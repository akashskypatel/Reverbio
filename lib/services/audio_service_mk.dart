/*
 *     Copyright (C) 2025 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:musify/API/musify.dart';
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:rxdart/rxdart.dart';

class AudioPlayerService {
  AudioPlayerService() {
    MediaKit.ensureInitialized();
    _initialize();
  }
  static final Player _player = Player();
  static bool _isShuffleEnabled = false;
  final _stateController = StreamController<AudioProcessingState>.broadcast();
  final _indexController = StreamController<int>.broadcast();
  AudioProcessingState _state = AudioProcessingState.idle;

  static Player get audioPlayer => _player;

  AudioProcessingState get state => _state;
  Player get player => _player;
  bool get shuffleModeEnabled => _isShuffleEnabled;
  bool get playing => _player.state.playing;
  bool get hasNext =>
      _player.state.playlist.index < _player.state.playlist.medias.length - 1;
  bool get hasPrevious => _player.state.playlist.index > 0;
  int get currentIndex => _player.state.playlist.index;
  Duration get position => _player.state.position;
  Duration get bufferedPosition => _player.state.buffer;
  double get speed => _player.state.rate;
  Stream<AudioProcessingState> get stateStream => _stateController.stream;
  Stream<bool> get playbackEventStream => _player.stream.playing;
  Stream<Duration> get durationStream => _player.stream.duration;
  Stream<Duration> get positionStream => _player.stream.position;
  Stream<Duration> get bufferedPositionStream => _player.stream.buffer;
  Stream<int> get currentIndexStream => _indexController.stream;
  Stream<Playlist> get sequenceStateStream => _player.stream.playlist;

  void _initialize() {
    _player.stream.buffering.listen((isBuffering) {
      if (!_player.state.playing && isBuffering) {
        _updateState(AudioProcessingState.buffering);
      }
    });

    _player.stream.completed.listen((isCompleted) {
      if (isCompleted) {
        _updateState(AudioProcessingState.completed);
      }
    });
    _player.stream.buffer.listen((buffer) {
      if (_player.state.buffering && buffer == Duration.zero) {
        _updateState(AudioProcessingState.idle);
      }
    });
    _player.stream.buffer.listen((buffer) {
      if (_player.state.buffering && buffer > Duration.zero) {
        _updateState(AudioProcessingState.loading);
      }
    });
    _player.stream.playing.listen((playing) {
      if (playing) {
        _updateState(AudioProcessingState.ready);
      }
    });
    _player.stream.error.listen((error) {
      if (error != '') {
        logger.log('Player Stream Error', error, StackTrace.current);
        _updateState(AudioProcessingState.error);
      }
    });
    _player.stream.playlist.listen((playlist) {
      _indexController.add(playlist.index);
    });
  }

  void _updateState(AudioProcessingState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  Future<void> play() async {
    return _player.play();
  }

  Future<void> pause() async {
    return _player.pause();
  }

  Future<void> stop() async {
    await player.seek(Duration.zero);
    return _player.pause();
  }

  Future<void> dispose() async {
    return _player.dispose();
  }

  Future<void> setShuffleMode(bool shuffle) async {
    _isShuffleEnabled = shuffle;
    return _player.setShuffle(shuffle);
  }
}

class MusifyAudioHandler extends BaseAudioHandler with ChangeNotifier {
  MusifyAudioHandler() {
    _setupEventSubscriptions();
    _updatePlaybackState();

    _initialize();
  }

  final AudioPlayerService audioPlayer = AudioPlayerService();

  Timer? _sleepTimer;
  bool sleepTimerExpired = false;

  late StreamSubscription<bool?> _playbackEventSubscription;
  late StreamSubscription<Duration?> _durationSubscription;
  late StreamSubscription<int?> _currentIndexSubscription;
  late StreamSubscription<Playlist?> _sequenceStateSubscription;

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        audioPlayer.positionStream,
        audioPlayer.bufferedPositionStream,
        audioPlayer.durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
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
        shuffleNotifier.value = audioPlayer.shuffleModeEnabled;
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
    _durationSubscription = audioPlayer.durationStream.listen(
      _handleDurationChange,
    );
    _currentIndexSubscription = audioPlayer.currentIndexStream.listen(
      _handleCurrentSongIndexChanged,
    );
    _sequenceStateSubscription = audioPlayer.sequenceStateStream.listen(
      _handleSequenceStateChange,
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
        repeatMode: repeatNotifier.value,
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
    final session = await AudioSession.instance;
    try {
      await session.configure(const AudioSessionConfiguration.music());
      session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await audioPlayer.player.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              await audioPlayer.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await audioPlayer.player.setVolume(1);
              break;
            case AudioInterruptionType.pause:
              await audioPlayer.play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e, stackTrace) {
      logger.log('Error initializing audio session', e, stackTrace);
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await audioPlayer.stop().then((_) => audioPlayer.dispose());

    await _playbackEventSubscription.cancel();
    await _durationSubscription.cancel();
    await _currentIndexSubscription.cancel();
    await _sequenceStateSubscription.cancel();

    await super.onTaskRemoved();
  }

  bool get hasNext =>
      activePlaylist['list'].isEmpty
          ? audioPlayer.hasNext
          : activeSongId + 1 < activePlaylist['list'].length;

  bool get hasPrevious =>
      activePlaylist['list'].isEmpty
          ? audioPlayer.hasPrevious
          : activeSongId > 0;

  @override
  Future<void> play() => audioPlayer.play();
  @override
  Future<void> pause() => audioPlayer.pause();
  @override
  Future<void> stop() => audioPlayer.stop();
  @override
  Future<void> seek(Duration position) => audioPlayer.player.seek(position);

  @override
  Future<void> fastForward() =>
      seek(Duration(seconds: audioPlayer.position.inSeconds + 15));

  @override
  Future<void> rewind() =>
      seek(Duration(seconds: audioPlayer.position.inSeconds - 15));

  Future<void> playSong(Map song) async {
    try {
      final isOffline = song['isOffline'] ?? false;

      final preliminaryTag = mapToMediaItem(song);
      mediaItem.add(preliminaryTag);

      final songUrl =
          isOffline
              ? song['audioPath']
              : await getSong(song['ytid'], song['isLive']);

      final audioSource = await buildAudioSource(song, songUrl, isOffline);

      await audioPlayer.player.open(audioSource);
      await audioPlayer.play();

      final cacheKey = 'song_${song['ytid']}_${audioQualitySetting.value}_url';
      if (!isOffline) addOrUpdateData('cache', cacheKey, songUrl);
      if (playNextSongAutomatically.value) getSimilarSong(song['ytid']);
    } catch (e, stackTrace) {
      logger.log('Error playing song', e, stackTrace);
    }
  }

  Future<void> playPlaylistSong({
    Map<dynamic, dynamic>? playlist,
    required int songIndex,
  }) async {
    if (playlist != null) activePlaylist = playlist;
    activeSongId = songIndex;
    await audioHandler.playSong(activePlaylist['list'][activeSongId]);
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

    if (!sponsorBlockSupport.value) {
      return audioSource;
    }

    final spbAudioSource = await checkIfSponsorBlockIsAvailable(
      audioSource,
      song['ytid'],
    );
    return spbAudioSource ?? audioSource;
  }

  //TODO: to implement spnsor clipping
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

  Future<void> skipToSong(int newIndex) async {
    if (newIndex >= 0 && newIndex < activePlaylist['list'].length) {
      activeSongId =
          shuffleNotifier.value
              ? _generateRandomIndex(activePlaylist['list'].length)
              : newIndex;
      await playSong(activePlaylist['list'][activeSongId]);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (!hasNext && repeatNotifier.value == AudioServiceRepeatMode.all) {
      // If repeat mode is set to repeat the playlist, start from the beginning
      await skipToSong(0);
    } else if (!hasNext &&
        playNextSongAutomatically.value &&
        nextRecommendedSong != null) {
      // If there's no next song but playNextSongAutomatically is enabled, play the recommended song
      await playSong(nextRecommendedSong);
    } else if (hasNext) {
      // If there is a next song, skip to the next song
      await skipToSong(activeSongId + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (!hasPrevious && repeatNotifier.value == AudioServiceRepeatMode.all) {
      // If repeat mode is set to repeat the playlist, start from the end
      await skipToSong(activePlaylist['list'].length - 1);
    } else if (hasPrevious) {
      // If there is a previous song, skip to the previous song
      await skipToSong(activeSongId - 1);
    }
  }

  Future<void> playAgain() async {
    await audioPlayer.player.seek(Duration.zero);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final shuffleEnabled = shuffleMode != AudioServiceShuffleMode.none;
    shuffleNotifier.value = shuffleEnabled;
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
    await audioPlayer.player.setPlaylistMode(newMode);
  }

  Future<void> setSleepTimer(Duration duration) async {
    _sleepTimer?.cancel();
    sleepTimerExpired = false;
    _sleepTimer = Timer(duration, () async {
      await stop();
      playNextSongAutomatically.value = false;
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
    sponsorBlockSupport.value = !sponsorBlockSupport.value;
    addOrUpdateData(
      'settings',
      'sponsorBlockSupport',
      sponsorBlockSupport.value,
    );
  }

  void changeAutoPlayNextStatus() {
    playNextSongAutomatically.value = !playNextSongAutomatically.value;
    addOrUpdateData(
      'settings',
      'playNextSongAutomatically',
      playNextSongAutomatically.value,
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
