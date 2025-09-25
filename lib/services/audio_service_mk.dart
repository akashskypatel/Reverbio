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
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/services/settings_manager.dart' as settings;
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/file_tagger.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/mediaitem.dart';
import 'package:reverbio/utilities/notifiable_future.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:rxdart/rxdart.dart';

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

  late final Player _player = Player();
  bool _isShuffleEnabled = false;
  double _volume = settings.volume.value.toDouble();

  late final _volumeNotifier = ValueNotifier(_volume);
  final _processingStateNotifier = ValueNotifier<AudioProcessingState>(
    AudioProcessingState.idle,
  );

  final NotifiableList<SongBar> _queueSongBars = NotifiableList();

  final _indexController = StreamController<int>.broadcast();
  final _processingStateController =
      StreamController<AudioProcessingState>.broadcast();
  final _mediaItemStreamController = StreamController<MediaItem>.broadcast();

  final ValueNotifier<DateTime?> _bufferStartNotifier = ValueNotifier(null);

  List<AudioDevice> audioDevices = [];
  AudioDevice audioDevice = AudioDevice.auto();

  StreamSubscription<MediaItem>? _mediaItemSubscription;
  StreamSubscription? _playerStreamBuffer;
  StreamSubscription? _playerStreamCompleted;
  StreamSubscription? _playerStreamPlaying;
  StreamSubscription? _playerStreamError;
  StreamSubscription? _playerStreamAudioDevice;
  StreamSubscription? _playerStreamAudioDevices;

  final ValueNotifier<SongBar?> _songValueNotifier = ValueNotifier(null);
  ValueNotifier<double> get volumeNotifier => _volumeNotifier;
  ValueNotifier<SongBar?> get songValueNotifier => _songValueNotifier;

  NotifiableList<SongBar> get queueSongBars => _queueSongBars;
  AudioProcessingState get processingState => _processingStateNotifier.value;
  PlayerState get state => _player.state;
  Player get player => _player;
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

  bool get hasPrevious {
    if (songValueNotifier.value == null) return false;
    final index = queueIndexOf(
      songValueNotifier.value!,
      songBars: _queueSongBars,
    );
    if (index == -1 || index <= 0) return false;
    return true;
  }

  int get currentIndex => _player.state.playlist.index;
  Duration get position => _player.state.position;
  Duration get duration => _player.state.duration;
  Duration get bufferedPosition => _player.state.buffer;
  double get speed => _player.state.rate;
  double get volume => _volume;

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
  Stream<AudioDevice> get audioDeviceStream => _player.stream.audioDevice;
  Stream<List<AudioDevice>> get audioDevicesStream =>
      _player.stream.audioDevices;

  void _initialize() {
    _playerStreamBuffer = _player.stream.buffer.listen((buffer) {
      final bufferedDuration =
          DateTime.now()
              .difference(_bufferStartNotifier.value ?? DateTime.now())
              .inSeconds;
      final playableDuration =
          _player.state.buffer.inSeconds ~/ _player.state.rate;
      final isBuffered =
          playableDuration >= bufferedDuration &&
          (bufferedDuration + playableDuration) > 0;
      if (isBuffered)
        _updateProcessingState(AudioProcessingState.ready);
      else
        _updateProcessingState(AudioProcessingState.buffering);
    });
    _playerStreamCompleted = _player.stream.completed.listen((isCompleted) {
      if (isCompleted &&
          _processingStateNotifier.value != AudioProcessingState.error) {
        _updateProcessingState(AudioProcessingState.completed);
      }
    });
    _playerStreamPlaying = _player.stream.playing.listen((playing) {
      if (playing &&
          _processingStateNotifier.value != AudioProcessingState.error) {
        _updateProcessingState(AudioProcessingState.ready);
      }
    });
    _playerStreamError = _player.stream.error.listen((error) {
      if (error != '') {
        logger.log('Player Stream Error', error, StackTrace.current);
        _updateProcessingState(AudioProcessingState.error);
      }
    });
    _playerStreamAudioDevice = _player.stream.audioDevice.listen(
      (event) => audioDevice = event,
    );
    _playerStreamAudioDevices = _player.stream.audioDevices.listen(
      (event) => audioDevices = event,
    );

    unawaited(setAudioDevice());
    unawaited(setVolume(_volume));
  }

  void _updateProcessingState(AudioProcessingState newState) {
    if (_processingStateNotifier.value != newState) {
      _processingStateNotifier.value = newState;
      _processingStateController.add(newState);
    }
  }

  void setProcessingState(AudioProcessingState newState) {
    _updateProcessingState(processingState);
  }

  Future<void> play() async {
    _updateProcessingState(AudioProcessingState.ready);
    //TODO: add current song playing highlight/icon in queue
    await _player.play();
    return;
  }

  Future<void> pause() async {
    return _player.pause();
  }

  Future<void> close() async {
    await player.stop();
    _songValueNotifier.value = null;
    return;
  }

  Future<void> stop() async {
    await seekToStart();
    return _player.pause();
  }

  Future<void> seekToStart() async {
    await player.seek(Duration.zero);
    return _player.pause();
  }

  Future<void> dispose() async {
    await close();
    await _playerStreamBuffer?.cancel();
    await _playerStreamCompleted?.cancel();
    await _playerStreamPlaying?.cancel();
    await _playerStreamError?.cancel();
    await _mediaItemSubscription?.cancel();
    await _playerStreamAudioDevice?.cancel();
    await _playerStreamAudioDevices?.cancel();
    await _processingStateController.close();
    await _indexController.close();
    await _processingStateController.close();
    await _mediaItemStreamController.close();
    return _player.dispose();
  }

  Future<void> setShuffleMode(bool shuffle) async {
    _isShuffleEnabled = shuffle;
    return _player.setShuffle(shuffle);
  }

  Future<void> open(Media media) async {
    _updateProcessingState(AudioProcessingState.loading);
    _bufferStartNotifier.value = DateTime.now();
    return _player.open(media);
  }

  Future<void> prepare(SongBar songBar, {bool setMetadata = true}) async {
    if (setMetadata) {
      _updateProcessingState(AudioProcessingState.loading);
      songValueNotifier.value = songBar;
      await songBar.prepareSong();
      _mediaItemSubscription = songBar.mediaItemStream.listen(
        _mediaItemStreamController.add,
      );
    } else {
      unawaited(songBar.prepareSong());
    }
  }

  Future<void> queue(Media media) async {
    await open(media);
    await player.seek(Duration.zero);
    _updateProcessingState(AudioProcessingState.ready);
    return pause();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    _volumeNotifier.value = volume;
    return _player.setVolume(volume);
  }

  Future<void> seek(Duration duration) async {
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

  Future<void> setAudioDevice({AudioDevice? audioDevice}) async {
    await _player.setAudioDevice(audioDevice ?? AudioDevice.auto());
  }
}

class ReverbioAudioHandler extends BaseAudioHandler {
  ReverbioAudioHandler() {
    _setupEventSubscriptions();
    if (isMobilePlatform()) unawaited(getSession());
    _updatePlaybackState();
  }
  final AudioPlayerService audioPlayer = AudioPlayerService();
  audio_session.AudioSession? _session;
  Timer? _sleepTimer;
  bool sleepTimerExpired = false;
  late bool wasPlayingBeforeCall = false;
  NotifiableList<SongBar> get queueSongBars => audioPlayer.queueSongBars;
  late final StreamSubscription<bool?> _playbackEventSubscription;
  late final StreamSubscription<AudioProcessingState?> _stateChangeSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<int?> _currentIndexSubscription;
  late final StreamSubscription<Playlist?> _sequenceStateSubscription;
  late final StreamSubscription<PositionData> _positionDataSubscription;
  late final StreamSubscription<MediaItem?> _mediaItemSubscription;
  late final StreamSubscription<TaskUpdate?> _downloadStatusSubscription;
  late final StreamSubscription<audio_session.AudioInterruptionEvent>
  _sessionEventStream;
  final ValueNotifier<PositionData> positionDataNotifier = ValueNotifier(
    PositionData(Duration.zero, Duration.zero, Duration.zero),
  );
  Duration get position => audioPlayer.position;
  Duration get duration => audioPlayer.duration;
  bool get hasNext => audioPlayer.hasNext;
  bool get hasPrevious => audioPlayer.hasPrevious;
  ValueNotifier<SongBar?> get songValueNotifier =>
      audioPlayer.songValueNotifier;
  Stream<PositionData> get positionDataStream => audioPlayer.positionDataStream;
  Stream<AudioDevice> get audioDeviceStream => audioPlayer.audioDeviceStream;
  Stream<List<AudioDevice>> get audioDevicesStream =>
      audioPlayer.audioDevicesStream;
  double get volume => audioPlayer.volume;
  AudioProcessingState get state => audioPlayer.processingState;
  bool get playing => audioPlayer.playing;
  Stream<Duration> get positionStream => audioPlayer.positionStream;
  bool cachedIsPlaying = false;
  static const platform = MethodChannel(
    'com.akashskypatel.reverbio/audio_device_channel',
  );

  Future<void> dispose() async {
    await _playbackEventSubscription.cancel();
    await _stateChangeSubscription.cancel();
    await _durationSubscription.cancel();
    await _currentIndexSubscription.cancel();
    await _sequenceStateSubscription.cancel();
    await _positionDataSubscription.cancel();
    await _mediaItemSubscription.cancel();
    await _sessionEventStream.cancel();
    await _downloadStatusSubscription.cancel();
    await audioPlayer.dispose();
  }

  Future<audio_session.AudioSession> getSession() async {
    if (_session == null) {
      _session = await audio_session.AudioSession.instance;
      await _session!.configure(
        const audio_session.AudioSessionConfiguration.music(),
      );
      _sessionEventStream = _session!.interruptionEventStream.listen(
        _handleSessionEventChange,
      );
    }
    return _session!;
  }

  Future<bool> sessionActive({bool active = true}) async {
    return (!isMobilePlatform()) ||
        await (await getSession()).setActive(active);
  }

  @override
  Future<void> onTaskRemoved() async {
    await close();
    await super.onTaskRemoved();
  }

  @override
  Future<void> play() async {
    if (await sessionActive()) {
      await audioPlayer.play();
      audioPlayer.setProcessingState(AudioProcessingState.loading);
      _updatePlaybackState();
    }
  }

  @override
  Future<void> pause() async {
    await audioPlayer.pause();
    audioPlayer.setProcessingState(AudioProcessingState.ready);
    _updatePlaybackState();
    await sessionActive(active: false);
  }

  @override
  Future<void> stop() async {
    await audioPlayer.stop();
    audioPlayer.setProcessingState(AudioProcessingState.ready);
    _updatePlaybackState();
    await sessionActive(active: false);
  }

  @override
  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
    _updatePlaybackState();
  }

  @override
  Future<void> skipToNext({bool play = true, bool skipOnError = true}) async {
    final loopAllSongs = repeatNotifier.value == AudioServiceRepeatMode.all;
    if (!audioPlayer.hasNext && !loopAllSongs) return;
    if (audioPlayer.songValueNotifier.value?.song == null) return;
    final index = queueIndexOf(audioPlayer.songValueNotifier.value!);
    if (loopAllSongs && index == queueSongBars.length - 1) {
      await this.prepare(
        songBar: queueSongBars.first,
        play: play,
        skipOnError: skipOnError,
      );
      audioPlayer.skipToNext(0);
    } else if (index < queueSongBars.length - 1) {
      await this.prepare(
        songBar: queueSongBars[index + 1],
        play: play,
        skipOnError: skipOnError,
      );
      audioPlayer.skipToNext(index + 1);
    }
    _updatePlaybackState();
  }

  @override
  Future<void> skipToPrevious({
    bool play = true,
    bool skipOnError = true,
  }) async {
    final loopAllSongs = repeatNotifier.value == AudioServiceRepeatMode.all;
    if (!audioPlayer.hasPrevious && !loopAllSongs) return;
    if (audioPlayer.songValueNotifier.value == null) return;
    final index = queueIndexOf(audioPlayer.songValueNotifier.value!);
    if (loopAllSongs && index == 0) {
      await this.prepare(
        songBar: queueSongBars.last,
        play: play,
        skipOnError: skipOnError,
      );
      audioPlayer.skipToPrevious(queueSongBars.length - 1);
    } else if (index > 0) {
      await this.prepare(
        songBar: queueSongBars[index - 1],
        play: play,
        skipOnError: skipOnError,
      );
      audioPlayer.skipToPrevious(index - 1);
    }
    _updatePlaybackState();
  }

  @override
  Future<void> skipToQueueItem(int index, {bool play = true}) async {
    index = min(index, queueSongBars.length - 1);
    await this.prepare(songBar: queueSongBars[index], play: play);
    _updatePlaybackState();
  }

  Future<void> skipToRandom({bool play = true}) async {
    final index = min(
      Random().nextInt(queueSongBars.length - 1),
      queueSongBars.length - 1,
    );
    await this.prepare(songBar: queueSongBars[index], play: play);
    _updatePlaybackState();
  }

  @override
  Future<void> seekForward(bool begin) async {
    if (begin)
      await seekToStart();
    else
      await seek(Duration(seconds: audioPlayer.position.inSeconds + 15));
    _updatePlaybackState();
  }

  @override
  Future<void> seekBackward(bool begin) async {
    if (begin)
      await seekToStart();
    else
      await seek(Duration(seconds: audioPlayer.position.inSeconds - 15));
    _updatePlaybackState();
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    return queueSongBars.map((songBar) => songBar.mediaItem).toList();
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    try {
      return queueSongBars
          .firstWhere((songBar) => songBar.mediaItem.id == mediaId)
          .mediaItem;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> onNotificationDeleted() async {
    await onTaskRemoved();
  }

  @override
  Future<void> prepare({
    SongBar? songBar,
    bool play = false,
    bool skipOnError = false,
    int skipCount = 0,
  }) async {
    try {
      if (songBar != null && !isSongInQueue(songBar)) {
        addSongToQueue(songBar);
      }
      if (queueSongBars.isEmpty) return;
      songValueNotifier.value?.songPrepareTracker.value?.cancel();
      audioPlayer.setProcessingState(AudioProcessingState.loading);
      songBar = songBar ?? audioPlayer.queueSongBars.first;
      await audioPlayer.prepare(songBar);
      if (!songBar.isError &&
          songBar.media != null &&
          !(songBar.songPrepareTracker.value?.isCancelled ?? true)) {
        await audioPlayer.queue(songBar.media!);
        if (play && !(songBar.songPrepareTracker.value?.isCancelled ?? true)) {
          await this.play();
        }
      } else if (skipOnError &&
          audioPlayer.queueSongBars.length > 1 &&
          songBar.isError) {
        if (skipCount < audioPlayer.queueSongBars.length || skipCount <= 10) {
          final next = nextSongBar(
            songBar,
            songBars: audioPlayer.queueSongBars,
          );
          if (next != null &&
              !(songBar.songPrepareTracker.value?.isCancelled ?? true)) {
            await Future.delayed(const Duration(seconds: 3));
            await prepare(
              songBar: next,
              play: play,
              skipOnError: skipOnError,
              skipCount: skipCount + 1,
            );
            return;
          }
        } else {
          showToast(
            songBar.context.l10n!.errorCouldNotFindAStream,
            context: songBar.context,
          );
        }
      }
      if (prepareNextSong.value) {
        final next = nextSongBar(songBar, songBars: audioPlayer.queueSongBars);
        if (next != null &&
            !(songBar.songPrepareTracker.value?.isCancelled ?? true))
          unawaited(audioPlayer.prepare(next, setMetadata: false));
      }
    } catch (e, stackTrace) {
      if (!(e is CancelledException))
        logger.log(
          'Error in ${stackTrace.getCurrentMethodName()}',
          e,
          stackTrace,
        );
    }
  }

  Future<void> close() async {
    try {
      cachedIsPlaying = false;
      songValueNotifier.value?.songPrepareTracker.value?.cancel();
      if (prepareNextSong.value && songValueNotifier.value != null) {
        final next = nextSongBar(
          songValueNotifier.value!,
          songBars: audioPlayer.queueSongBars,
        );
        next?.songPrepareTracker.value?.cancel();
      }
      await audioPlayer.close();
      queue.add([]);
      playbackState.add(PlaybackState());
      mediaItem.add(null);
      await sessionActive(active: false);
    } catch (e, stackTrace) {
      if (!(e is CancelledException))
        logger.log(
          'Error in ${stackTrace.getCurrentMethodName()}',
          e,
          stackTrace,
        );
    }
  }

  Future<void> setVolume(double volume) => audioPlayer.setVolume(volume);
  Future<void> seekToStart() => audioPlayer.seekToStart();

  Future<void> setAudioDevice(dynamic device) async {
    try {
      if (Platform.isAndroid) {
        final devices = await getConnectedAudioDevices();
        if (devices.where((e) => e['id'] == device['id']).isNotEmpty)
          await platform.invokeMethod<dynamic>('setAudioOutputDevice', {
            'deviceId': device['id'],
          });
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()} change',
        e,
        stackTrace,
      );
      throw Exception(e.toString());
    }
  }

  Future<bool> getAndroidAutoDevMode() async {
    try {
      if (Platform.isAndroid) {
        final devMode = await platform.invokeMethod<dynamic>(
          'getAndroidAutoDevMode',
        );
        return devMode;
      }
      return false;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()} change',
        e,
        stackTrace,
      );
      throw Exception(e.toString());
    }
  }

  Future<dynamic> getCurrentAudioDevice() async {
    try {
      if (Platform.isAndroid) {
        final device = await platform.invokeMethod<dynamic>(
          'getCurrentAudioDevice',
        );
        audioDevice.value = device;
        return device;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()} change',
        e,
        stackTrace,
      );
      throw Exception(e.toString());
    }
  }

  Future<List<dynamic>> getConnectedAudioDevices() async {
    try {
      if (Platform.isAndroid) {
        final devices =
            (await platform.invokeMethod<List>('getAudioOutputDevices')) ??
            <dynamic>[];

        return devices;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()} change',
        e,
        stackTrace,
      );
      throw Exception(e.toString());
    }
    return [];
  }

  Future<void> _handleDeviceEventChange(
    audio_session.AudioDevicesChangedEvent event,
  ) async {}

  void _handleSessionEventChange(audio_session.AudioInterruptionEvent event) {
    if (event.begin) {
      switch (event.type) {
        case audio_session.AudioInterruptionType.duck:
          // Another app started playing audio and we should duck.
          if (audioPlayer.playing) unawaited(setVolume(audioPlayer.volume / 2));
          break;
        case audio_session.AudioInterruptionType.pause:
        case audio_session.AudioInterruptionType.unknown:
          // Another app started playing audio and we should pause.
          if (audioPlayer.playing) unawaited(pause());
          break;
      }
    } else {
      switch (event.type) {
        case audio_session.AudioInterruptionType.duck:
          // The interruption ended and we should unduck.
          if (audioPlayer.playing) unawaited(setVolume(audioPlayer.volume * 2));
          break;
        case audio_session.AudioInterruptionType.pause:
          // The interruption ended and we should resume.
          if (cachedIsPlaying) unawaited(play());
        case audio_session.AudioInterruptionType.unknown:
          // The interruption ended but we should not resume.
          break;
      }
    }
  }

  Future<void> _handlePlaybackEvent(bool playing) async {
    try {
      if (playing &&
          audioPlayer.processingState == AudioProcessingState.completed &&
          !sleepTimerExpired) {
        await skipToNext();
      }
    } catch (e, stackTrace) {
      logger.log('Error handling playback event', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _handleStateChangeSubscription(AudioProcessingState state) {
    _updatePlaybackState();
  }

  void _handleMediaItemChange(MediaItem _mediaItem) {
    mediaItem.add(_mediaItem);
    _updatePlaybackState();
  }

  void _handleDurationChange(Duration? duration) {
    try {} catch (e, stackTrace) {
      logger.log('Error handling duration change', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _handleCurrentSongIndexChanged(int? index) {
    try {} catch (e, stackTrace) {
      logger.log('Error handling current song index change', e, stackTrace);
    }
    _updatePlaybackState();
  }

  void _handleSequenceStateChange(Playlist? playlist) {
    try {
      settings.shuffleNotifier.value = audioPlayer.shuffleModeEnabled;
    } catch (e, stackTrace) {
      logger.log('Error handling sequence state change', e, stackTrace);
    }
    _updatePlaybackState();
  }

  Future<void> _positionDataNotify(PositionData value) async {
    positionDataNotifier.value = value;
    if (((value.duration - value.position).inMilliseconds / 10) <= 100 &&
        value.duration != Duration.zero &&
        value.position != Duration.zero) {
      switch (repeatNotifier.value) {
        case AudioServiceRepeatMode.one:
          await this.prepare(
            songBar: audioPlayer.songValueNotifier.value,
            play: true,
          );
          break;
        default:
          if (shuffleNotifier.value &&
              audioPlayer.processingState == AudioProcessingState.completed)
            await skipToRandom();
          else if (audioPlayer.processingState ==
              AudioProcessingState.completed)
            await skipToNext();
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
            (jsonDecode(jsonEncode(song['skipSegments'])) as List)
                .cast<Map<String, dynamic>>()
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
            if (seekTo != null) {
              if (((value.duration.inMicroseconds - seekTo) ~/ 1000) <= 100)
                await audioHandler.skipToNext();
              await audioHandler.seek(Duration(microseconds: seekTo));
            }
        }
      }
    }
    _updatePlaybackState();
  }

  void _setupEventSubscriptions() {
    _downloadStatusSubscription = FileDownloader().updates.listen(
      _handleFileDownloadState,
    );
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

  void _handleFileDownloadState(TaskUpdate update) {
    try {
      switch (update) {
        case TaskStatusUpdate():
          // process the TaskStatusUpdate, e.g.
          switch (update.status) {
            case TaskStatus.enqueued:
              showToast(
                '${L10n.current.downloadingInBackground}: "${update.task.displayName}"',
                id: update.task.taskId,
                data: ValueNotifier<int>(0),
              );
              break;
            case TaskStatus.complete:
              userOfflineSongs.addOrUpdate(update.task.taskId, checkEntityId);
              showToast(
                '${L10n.current.downloaded}: "${update.task.displayName}"',
                id: update.task.taskId,
              );
              unawaited(
                FileTagger(
                  offlineDirectory: offlineDirectory.value!,
                ).tagOfflineFile(update.task.taskId, update.task.taskId),
              );
              break;
            case TaskStatus.canceled:
              showToast(
                '${L10n.current.downloadCancelled}: "${update.task.displayName}"',
                id: update.task.taskId,
              );
              break;
            case TaskStatus.paused:
              showToast(
                '${L10n.current.downloadPaused}: "${update.task.displayName}"',
                id: update.task.taskId,
              );
              break;
            default:
              break;
          }
        case TaskProgressUpdate():
          final progress = notificationLog[update.task.taskId]?['data'];
          if (progress is ValueNotifier<int>) {
            progress.value = (update.progress * 100).toInt();
          }
          break;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()} change',
        e,
        stackTrace,
      );
    }
  }

  void _updatePlaybackState() {
    cachedIsPlaying = audioPlayer.playing;
    Future.microtask(() {
      final newMediaItem = songValueNotifier.value?.mediaItem.copyWith(
        duration: audioHandler.duration,
      );
      if (newMediaItem != mediaItem.value) mediaItem.add(newMediaItem);
      if (mediaItem.value == null)
        playbackState.add(PlaybackState());
      else {
        final newPlaybackState = playbackState.value.copyWith(
          controls: [
            if (hasPrevious)
              MediaControl.skipToPrevious
            else
              MediaControl.rewind,
            if (audioPlayer.playing) MediaControl.pause else MediaControl.play,
            if (hasNext) MediaControl.skipToNext else MediaControl.fastForward,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
            MediaAction.seek,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
            MediaAction.skipToQueueItem,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: audioPlayer.processingState,
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
        );
        if (playbackState.value != newPlaybackState)
          playbackState.add(newPlaybackState);
      }
    });
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

  void changeSponsorBlockStatus() async {
    settings.sponsorBlockSupport.value = !settings.sponsorBlockSupport.value;
  }

  void changeAutoPlayNextStatus() async {
    settings.playNextSongAutomatically.value =
        !settings.playNextSongAutomatically.value;
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
    audioHandler.queue.add(audioHandler.queue.value + [songBar.mediaItem]);
  }
}

bool removeSongFromQueue(SongBar songBar) {
  final val = activeQueue['list'].remove(songBar.song);
  audioHandler.queueSongBars.removeWhere((e) {
    return e.equals(songBar);
  });
  updateMediaItemQueue(audioHandler.queueSongBars);
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

SongBar? nextSongBar(SongBar songBar, {List<SongBar>? songBars}) {
  final list = songBars != null ? songBars : audioHandler.queueSongBars;
  final length = list.length;
  final index = list.indexWhere((e) => e.equals(songBar));
  if (index < 0 || index + 1 >= list.length) return null;
  if (length == 1) return songBar;
  if (index == (length - 1) &&
      repeatNotifier.value == AudioServiceRepeatMode.all)
    return list[0];
  return list[index + 1];
}

SongBar? previousSongBar(SongBar songBar, {List<SongBar>? songBars}) {
  final list = songBars != null ? songBars : audioHandler.queueSongBars;
  final length = list.length;
  final index = list.indexWhere((e) => e.equals(songBar));
  if (index < 0 || index - 1 < 0) return null;
  if (length == 1) return songBar;
  if (index == 0 && repeatNotifier.value == AudioServiceRepeatMode.all)
    return list[length - 1];
  return list[index - 1];
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
}
