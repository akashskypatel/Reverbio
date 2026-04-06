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
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/queue_manager.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/mediaitem.dart';
import 'package:reverbio/utilities/notifiable_future.dart';
import 'package:reverbio/utilities/utils.dart';

/// A1 fix: Extract song preparation business logic from SongBar widget
/// This controller handles all song metadata preparation, YouTube linking,
/// and MediaItem conversion to keep the widget layer clean.
class SongPreparationController extends ChangeNotifier {
  SongPreparationController({
    required this.song,
    required this.songFuture,
  });

  final Map<String, dynamic> song;
  final NotifiableFuture<Map<String, dynamic>> songFuture;

  // A1 fix: Extract all ValueNotifiers from _SongBarState
  final ValueNotifier<bool> isVisible = ValueNotifier(true);
  final ValueNotifier<bool> isErrorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isPreparedNotifier = ValueNotifier(false);
  final ValueNotifier<MediaItem?> mediaItemNotifier = ValueNotifier(null);
  final ValueNotifier<Media?> mediaNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>> songMetadataNotifier =
      ValueNotifier({});
  final ValueNotifier<int> statusNotifier = ValueNotifier(0);
  final ValueNotifier<BorderRadius> borderRadiusNotifier =
      ValueNotifier(BorderRadius.zero);
  final ValueNotifier<NotifiableFuture<void>?> songPrepareTracker =
      ValueNotifier(null);
  // E1a fix: Extract like status notifier
  final ValueNotifier<bool> isLikedNotifier = ValueNotifier(false);
  // E1b fix: Extract download status notifier (true = downloaded, false = not downloaded)
  final ValueNotifier<bool> isDownloadedNotifier = ValueNotifier(false);
  final _mediaItemStreamController = StreamController<MediaItem>.broadcast();
  Stream<MediaItem> get mediaItemStream => _mediaItemStreamController.stream;
  void addMediaItemToStream(MediaItem item) => _mediaItemStreamController.add(item);

  // A1 fix: Track preparation state to prevent race conditions
  bool isPreparing = false;

  bool get isError => isErrorNotifier.value;
  bool get isLoading => isLoadingNotifier.value;
  bool get isPrepared => isPreparedNotifier.value;
  MediaItem? get mediaItem => mediaItemNotifier.value;
  Media? get media => mediaNotifier.value;

  @override
  void dispose() {
    isVisible.dispose();
    isErrorNotifier.dispose();
    isLoadingNotifier.dispose();
    isPreparedNotifier.dispose();
    mediaItemNotifier.dispose();
    mediaNotifier.dispose();
    songMetadataNotifier.dispose();
    statusNotifier.dispose();
    borderRadiusNotifier.dispose();
    songPrepareTracker.dispose();
    isLikedNotifier.dispose();
    isDownloadedNotifier.dispose();
    _mediaItemStreamController.close();
    super.dispose();
  }

  /// A1 fix: Prepare song metadata (moved from _SongBarState._prepareSong)
  Future<void> prepareSong() async {
    if (isPreparing) return;
    isPreparing = true;
    try {
      final _song = copyMap(songMetadataNotifier.value)
        ..addAll(songFuture.resultOrData ?? {});
      songMetadataNotifier.value = _song;
      isLoadingNotifier.value = true;
      statusNotifier.value = 1;
      songFuture.copyValuesFrom(getMetadataFuture(isPrepare: true));
      await songFuture.completerFuture;
      await getSongUrl(song).then((value) {
        final _song = copyMap(songMetadataNotifier.value)..addAll(value);
        songMetadataNotifier.value = _song;
      });
      if (song['songUrl'] == null || await checkUrl(song['songUrl']) >= 400) {
        final _song = copyMap(songMetadataNotifier.value)
          ..['songUrl'] = null
          ..['isError'] = true
          ..['error'] = L10n.current.urlError;
        songMetadataNotifier.value = _song;
      }
      await _updateMediaItem();
      isPreparedNotifier.value = true;
      statusNotifier.value = 0;
      statusNotifier.value = song.containsKey('isError')
          ? ((song['isError'] ?? false) ? 3 : 0)
          : 0;
      isErrorNotifier.value =
          song.containsKey('isError') ? song['isError'] : false;
      isLoadingNotifier.value = false;
    } catch (e, stackTrace) {
      isLoadingNotifier.value = false;
      isErrorNotifier.value = true;
      statusNotifier.value = 3;
      logger.log(
        'Error in prepareSong:',
        e,
        stackTrace,
      );
    } finally {
      isPreparing = false;
    }
    if (isErrorNotifier.value) {
      showToast(L10n.current.errorCouldNotFindAStream);
    }
    final _song = copyMap(songMetadataNotifier.value)
      ..addAll(songFuture.resultOrData ?? {});
    songMetadataNotifier.value = _song;
    notifyListeners();
  }

  /// A1 fix: Get YouTube song (moved from _SongBarState.getYtSong)
  Future<void> getYtSong(String? newYtid) async {
    if (!isSongValid(song)) return;
    isLoadingNotifier.value = true;
    statusNotifier.value = 1;
    final ytSong = await findYTSong(song, newYtid: newYtid);
    final ytid = (song['ytid'] ?? song['id']) as String? ?? '';
    if (ytid.isNotEmpty && isYouTubeSongValid(ytSong)) {
      final _song = copyMap(ytSong)..addAll(songFuture.resultOrData ?? {});
      songMetadataNotifier.value = _song;
      isLoadingNotifier.value = false;
      statusNotifier.value = 0;
    } else {
      isLoadingNotifier.value = false;
      isErrorNotifier.value = true;
      statusNotifier.value = 3;
    }
    if (isErrorNotifier.value) {
      showToast(L10n.current.errorCouldNotFindAStream);
    }
    notifyListeners();
  }

  /// A1 fix: Get metadata future (moved from _SongBarState.getMetadataFuture)
  NotifiableFuture<Map<String, dynamic>> getMetadataFuture({
    bool isPrepare = false,
  }) {
    try {
      if (!isSongValid(song) ||
          (!isMusicbrainzSongValid(song) && isPrepare)) {
        return queueSongInfoRequest(song);
      } else {
        return NotifiableFuture.fromValue(song);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in getMetadataFuture:',
        e,
        stackTrace,
      );
      return NotifiableFuture.fromValue(song);
    }
  }

  /// A1 fix: Update MediaItem (moved from _SongBarState._updateMediaItem)
  Future<void> _updateMediaItem() async {
    song['image'] = (await getValidImage(song))?.toString();
    mediaItemNotifier.value = mapToMediaItem(song);
    _mediaItemStreamController.add(mediaItemNotifier.value!);
    if (song['songUrl'] != null && !isErrorNotifier.value) {
      mediaNotifier.value = await audioHandler.buildAudioSourceFromMap(song);
    }
    notifyListeners();
  }

  /// A1 fix: Prepare song with tracker (moved from _SongBarState.prepareSong wrapper)
  Future<void> prepareWithTracker() async {
    songPrepareTracker.value = NotifiableFuture();
    await songPrepareTracker.value!.runFuture(prepareSong());
  }

  /// A1 fix: Set border radius (moved from _SongBarState.setBorder)
  void setBorder({BorderRadius borderRadius = BorderRadius.zero}) {
    borderRadiusNotifier.value = borderRadius;
  }

  /// A1 fix: Set visibility (moved from _SongBarState.setVisibility)
  bool setVisibility(bool show) {
    isVisible.value = show;
    return show;
  }

  // E1a fix: Toggle like status (moved from _SongBarState.likeItem)
  void toggleLike() {
    final isLiked = isLikedNotifier.value;
    updateSongLikeStatus(song, !isLiked);
    isLikedNotifier.value = !isLiked;
    notifyListeners();
  }

  // E1b fix: Trigger download (moved from _SongBarState._onDownload)
  Future<void> triggerDownload() async {
    try {
      await makeSongOffline(song);
      isDownloadedNotifier.value = true;
      notifyListeners();
    } catch (e, stackTrace) {
      logger.log('Error in triggerDownload:', e, stackTrace);
    }
  }

  // E1b fix: Remove from offline (moved from _SongBarState._onRemoveDownload)
  Future<void> removeDownload() async {
    try {
      await removeSongFromOffline(song);
      isDownloadedNotifier.value = false;
      notifyListeners();
    } catch (e, stackTrace) {
      logger.log('Error in removeDownload:', e, stackTrace);
    }
  }

  // E1c fix: Add to queue — calls queue_manager.addSongToQueue
  void addToQueue() {
    addSongToQueue(song);
    notifyListeners();
  }

  // E1c fix: Remove from queue — calls queue_manager.removeSongFromQueue
  void removeFromQueue() {
    removeSongFromQueue(song);
    notifyListeners();
  }

  // E1d fix: Execute menu action (moved from _SongBarState._buildContextMenu)
  void executeMenuAction(String action) {
    switch (action) {
      case 'like':
        toggleLike();
      case 'add_to_playlist':
        // Handled by caller
      case 'add_to_queue':
        addToQueue();
      case 'remove_from_queue':
        removeFromQueue();
      case 'offline':
        if (isDownloadedNotifier.value) {
          removeDownload();
        } else {
          triggerDownload();
        }
      case 'youtube':
      case 'youtube_links':
      case 'musicbrainz':
      case 'get_musicbrainz':
        // These are handled by caller with navigation
    }
    notifyListeners();
  }

  // E1a fix: Initialize like status from song data
  void initLikeStatus() {
    isLikedNotifier.value = isSongAlreadyLiked(song);
  }

  // E1b fix: Initialize download status from song data
  void initDownloadStatus() {
    isDownloadedNotifier.value = isSongAlreadyOffline(song);
  }
}
