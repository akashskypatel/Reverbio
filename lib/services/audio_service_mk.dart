/*
 *     Copyright (C) 2025 Akashy Patel
 *
 *     Reverbio is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Reverbio is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Reverbio, including how to contribute,
 *     please visit: https://github.com/akashskypatel/Reverbio
 */

import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/settings_manager.dart' as settings;
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/mediaitem.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:rxdart/rxdart.dart';

enum AudioPlayerState { uninitialized, initialized, playing, paused, stopped }

final Map activeQueue = {
  'id': '',
  'ytid': '',
  'title': 'No Songs in Queue',
  'image': '',
  'source': '',
  'list': [],
};

class AudioPlayerService {
  AudioPlayerService() {
    MediaKit.ensureInitialized();
    _initialize();
  }
  static final Player _player = Player();
  static bool _isShuffleEnabled = false;
  static double _volume = settings.volume.toDouble();
  static final _processingStateController =
      StreamController<AudioProcessingState>.broadcast();
  static final _indexController = StreamController<int>.broadcast();
  static final _volumeNotifier = ValueNotifier(_volume);
  static AudioProcessingState _processingState = AudioProcessingState.idle;
  static AudioPlayerState _playerState = AudioPlayerState.uninitialized;
  static final _playerStateController =
      StreamController<AudioPlayerState>.broadcast();
  final ValueNotifier<SongBar?> _songValueNotifier = ValueNotifier(null);
  final List<SongBar> _queueSongBars = [];

  ValueNotifier<SongBar?> get songValueNotifier => _songValueNotifier;
  List<SongBar> get queueSongBars => _queueSongBars;
  AudioPlayerState get playerState => _playerState;
  AudioProcessingState get state => _processingState;
  static Player get player => _player;
  bool get shuffleModeEnabled => _isShuffleEnabled;
  bool get playing => _player.state.playing;
  bool get hasNext {
    if (songValueNotifier.value == null) return false;
    final index = _queueSongBars.indexOf(songValueNotifier.value!);
    if (index == -1 || index >= _queueSongBars.length - 1) return false;
    return true;
  }

  //_player.state.playlist.index < _player.state.playlist.medias.length - 1;
  bool get hasPrevious {
    if (songValueNotifier.value == null) return false;
    final index = _queueSongBars.indexOf(songValueNotifier.value!);
    if (index == -1 || index <= 0) return false;
    return true;
  }

  //_player.state.playlist.index > 0;
  int get currentIndex => _player.state.playlist.index;
  Duration get position => _player.state.position;
  Duration get bufferedPosition => _player.state.buffer;
  double get speed => _player.state.rate;
  double get volume => _volume;

  Stream<AudioPlayerState> get playerStateStream =>
      _playerStateController.stream;
  Stream<AudioProcessingState> get processingStateStream =>
      _processingStateController.stream;
  Stream<bool> get playbackEventStream => _player.stream.playing;
  Stream<Duration> get durationStream => _player.stream.duration;
  Stream<Duration> get positionStream => _player.stream.position;
  Stream<Duration> get bufferedPositionStream => _player.stream.buffer;
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.stream.position,
        _player.stream.buffer,
        _player.stream.duration,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      );
  Stream<int> get currentIndexStream => _indexController.stream;
  Stream<Playlist> get sequenceStateStream => _player.stream.playlist;
  ValueNotifier<double> get volumeNotifier => _volumeNotifier;

  void _initialize() {
    _playerState = AudioPlayerState.initialized;
    _player.stream.buffer.listen((buffer) {
      if ((_player.state.buffer.inSeconds < (_player.state.rate * 60)) ||
          _player.state.buffering) {
        _updateProcessingState(AudioProcessingState.buffering);
      } else if (_player.state.buffer.inSeconds >= (_player.state.rate * 60)) {
        _updateProcessingState(AudioProcessingState.ready);
      }
      logger.log(
        'Buffer position:${_player.state.buffer.inSeconds} \n Status:$_processingState',
        null,
        null,
      );
    });
    _player.stream.completed.listen((isCompleted) {
      if (isCompleted && _processingState != AudioProcessingState.error) {
        _updateProcessingState(AudioProcessingState.completed);
        logger.log(
          'Buffer Completed:${_player.state.buffer.inSeconds} \n Status:$_processingState',
          null,
          null,
        );
      }
    });
    _player.stream.playing.listen((playing) {
      if (playing && _processingState != AudioProcessingState.error) {
        _updateProcessingState(AudioProcessingState.ready);
        _updatePlayerState(AudioPlayerState.paused);
        logger.log(
          'Playing:${_player.state.buffer.inSeconds} \n Status:$_processingState',
          null,
          null,
        );
      }
    });
    _player.stream.error.listen((error) {
      if (error != '') {
        logger.log('Player Stream Error', error, StackTrace.current);
        _updateProcessingState(AudioProcessingState.error);
        logger.log(
          'Error:${_player.state.buffer.inSeconds} \n Status:$_processingState',
          null,
          null,
        );
      }
    });
    _player.stream.playlist.listen((playlist) {
      _indexController.add(playlist.index);
    });
    setVolume(_volume);
  }

  void _updateProcessingState(AudioProcessingState newState) {
    if (_processingState != newState) {
      _processingState = newState;
      _processingStateController.add(newState);
    }
  }

  void _updatePlayerState(AudioPlayerState newState) {
    if (_playerState != newState) {
      _playerState = newState;
      _playerStateController.add(newState);
    }
  }

  Future<void> play() async {
    _updatePlayerState(AudioPlayerState.playing);
    return _player.play();
  }

  Future<void> pause() async {
    _updatePlayerState(AudioPlayerState.paused);
    return _player.pause();
  }

  Future<void> stop() async {
    _updatePlayerState(AudioPlayerState.stopped);
    await player.stop();
    return _player.stop();
  }

  Future<void> seekToStart() async {
    await player.seek(Duration.zero);
    return _player.pause();
  }

  Future<void> dispose() async {
    _updatePlayerState(AudioPlayerState.uninitialized);
    await _processingStateController.close();
    return _player.dispose();
  }

  Future<void> setShuffleMode(bool shuffle) async {
    _isShuffleEnabled = shuffle;
    return _player.setShuffle(shuffle);
  }

  Future<void> open(Media media) async {
    _updateProcessingState(AudioProcessingState.loading);
    return _player.open(media);
  }

  Future<void> queue(Media media, SongBar songBar) async {
    _updateProcessingState(AudioProcessingState.loading);
    songValueNotifier.value = songBar;
    await _player.open(media);
    await player.seek(Duration.zero);
    return _player.pause();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    _volumeNotifier.value = volume;
    addOrUpdateData('settings', 'volume', volume.toInt());
    return _player.setVolume(volume);
  }

  Future<void> seek(Duration duration) async {
    return _player.seek(duration);
  }

  Future<void> setPlaylistMode(PlaylistMode mode) async {
    return _player.setPlaylistMode(mode);
  }
}

class ReverbioAudioHandler extends BaseAudioHandler {
  ReverbioAudioHandler() {
    _setupEventSubscriptions();
    _updatePlaybackState();

    _initialize();
  }

  final AudioPlayerService audioPlayer = AudioPlayerService();

  Timer? _sleepTimer;
  bool sleepTimerExpired = false;
  late bool wasPlayingBeforeCall = false;
  List<SongBar> get queueSongBars => audioPlayer.queueSongBars;
  late final StreamSubscription<bool?> _playbackEventSubscription;
  late final StreamSubscription<AudioProcessingState?> _stateChangeSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<int?> _currentIndexSubscription;
  late final StreamSubscription<Playlist?> _sequenceStateSubscription;
  late final StreamSubscription<PositionData> _positionDataSubscription;

  final ValueNotifier<PositionData> positionDataNotifier = ValueNotifier(
    PositionData(Duration.zero, Duration.zero, Duration.zero),
  );

  void _handlePlaybackEvent(bool playing) {
    try {
      if (playing &&
          audioPlayer.state == AudioProcessingState.completed &&
          !sleepTimerExpired) {
        skipToNext();
      }
    } catch (e, stackTrace) {
      logger.log('Error handling playback event', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _handleStateChangeSubscription(AudioProcessingState state) {
    _updatePlaybackState();
  }

  void _handleDurationChange(Duration? duration) {
    try {
      final index = audioPlayer.currentIndex;
      if (queue.value.isNotEmpty) {
        final newQueue = List<MediaItem>.from(queue.value);
        final oldMediaItem = newQueue[index];
        final newMediaItem = oldMediaItem.copyWith(duration: duration);
        newQueue[index] = newMediaItem;
        queue.add(newQueue);
        mediaItem.add(newMediaItem);
      }
    } catch (e, stackTrace) {
      logger.log('Error handling duration change', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _handleCurrentSongIndexChanged(int? index) {
    try {
      if (index != null && queue.value.isNotEmpty) {
        final playlist = queue.value;
        mediaItem.add(playlist[index]);
      }
    } catch (e, stackTrace) {
      logger.log('Error handling current song index change', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _handleSequenceStateChange(Playlist? playlist) {
    try {
      final sequence = playlist?.medias;
      if (sequence != null && sequence.isNotEmpty) {
        final items =
            sequence
                .map((source) => extrasToMediaItem(source.extras ?? {}))
                .toList();
        queue.add(items);
        settings.shuffleNotifier.value = audioPlayer.shuffleModeEnabled;
      }
    } catch (e, stackTrace) {
      logger.log('Error handling sequence state change', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _setupEventSubscriptions() {
    _playbackEventSubscription = audioPlayer.playbackEventStream.listen(
      _handlePlaybackEvent,
    );
    _stateChangeSubscription = audioPlayer.processingStateStream.listen(
      _handleStateChangeSubscription,
    );
    _durationSubscription = audioPlayer.durationStream.listen(
      _handleDurationChange,
    );
    _currentIndexSubscription = audioPlayer.currentIndexStream.listen(
      _handleCurrentSongIndexChanged,
    );
    _sequenceStateSubscription = audioPlayer.sequenceStateStream.listen(
      _handleSequenceStateChange,
    );
    _positionDataSubscription = audioPlayer.positionDataStream.listen(
      _positionDataNotify,
    );
  }

  void _positionDataNotify(PositionData value) {
    positionDataNotifier.value = value;
    if (positionDataNotifier.value.duration.inSeconds ==
            positionDataNotifier.value.position.inSeconds &&
        positionDataNotifier.value.duration.inSeconds !=
            Duration.zero.inSeconds &&
        positionDataNotifier.value.position.inSeconds !=
            Duration.zero.inSeconds)
      switch (repeatNotifier.value) {
        case AudioServiceRepeatMode.one:
          queueSong(songBar: audioPlayer.songValueNotifier.value, play: true);
          break;
        default:
          skipToNext();
          break;
      }
  }

  void _updatePlaybackState() {
    final hasPreviousOrNext = hasPrevious || hasNext;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (hasPreviousOrNext)
            MediaControl.skipToPrevious
          else
            MediaControl.rewind,
          if (audioPlayer.playing) MediaControl.pause else MediaControl.play,
          if (hasPreviousOrNext)
            MediaControl.skipToNext
          else
            MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: audioPlayer.state,
        repeatMode: settings.repeatNotifier.value,
        shuffleMode:
            audioPlayer.shuffleModeEnabled
                ? AudioServiceShuffleMode.all
                : AudioServiceShuffleMode.none,
        playing: audioPlayer.playing,
        updatePosition: audioPlayer.position,
        bufferedPosition: audioPlayer.bufferedPosition,
        speed: audioPlayer.speed,
        queueIndex: audioPlayer.currentIndex,
      ),
    );
  }

  Future<void> _initialize() async {
    /* final session = await AudioSession.instance;
    try {
      await session.configure(const AudioSessionConfiguration.music());
      session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          wasPlayingBeforeCall = audioPlayer.playing;
          switch (event.type) {
            case AudioInterruptionType.duck:
              await audioPlayer.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              await audioPlayer.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await audioPlayer.setVolume(1);
              break;
            case AudioInterruptionType.pause:
              if (wasPlayingBeforeCall) await audioPlayer.play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e, stackTrace) {
      logger.log('Error initializing audio session', e, stackTrace);
    } */
  }

  @override
  Future<void> onTaskRemoved() async {
    await audioPlayer.stop().then((_) => audioPlayer.dispose());

    await _playbackEventSubscription.cancel();
    await _stateChangeSubscription.cancel();
    await _durationSubscription.cancel();
    await _currentIndexSubscription.cancel();
    await _sequenceStateSubscription.cancel();
    await _positionDataSubscription.cancel();
    await super.onTaskRemoved();
  }

  bool get hasNext => audioPlayer.hasNext;

  bool get hasPrevious => audioPlayer.hasPrevious;

  @override
  Future<void> play() => audioPlayer.play();
  @override
  Future<void> pause() => audioPlayer.pause();
  @override
  Future<void> stop() => audioPlayer.stop();
  @override
  Future<void> seek(Duration position) => audioPlayer.seek(position);
  @override
  Future<void> skipToNext({bool play = true}) async {
    final loopAllSongs = repeatNotifier.value == AudioServiceRepeatMode.all;
    if (!audioPlayer.hasNext && !loopAllSongs) return;
    if (audioPlayer.songValueNotifier.value?.song == null) return;
    final index = queueSongBars.indexOf(audioPlayer.songValueNotifier.value!);
    if (loopAllSongs && index == queueSongBars.length - 1)
      await queueSong(songBar: queueSongBars.first, play: play);
    else if (index < queueSongBars.length - 1)
      await queueSong(songBar: queueSongBars[index + 1], play: play);
    return;
  }

  @override
  Future<void> skipToPrevious({bool play = true}) async {
    final loopAllSongs = repeatNotifier.value == AudioServiceRepeatMode.all;
    if (!audioPlayer.hasPrevious && !loopAllSongs) return;
    if (audioPlayer.songValueNotifier.value == null) return;
    final index = queueSongBars.indexOf(audioPlayer.songValueNotifier.value!);
    if (loopAllSongs && index == 0)
      await queueSong(songBar: queueSongBars.last, play: play);
    else if (index > 0)
      await queueSong(songBar: queueSongBars[index - 1], play: play);
    return;
  }

  Future<void> setVolume(double volume) => audioPlayer.setVolume(volume);

  Future<void> seekToStart() => audioPlayer.seekToStart();

  @override
  Future<void> fastForward() =>
      seek(Duration(seconds: audioPlayer.position.inSeconds + 15));

  @override
  Future<void> rewind() =>
      seek(Duration(seconds: audioPlayer.position.inSeconds - 15));

  Future<bool> queueSong({
    SongBar? songBar,
    bool play = false,
    bool skipOnError = false,
  }) async {
    try {
      if (songBar != null && !isSongInQueue(songBar)) {
        addSongToQueue(songBar);
      }
      if (queueSongBars.isEmpty) return false;
      final loopAllSongs = repeatNotifier.value == AudioServiceRepeatMode.all;
      final index = songBar == null ? 0 : queueSongBars.indexOf(songBar);
      songBar = queueSongBars[index];
      final isError =
          songBar.song.containsKey('isError') ? songBar.song['isError'] : false;
      ;
      /* if (index < queueSongBars.length) {
        isError = !(await queueSongBars[index].queueSong(play: play));
      } */
      final newIndex =
          index >= queueSongBars.length && loopAllSongs ? 0 : index + 1;
      if (play &&
          !isError &&
          queueSongBars.length > 1 &&
          newIndex != index &&
          newIndex < queueSongBars.length)
        unawaited(queueSongBars[newIndex].primeSong());

      if (play &&
          isError &&
          skipOnError &&
          newIndex < queueSongBars.length &&
          newIndex != index)
        return queueSong(
          songBar: queueSongBars[newIndex],
          play: play,
          skipOnError: skipOnError,
        );
      final isOffline = songBar.song['isOffline'] ?? false;
      final preliminaryTag = mapToMediaItem(songBar.song);
      if (!songBar.isPrimed && !songBar.isLoading)
        await songBar.primeSong(shouldWait: true);
      final songUrl = songBar.song['songUrl'];
      if (songUrl == null) return !isError;
      final audioSource = await buildAudioSource(
        songBar.song,
        songUrl,
        isOffline,
      );
      mediaItem.add(preliminaryTag);
      await audioPlayer.queue(audioSource, songBar);
      if (play) unawaited(audioPlayer.play());
      final cacheKey =
          'song_${songBar.song['ytid']}_${settings.audioQualitySetting.value}_url';
      if (!isOffline) addOrUpdateData('cache', cacheKey, songUrl);
      return !isError;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return false;
    }
  }

  Future<Media> buildAudioSource(
    Map song,
    String songUrl,
    bool isOffline,
  ) async {
    final extras = songToMediaExtras(song);

    if (isOffline) {
      final uri = Uri.file(songUrl);
      final media = Media(uri.toString(), extras: extras);
      return media;
    }

    final uri = Uri.parse(songUrl);
    final audioSource = Media(uri.toString(), extras: extras);

    if (!settings.sponsorBlockSupport.value) {
      return audioSource;
    }

    final spbAudioSource = await checkIfSponsorBlockIsAvailable(
      audioSource,
      song['ytid'],
    );
    return spbAudioSource ?? audioSource;
  }

  //TODO: to implement sponsor clipping
  Future<Media?> checkIfSponsorBlockIsAvailable(
    Media media,
    String songId,
  ) async {
    try {
      return null;
    } catch (e, stackTrace) {
      logger.log('Error checking sponsor block', e, stackTrace);
    }
    return null;
  }

  Future<void> playAgain() async {
    await audioPlayer.seek(Duration.zero);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final shuffleEnabled = shuffleMode != AudioServiceShuffleMode.none;
    settings.shuffleNotifier.value = shuffleEnabled;
    await audioPlayer.setShuffleMode(shuffleEnabled);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    PlaylistMode newMode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.all:
        newMode = PlaylistMode.loop;
        break;
      case AudioServiceRepeatMode.one:
        newMode = PlaylistMode.single;
        break;
      default:
        newMode = PlaylistMode.none;
    }
    // we use this only when we want to loop single song
    await audioPlayer.setPlaylistMode(newMode);
  }

  Future<void> setSleepTimer(Duration duration) async {
    _sleepTimer?.cancel();
    sleepTimerExpired = false;
    _sleepTimer = Timer(duration, () async {
      await stop();
      settings.playNextSongAutomatically.value = false;
      sleepTimerExpired = true;
      _sleepTimer = null;
    });
  }

  void cancelSleepTimer() {
    if (_sleepTimer != null) {
      _sleepTimer!.cancel();
      _sleepTimer = null;
      sleepTimerExpired = false;
    }
  }

  void changeSponsorBlockStatus() {
    settings.sponsorBlockSupport.value = !settings.sponsorBlockSupport.value;
    addOrUpdateData(
      'settings',
      'sponsorBlockSupport',
      settings.sponsorBlockSupport.value,
    );
  }

  void changeAutoPlayNextStatus() {
    settings.playNextSongAutomatically.value =
        !settings.playNextSongAutomatically.value;
    addOrUpdateData(
      'settings',
      'playNextSongAutomatically',
      settings.playNextSongAutomatically.value,
    );
  }

  int _generateRandomIndex(int length) {
    final random = Random();
    var randomIndex = random.nextInt(length);

    while (randomIndex == activeSongId) {
      randomIndex = random.nextInt(length);
    }

    return randomIndex;
  }
}

void addSongsToQueue(List<SongBar> songBars) {
  for (final songBar in songBars) {
    addSongToQueue(songBar);
  }
}

void addSongToQueue(SongBar songBar) {
  if (!isSongInQueue(songBar)) {
    activeQueue['list'].add(songBar.song);
    audioHandler.queueSongBars.add(songBar);
    activeQueueLength.value = audioHandler.queueSongBars.length;
  }
}

bool removeSongFromQueue(SongBar songBar) {
  final val = activeQueue['list'].remove(songBar.song);
  audioHandler.queueSongBars.remove(songBar);
  activeQueueLength.value = audioHandler.queueSongBars.length;
  return val;
}

bool isSongInQueue(SongBar songBar) {
  return audioHandler.queueSongBars.contains(songBar);
}

void setQueueToPlaylist(dynamic playlist, List<SongBar> songBars) {
  clearSongQueue();
  activeQueue['id'] = playlist['id'];
  activeQueue['ytid'] = playlist['ytid'];
  activeQueue['title'] = playlist['title'];
  activeQueue['image'] = playlist['image'];
  activeQueue['source'] = playlist['source'];
  addSongsToQueue(songBars);
}

void clearSongQueue() {
  activeQueue['id'] = '';
  activeQueue['ytid'] = '';
  activeQueue['title'] = 'No Songs in Queue';
  activeQueue['image'] = '';
  activeQueue['source'] = '';
  activeQueue['list'].clear();
  audioHandler.queueSongBars.clear();
  activeQueueLength.value = 0;
}
