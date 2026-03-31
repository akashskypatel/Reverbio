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

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/services/settings_manager.dart' as settings;
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:rxdart/rxdart.dart';

/// Phase 4.B.2: AudioPlayerService - MediaKit Player wrapper
/// Handles low-level audio playback, streams, and device management

class AudioPlayerService {
  AudioPlayerService() {
    MediaKit.ensureInitialized();
    _initialize();
  }

  late final Player _player = Player();
  bool _isShuffleEnabled = false;
  late double _volume;

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
    final index = _queueSongBars.indexWhere((e) => e.equals(songValueNotifier.value!));
    if (index == -1 || index >= _queueSongBars.length - 1) return false;
    return true;
  }

  bool get hasPrevious {
    if (songValueNotifier.value == null) return false;
    final index = _queueSongBars.indexWhere((e) => e.equals(songValueNotifier.value!));
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
    // R1 fix: Use newState argument instead of ignoring it
    _updateProcessingState(newState);
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
    // R7 fix: Remove duplicate _processingStateController.close()
    await _processingStateController.close();
    await _indexController.close();
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
      // R6 fix: Cancel existing subscription before creating new one
      await _mediaItemSubscription?.cancel();
      if (songBar.mediaItemStream != null) {
        _mediaItemSubscription = songBar.mediaItemStream!.listen(
          _mediaItemStreamController.add,
        );
      }
    } else {
      unawaited(songBar.prepareSong());
    }
  }

  Future<void> queue(Media media) async {
    await open(media);
    await seek(Duration.zero);
    _updateProcessingState(AudioProcessingState.ready);
    return pause();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    _volumeNotifier.value = volume;
    // R5 fix: Persist volume to settings
    settings.volume.value = volume.toInt();
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

  // R27 fix: Seek forward with position clamping
  Future<void> seekForward(bool begin) async {
    if (begin) {
      final duration = _player.state.duration;
      final newPosition = _player.state.position.inSeconds + 15;
      final clampedPosition = duration.inSeconds > 0
          ? newPosition.clamp(0, duration.inSeconds)
          : newPosition;
      await seek(Duration(seconds: clampedPosition));
    }
  }

  // R27 fix: Seek backward with position clamping
  Future<void> seekBackward(bool begin) async {
    if (begin) {
      final newPosition = _player.state.position.inSeconds - 15;
      final clampedPosition = newPosition.clamp(0, double.infinity);
      await seek(Duration(seconds: clampedPosition.toInt()));
    }
  }
}
