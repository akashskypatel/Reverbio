/*
 *     Copyright (C) 2025 Akash Patel
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
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/settings_manager.dart' as settings;
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/mediaitem.dart';
import 'package:reverbio/utilities/utils.dart';
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

  static final _volumeNotifier = ValueNotifier(_volume);
  static AudioProcessingState _processingState = AudioProcessingState.idle;
  static AudioPlayerState _playerState = AudioPlayerState.uninitialized;

  final List<SongBar> _queueSongBars = [];

  static final _indexController = StreamController<int>.broadcast();
  static final _processingStateController =
      StreamController<AudioProcessingState>.broadcast();
  static final _playerStateController =
      StreamController<AudioPlayerState>.broadcast();
  final _mediaItemStreamController = StreamController<MediaItem>.broadcast();

  StreamSubscription<MediaItem>? _mediaItemSubscription;
  StreamSubscription? _playerStreamBuffer;
  StreamSubscription? _playerStreamCompleted;
  StreamSubscription? _playerStreamPlaying;
  StreamSubscription? _playerStreamError;

  final ValueNotifier<SongBar?> _songValueNotifier = ValueNotifier(null);
  ValueNotifier<double> get volumeNotifier => _volumeNotifier;
  ValueNotifier<SongBar?> get songValueNotifier => _songValueNotifier;

  List<SongBar> get queueSongBars => _queueSongBars;
  AudioPlayerState get playerState => _playerState;
  AudioProcessingState get state => _processingState;
  static Player get player => _player;
  bool get shuffleModeEnabled => _isShuffleEnabled;
  bool get playing => _player.state.playing;
  bool get hasNext {
    if (songValueNotifier.value == null) return false;
    final index = queueIndexOf(
      songValueNotifier.value!,
      songBars: _queueSongBars,
    );
    if (index == -1 || index >= _queueSongBars.length - 1) return false;
    return true;
  }

  //_player.state.playlist.index < _player.state.playlist.medias.length - 1;
  bool get hasPrevious {
    if (songValueNotifier.value == null) return false;
    final index = queueIndexOf(
      songValueNotifier.value!,
      songBars: _queueSongBars,
    );
    if (index == -1 || index <= 0) return false;
    return true;
  }

  //_player.state.playlist.index > 0;
  int get currentIndex => _player.state.playlist.index;
  Duration get position => _player.state.position;
  Duration get duration => _player.state.duration;
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
  Stream<MediaItem> get mediaItemStream => _mediaItemStreamController.stream;

  void _initialize() {
    _playerState = AudioPlayerState.initialized;
    _playerStreamBuffer = _player.stream.buffer.listen((buffer) {
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
    _playerStreamCompleted = _player.stream.completed.listen((isCompleted) {
      if (isCompleted && _processingState != AudioProcessingState.error) {
        _updateProcessingState(AudioProcessingState.completed);
        logger.log(
          'Buffer Completed:${_player.state.buffer.inSeconds} \n Status:$_processingState',
          null,
          null,
        );
      }
    });
    _playerStreamPlaying = _player.stream.playing.listen((playing) {
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
    _playerStreamError = _player.stream.error.listen((error) {
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
    /*
    _player.stream.playlist.listen((playlist) {
      _indexController.add(playlist.index);
    });
    */
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
    await _player.play();
    return;
  }

  Future<void> pause() async {
    _updatePlayerState(AudioPlayerState.paused);
    return _player.pause();
  }

  Future<void> close() async {
    _updatePlayerState(AudioPlayerState.initialized);
    await player.stop();
    _songValueNotifier.value = null;
    return;
  }

  Future<void> stop() async {
    _updatePlayerState(AudioPlayerState.stopped);
    await _mediaItemSubscription?.cancel();
    await player.stop();
    return _player.stop();
  }

  Future<void> seekToStart() async {
    _updatePlayerState(
      player.state.playing ? AudioPlayerState.playing : AudioPlayerState.paused,
    );
    await player.seek(Duration.zero);
    return _player.pause();
  }

  Future<void> dispose() async {
    _updatePlayerState(AudioPlayerState.uninitialized);
    await close();
    await _playerStreamBuffer?.cancel();
    await _playerStreamCompleted?.cancel();
    await _playerStreamPlaying?.cancel();
    await _playerStreamError?.cancel();
    await _mediaItemSubscription?.cancel();
    await _processingStateController.close();
    await _indexController.close();
    await _processingStateController.close();
    await _playerStateController.close();
    await _mediaItemStreamController.close();
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
    _mediaItemSubscription = songBar.mediaItemStream.listen(
      _mediaItemStreamController.add,
    );
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
    if (duration < player.state.duration)
      _updatePlayerState(
        player.state.playing ? AudioPlayerState.playing : playerState,
      );
    return _player.seek(duration);
  }

  Future<void> setPlaylistMode(PlaylistMode mode) async {
    return _player.setPlaylistMode(mode);
  }

  void skipToNext(int index) {
    _indexController.add(index);
  }

  void skipToPrevious(int index) {
    _indexController.add(index);
  }
}

class ReverbioAudioHandler extends BaseAudioHandler {
  ReverbioAudioHandler() {
    _setupEventSubscriptions();
    _updatePlaybackState();
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
  late final StreamSubscription<MediaItem?> _mediaItemSubscription;

  final ValueNotifier<PositionData> positionDataNotifier = ValueNotifier(
    PositionData(Duration.zero, Duration.zero, Duration.zero),
  );

  Duration get position => audioPlayer.position;
  Duration get duration => audioPlayer.duration;
  bool get hasNext => audioPlayer.hasNext;
  bool get hasPrevious => audioPlayer.hasPrevious;
  ValueNotifier<SongBar?> get songValueNotifier =>
      audioPlayer.songValueNotifier;
  Stream<AudioPlayerState> get playerStateStream =>
      audioPlayer.playerStateStream;
  double get volume => audioPlayer.volume;
  Stream<PositionData> get positionDataStream => audioPlayer.positionDataStream;
  AudioProcessingState get state => audioPlayer.state;
  bool get playing => audioPlayer.playing;
  Stream<Duration> get positionStream => audioPlayer.positionStream;

  Future<void> dispose() async {
    await _playbackEventSubscription.cancel();
    await _stateChangeSubscription.cancel();
    await _durationSubscription.cancel();
    await _currentIndexSubscription.cancel();
    await _sequenceStateSubscription.cancel();
    await _positionDataSubscription.cancel();
    await _mediaItemSubscription.cancel();
    await audioPlayer.dispose();
  }

  @override
  Future<void> onTaskRemoved() async {
    await close();
    await super.onTaskRemoved();
  }

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
    final index = queueIndexOf(audioPlayer.songValueNotifier.value!);
    if (loopAllSongs && index == queueSongBars.length - 1) {
      await queueSong(songBar: queueSongBars.first, play: play);
      audioPlayer.skipToNext(0);
    } else if (index < queueSongBars.length - 1) {
      await queueSong(songBar: queueSongBars[index + 1], play: play);
      audioPlayer.skipToNext(index + 1);
    }
    return;
  }

  @override
  Future<void> skipToPrevious({bool play = true}) async {
    final loopAllSongs = repeatNotifier.value == AudioServiceRepeatMode.all;
    if (!audioPlayer.hasPrevious && !loopAllSongs) return;
    if (audioPlayer.songValueNotifier.value == null) return;
    final index = queueIndexOf(audioPlayer.songValueNotifier.value!);
    if (loopAllSongs && index == 0) {
      await queueSong(songBar: queueSongBars.last, play: play);
      audioPlayer.skipToPrevious(queueSongBars.length - 1);
    } else if (index > 0) {
      await queueSong(songBar: queueSongBars[index - 1], play: play);
      audioPlayer.skipToPrevious(index - 1);
    }
    return;
  }

  @override
  Future<void> skipToQueueItem(int index, {bool play = true}) async {
    index = min(index, queueSongBars.length - 1);
    await queueSong(songBar: queueSongBars[index], play: play);
  }

  Future<void> skipToRandom({bool play = true}) async {
    final index = min(
      Random().nextInt(queueSongBars.length - 1),
      queueSongBars.length - 1,
    );
    await queueSong(songBar: queueSongBars[index], play: play);
  }

  @override
  Future<void> fastForward() =>
      seek(Duration(seconds: audioPlayer.position.inSeconds + 15));

  @override
  Future<void> rewind() =>
      seek(Duration(seconds: audioPlayer.position.inSeconds - 15));

  Future<void> close() async {
    await audioPlayer.close();
    queue.add([]);
    playbackState.add(PlaybackState());
    mediaItem.add(null);
  }

  Future<void> setVolume(double volume) => audioPlayer.setVolume(volume);
  Future<void> seekToStart() => audioPlayer.seekToStart();

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

  void _handleMediaItemChange(MediaItem mediaitem) {
    mediaItem.add(mediaitem);
  }

  void _handleDurationChange(Duration? duration) {
    try {
      /*
      final index = audioPlayer.currentIndex;
      if (queue.value.isNotEmpty) {
        final newQueue = List<MediaItem>.from(queue.value);
        final oldMediaItem = newQueue[index];
        final newMediaItem = oldMediaItem.copyWith(duration: duration);
        newQueue[index] = newMediaItem;
        queue.add(newQueue);
        mediaItem.add(newMediaItem);
      }
      */
    } catch (e, stackTrace) {
      logger.log('Error handling duration change', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _handleCurrentSongIndexChanged(int? index) {
    try {
      /*
      if (index != null && queue.value.isNotEmpty) {
        final playlist = queue.value;
        mediaItem.add(playlist[index]);
      }
      */
    } catch (e, stackTrace) {
      logger.log('Error handling current song index change', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _handleSequenceStateChange(Playlist? playlist) {
    try {
      /*
      final sequence = playlist?.medias;
      if (sequence != null && sequence.isNotEmpty) {
        final items =
            sequence
                .map((source) => extrasToMediaItem(source.extras ?? {}))
                .toList();
        queue.add(items); 
      }
      */
      settings.shuffleNotifier.value = audioPlayer.shuffleModeEnabled;
    } catch (e, stackTrace) {
      logger.log('Error handling sequence state change', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _positionDataNotify(PositionData value) {
    positionDataNotifier.value = value;
    if (((value.duration - value.position).inMilliseconds / 10) <= 100 &&
        value.duration != Duration.zero &&
        value.position != Duration.zero) {
      switch (repeatNotifier.value) {
        case AudioServiceRepeatMode.one:
          queueSong(songBar: audioPlayer.songValueNotifier.value, play: true);
          break;
        default:
          if (shuffleNotifier.value)
            skipToRandom();
          else
            skipToNext();
          break;
      }
    }
    if (value.duration != value.position &&
        value.duration != Duration.zero &&
        value.position != Duration.zero) {
      final song = audioPlayer.songValueNotifier.value?.song;
      if (song != null &&
          song['skipSegments'] != null &&
          song['skipSegments'].isNotEmpty) {
        final checkSegment =
            (song['skipSegments'] as List<Map<String, dynamic>>)
                .where(
                  (e) =>
                      e['start']! <= value.position.inMicroseconds &&
                      e['end']! > value.position.inMicroseconds,
                )
                .toList();
        if (checkSegment.isNotEmpty) {
          final seekTo = checkSegment.first['end'];
          final category = checkSegment.first['category'];
          if ((category == 'sponsor' && sponsorBlockSupport.value) ||
              (category != 'sponsor' && skipNonMusic.value))
            if (seekTo != null)
              audioPlayer.seek(Duration(microseconds: seekTo));
        }
      }
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
    _mediaItemSubscription = audioPlayer.mediaItemStream.listen(
      _handleMediaItemChange,
    );
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
      final index = songBar == null ? 0 : queueIndexOf(songBar);
      songBar = queueSongBars[index];
      final isError =
          songBar.song.containsKey('isError') ? songBar.song['isError'] : false;
      /* if (index < queueSongBars.length) {
        isError = !(await queueSongBars[index].queueSong(play: play));
      } */
      // Prepare next song
      if (prepareNextSong.value) {
        final newIndex =
            index >= queueSongBars.length && loopAllSongs ? 0 : index + 1;
        if (play &&
            !isError &&
            queueSongBars.length > 1 &&
            newIndex != index &&
            newIndex < queueSongBars.length)
          unawaited(queueSongBars[newIndex].prepareSong());

        if (play &&
            isError &&
            skipOnError &&
            newIndex < queueSongBars.length &&
            newIndex != index)
          return await queueSong(
            songBar: queueSongBars[newIndex],
            play: play,
            skipOnError: skipOnError,
          );
      }
      final isOffline = songBar.song['isOffline'] ?? false;
      final preliminaryTag = mapToMediaItem(songBar.song);
      if (songBar.song['songUrl'] == null &&
          !songBar.isPrimed &&
          !songBar.isLoading)
        await songBar.prepareSong(shouldWait: true);

      if (songBar.song['songUrl'] == null ||
          await checkUrl(songBar.song['songUrl']) >= 400) {
        songBar.song['songUrl'] = null;
        songBar.song['isError'] = true;
        songBar.song['error'] = 'Song URL could not be resolved.';
      }
      final songUrl = songBar.song['songUrl'];
      if (songUrl != null) {
        final audioSource = await buildAudioSource(songBar);
        if (play) {
          mediaItem.add(preliminaryTag);
          logger.log('Playing: $songUrl', null, null);
          await audioPlayer.queue(audioSource, songBar);
          unawaited(audioPlayer.play());
        }
        final cacheKey =
            'song_${songBar.song['ytid']}_${settings.audioQualitySetting.value}_url';
        if (!isOffline) addOrUpdateData('cache', cacheKey, songUrl);
        return !isError;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return false;
  }

  Future<Media> buildAudioSource(SongBar songBar) async {
    final extras = songToMediaExtras(songBar.song);

    if (songBar.song['offlineAudioPath'] != null &&
        isFilePath(songBar.song['offlineAudioPath']) &&
        doesFileExist(songBar.song['offlineAudioPath'])) {
      final uri = Uri.file(songBar.song['offlineAudioPath']);
      final media = Media(uri.toString(), extras: extras);
      return media;
    }

    final uri = Uri.parse(songBar.song['songUrl']);
    final audioSource = Media(uri.toString(), extras: extras);

    if (!settings.sponsorBlockSupport.value) {
      return audioSource;
    }

    if (songBar.song['source'] == 'youtube' && !offlineMode.value)
      songBar.song['skipSegments'] = await getSkipSegments(
        songBar.song['ytid'],
      );
    return audioSource;
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

void updateMediaItemQueue(List<SongBar> songBars) {
  audioHandler.queue.add(songBars.map((e) => e.mediaItem).toList());
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
    audioHandler.queue.add(audioHandler.queue.value + [songBar.mediaItem]);
  }
}

bool removeSongFromQueue(SongBar songBar) {
  final val = activeQueue['list'].remove(songBar.song);
  audioHandler.queueSongBars.removeWhere((e) {
    return e.equals(songBar);
  });
  updateMediaItemQueue(audioHandler.queueSongBars);
  activeQueueLength.value = audioHandler.queueSongBars.length;
  return val;
}

bool isSongInQueue(SongBar songBar) {
  final inQueue =
      audioHandler.queueSongBars.where((e) {
        return e.equals(songBar);
      }).isNotEmpty;
  return inQueue;
}

int queueIndexOf(SongBar songBar, {List<SongBar>? songBars}) {
  if (songBars != null) return songBars.indexWhere((e) => e.equals(songBar));
  return audioHandler.queueSongBars.indexWhere((e) => e.equals(songBar));
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
