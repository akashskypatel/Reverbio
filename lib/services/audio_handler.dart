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
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/services/audio_player_service.dart';
import 'package:reverbio/services/queue_manager.dart';
import 'package:reverbio/services/settings_manager.dart' as settings;
import 'package:reverbio/utilities/file_tagger.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/mediaitem.dart';
import 'package:reverbio/utilities/notifiable_future.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/song_bar.dart';

/// Phase 4.B.4: ReverbioAudioHandler - OS audio integration
/// Handles audio service integration, media controls, and playback events

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
  // R14 fix: Removed unused wasPlayingBeforeCall variable
  NotifiableList<SongBar> get queueSongBars => audioPlayer.queueSongBars;
  late final StreamSubscription<bool?> _playbackEventSubscription;
  late final StreamSubscription<AudioProcessingState?> _stateChangeSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<int?> _currentIndexSubscription;
  late final StreamSubscription<Playlist?> _sequenceStateSubscription;
  late final StreamSubscription<PositionData> _positionDataSubscription;
  late final StreamSubscription<MediaItem?> _mediaItemSubscription;
  late final StreamSubscription<TaskUpdate?> _downloadStatusSubscription;
  // R2 fix: Make nullable to prevent LateInitializationError on non-mobile
  StreamSubscription<audio_session.AudioInterruptionEvent>? _sessionEventStream;
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
  // R8 fix: Store original volume before ducking to restore on unduck
  double? _volumeBeforeDucking;
  // R11 fix: Re-entrancy guard to prevent concurrent skip calls
  bool _isSkipping = false;
  // R2 fix: Re-entrancy guard to prevent concurrent position updates
  bool _isPositionUpdating = false;

  Future<void> dispose() async {
    await _playbackEventSubscription.cancel();
    await _stateChangeSubscription.cancel();
    await _durationSubscription.cancel();
    await _currentIndexSubscription.cancel();
    await _sequenceStateSubscription.cancel();
    await _positionDataSubscription.cancel();
    await _mediaItemSubscription.cancel();
    // R2 fix: Use null-aware cancel for nullable _sessionEventStream
    await _sessionEventStream?.cancel();
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
    // R11 fix: Re-entrancy guard to prevent concurrent skip calls
    if (_isSkipping) return;
    _isSkipping = true;
    try {
      final loopAllSongs = settings.repeatNotifier.value == AudioServiceRepeatMode.all;
      // R9 fix: Allow repeat-all wrap-around by not returning early
      if (!audioPlayer.hasNext && !loopAllSongs) {
        _updatePlaybackState();  // R176 fix: Update state before early return
        return;
      }
      if (audioPlayer.songValueNotifier.value?.song == null) {
        _updatePlaybackState();  // R177 fix: Update state before early return
        return;
      }
      final index = queueIndexOf(audioPlayer.songValueNotifier.value!);
      // R9 fix: Properly handle repeat-all wrap-around
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
    } finally {
      _isSkipping = false;
    }
  }

  @override
  Future<void> skipToPrevious({
    bool play = true,
    bool skipOnError = true,
  }) async {
    final loopAllSongs = settings.repeatNotifier.value == AudioServiceRepeatMode.all;
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
    // R4 fix: Guard against empty queue
    if (queueSongBars.isEmpty) return;
    // Fix: Clamp index to valid [0, length-1] range to prevent RangeError on negative indices
    index = index.clamp(0, queueSongBars.length - 1);
    await this.prepare(songBar: queueSongBars[index], play: play);
    _updatePlaybackState();
  }

  Future<void> skipToRandom({bool play = true}) async {
    // R3 fix: Guard against single-item queue
    if (queueSongBars.length <= 1) return;
    // Fix: Exclude current song index to ensure we actually skip to a different song
    final random = Random();
    var index = random.nextInt(queueSongBars.length);
    // Fix: Add null check before force-unwrap
    final currentSong = audioPlayer.songValueNotifier.value;
    final currentIndex = currentSong != null
        ? queueSongBars.indexWhere((e) => e.equals(currentSong))
        : -1;
    // Re-roll if we picked the current song (max 10 attempts to avoid infinite loop)
    var attempts = 0;
    while (index == currentIndex && attempts < 10) {
      index = random.nextInt(queueSongBars.length);
      attempts++;
    }
    await this.prepare(songBar: queueSongBars[index], play: play);
    _updatePlaybackState();
  }

  @override
  Future<void> seekForward(bool begin) async {
    // R5 fix: Properly implement forward seek (skip seekToStart)
    // Seek on button press (begin=true), not release (begin=false)
    if (begin) {
      final duration = audioPlayer.duration;
      final newPosition = audioPlayer.position.inSeconds + 15;
      // R27 fix: Clamp position to valid [0, duration] range
      final clampedPosition = duration.inSeconds > 0
          ? newPosition.clamp(0, duration.inSeconds)
          : newPosition;
      await seek(Duration(seconds: clampedPosition));
    }
    _updatePlaybackState();
  }

  @override
  Future<void> seekBackward(bool begin) async {
    // R5 fix: Properly implement backward seek (skip seekToStart)
    // Seek on button press (begin=true), not release (begin=false)
    if (begin) {
      final newPosition = audioPlayer.position.inSeconds - 15;
      // R27 fix: Clamp position to valid [0, duration] range
      final clampedPosition = newPosition.clamp(0, double.infinity);
      await seek(Duration(seconds: clampedPosition.toInt()));
    }
    _updatePlaybackState();
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    return queueSongBars.map((songBar) => songBar.mediaItem).whereType<MediaItem>().toList();
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    try {
      return queueSongBars
          .firstWhere((songBar) => songBar.mediaItem?.id == mediaId)
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
            L10n.current.errorCouldNotFindAStream,
          );
        }
      }
      if (settings.prepareNextSong.value) {
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
      if (settings.prepareNextSong.value && songValueNotifier.value != null) {
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
          await audioChannel.invokeMethod<dynamic>('setAudioOutputDevice', {
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

  // R24 fix: Properly cast dynamic return to bool
  Future<bool> getAndroidAutoDevMode() async {
    try {
      if (Platform.isAndroid) {
        final devMode = await audioChannel.invokeMethod<dynamic>(
          'getAndroidAutoDevMode',
        );
        return devMode as bool;
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

  // R17 fix: Added explicit return null for non-Android and fixed return type
  Future<dynamic> getCurrentAudioDevice() async {
    try {
      if (Platform.isAndroid) {
        final device = await audioChannel.invokeMethod<dynamic>(
          'getCurrentAudioDevice',
        );
        settings.audioDevice.value = device;
        return device;
      }
      return null;  // R17 fix: Explicit return for non-Android
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
            (await audioChannel.invokeMethod<List>('getAudioOutputDevices')) ??
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

  // R15 fix: Removed empty _handleDeviceEventChange stub - never connected to any stream

  void _handleSessionEventChange(audio_session.AudioInterruptionEvent event) {
    if (event.begin) {
      switch (event.type) {
        case audio_session.AudioInterruptionType.duck:
          // R8 fix: Store original volume before ducking
          _volumeBeforeDucking ??= audioPlayer.volume;
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
          // R8 fix: Restore original volume on unduck
          if (audioPlayer.playing && _volumeBeforeDucking != null) {
            unawaited(setVolume(_volumeBeforeDucking!));
            _volumeBeforeDucking = null;
          }
          break;
        case audio_session.AudioInterruptionType.pause:
          // The interruption ended and we should resume.
          if (cachedIsPlaying) unawaited(play());
          // R12 fix: Add missing break to prevent fall-through
          break;
        case audio_session.AudioInterruptionType.unknown:
          // The interruption ended but we should not resume.
          break;
      }
    }
  }

  Future<void> _handlePlaybackEvent(bool playing) async {
    try {
      // R10/R11 fix: Only skip on song completion, not during skip segment handling
      if (playing &&
          audioPlayer.processingState == AudioProcessingState.completed &&
          !sleepTimerExpired &&
          !_isSkipping) {
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

  // R16 fix: Simplified _handleDurationChange - removed empty try-catch
  void _handleDurationChange(Duration? duration) {
    _updatePlaybackState();
  }

  // R16 fix: Simplified _handleCurrentSongIndexChanged - removed empty try-catch
  void _handleCurrentSongIndexChanged(int? index) {
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
    // R2 fix: Re-entrancy guard to prevent concurrent position updates
    if (_isPositionUpdating) return;
    _isPositionUpdating = true;
    try {
      positionDataNotifier.value = value;
      // R10/R11 fix: Use else branches to prevent multiple skip triggers
      if (((value.duration - value.position).inMilliseconds / 10) <= 100 &&
          value.duration != Duration.zero &&
          value.position != Duration.zero) {
        switch (settings.repeatNotifier.value) {
          case AudioServiceRepeatMode.one:
            await this.prepare(
              songBar: audioPlayer.songValueNotifier.value,
              play: true,
            );
            break;
          default:
            // R10/R11 fix: Only skip if not already skipping and song not completed
            // (_handlePlaybackEvent handles completion skip)
            if (!_isSkipping &&
                audioPlayer.processingState != AudioProcessingState.completed) {
              if (settings.shuffleNotifier.value)
                await skipToRandom();
              else
                await skipToNext();
            }
            break;
        }
      } else if (value.duration != value.position &&
          value.duration != Duration.zero &&
          value.position != Duration.zero) {
        // R10 fix: Use else if to prevent double-trigger with above block
        final song = audioPlayer.songValueNotifier.value?.song;
        if (song != null &&
            song['skipSegments'] != null &&
            song['skipSegments'].isNotEmpty) {
          // R23 fix: Removed unnecessary JSON round-trip (jsonDecode/jsonEncode)
          final checkSegment =
              (song['skipSegments'] as List)
                  .whereType<Map<String, dynamic>>()
                  .where(
                    (e) =>
                        e['start']! <= value.position.inMicroseconds &&
                        e['end']! > value.position.inMicroseconds,
                  )
                  .toList();
          if (checkSegment.isNotEmpty) {
            final seekTo = checkSegment.first['end'];
            final category = checkSegment.first['category'];
            if ((category == 'sponsor' && settings.sponsorBlockSupport.value) ||
                (category != 'sponsor' && settings.skipNonMusic.value))
              if (seekTo != null) {
                // R626 fix: Only skip to next if segment ends near song end AND not already skipping
                if (((value.duration.inMicroseconds - seekTo) ~/ 1000) <= 100 &&
                    !_isSkipping) {
                  await this.skipToNext();
                  // R626 fix: Don't seek after skipToNext - that would corrupt the next song's position
                } else {
                  // R626 fix: Only seek if we're not skipping to next song
                  await this.seek(Duration(microseconds: seekTo));
                }
              }
          }
        }
      }
      _updatePlaybackState();
    } finally {
      _isPositionUpdating = false;
    }
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
                FileTagger().tagOfflineFile(
                  update.task.taskId,
                  id: update.task.taskId,
                ),
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
      try {
        final currentMediaItem = songValueNotifier.value?.mediaItem;
        final newMediaItem = currentMediaItem?.copyWith(
          duration: audioHandler.duration,
        );
        if (newMediaItem != null && newMediaItem != mediaItem.value) mediaItem.add(newMediaItem);
        if (mediaItem.value == null)
          playbackState.add(PlaybackState());
        else {
          final newPlaybackState = playbackState.value.copyWith(
            controls: [
              if (hasPrevious)
                MediaControl.skipToPrevious
              else
                MediaControl.rewind,
              if (audioPlayer.playing)
                MediaControl.pause
              else
                MediaControl.play,
              if (hasNext)
                MediaControl.skipToNext
              else
                MediaControl.fastForward,
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
      } catch (e, stackTrace) {
        logger.log(
          'Error in ${stackTrace.getCurrentMethodName()} change',
          e,
          stackTrace,
        );
      }
    });
  }

  Future<Media> buildAudioSource(SongBar songBar) async {
    return buildAudioSourceFromMap(songBar.song);
  }

  Future<Media> buildAudioSourceFromMap(Map<String, dynamic> song) async {
    final extras = songToMediaExtras(song);
    final offlinePath = await getOfflinePath(song);
    if (offlinePath != null &&
        isFilePath(offlinePath) &&
        doesFileExist(offlinePath)) {
      final uri = Uri.file(offlinePath);
      final media = Media(uri.toString(), extras: extras);
      return media;
    }

    // R22 fix: Null-check songUrl before constructing Media
    final songUrl = song['songUrl'] as String?;
    if (songUrl == null || songUrl.isEmpty) {
      throw StateError('songUrl is null or empty');
    }

    final uri = Uri.parse(songUrl);
    final audioSource = Media(uri.toString(), extras: extras);

    if (!settings.sponsorBlockSupport.value) {
      return audioSource;
    }

    if (song['source'] == 'youtube' && !settings.offlineMode.value)
      song['skipSegments'] = await getSkipSegments(
        song['ytid'],
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

  // R19 fix: Store original playNextSongAutomatically value to restore on cancel
  bool? _playNextSongBeforeSleepTimer;

  Future<void> setSleepTimer(Duration duration) async {
    _sleepTimer?.cancel();
    sleepTimerExpired = false;
    // R19 fix: Save original value before mutating settings
    _playNextSongBeforeSleepTimer = settings.playNextSongAutomatically.value;
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
      // R19 fix: Restore original playNextSongAutomatically value
      if (_playNextSongBeforeSleepTimer != null) {
        settings.playNextSongAutomatically.value = _playNextSongBeforeSleepTimer!;
        _playNextSongBeforeSleepTimer = null;
      }
    }
  }

  void changeSponsorBlockStatus() async {
    settings.sponsorBlockSupport.value = !settings.sponsorBlockSupport.value;
  }

  void changeAutoPlayNextStatus() async {
    settings.playNextSongAutomatically.value =
        !settings.playNextSongAutomatically.value;
  }
}
