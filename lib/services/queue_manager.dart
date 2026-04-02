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

import 'package:audio_service/audio_service.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/mediaitem.dart';

/// Phase 4.B.3 + Phase 7 E2: Queue management functions
/// Handles queue state, operations, and helper functions
/// Updated to use Map<String, dynamic> instead of SongBar widgets

// R26 fix: Typed Map instead of untyped Map
final Map<String, dynamic> activeQueue = {
  'id': '',
  'ytid': '',
  'title': 'No Songs in Queue',
  'image': '',
  'source': '',
  'list': [],
};

/// Create MediaItem from song Map.
MediaItem? mediaItemFromSong(Map<String, dynamic> song) {
  return mapToMediaItem(song);
}

/// Update media item queue in audio handler.
void updateMediaItemQueue(List<Map<String, dynamic>> songMaps) {
  audioHandler.queue.add(
    songMaps.map(mediaItemFromSong).whereType<MediaItem>().toList(),
  );
}

/// Add multiple songs to queue.
void addSongsToQueue(List<Map<String, dynamic>> songMaps) {
  for (final song in songMaps) {
    addSongToQueue(song);
  }
}

/// Add single song to queue.
void addSongToQueue(Map<String, dynamic> song) {
  if (!isSongInQueue(song)) {
    activeQueue['list'].add(song);
    audioHandler.queueSongMaps.add(song);
    final mediaItem = mediaItemFromSong(song);
    if (mediaItem != null) {
      audioHandler.queue.add(audioHandler.queue.value + [mediaItem]);
    }
  }
}

/// Remove song from queue.
bool removeSongFromQueue(Map<String, dynamic> song) {
  final val = activeQueue['list'].removeWhere((s) => checkSong(s, song));
  audioHandler.queueSongMaps.removeWhere((e) => checkSong(e, song));
  updateMediaItemQueue(audioHandler.queueSongMaps);
  return val.isNotEmpty;
}

/// Check if song is in queue.
bool isSongInQueue(Map<String, dynamic> song) {
  final inQueue = audioHandler.queueSongMaps.any((e) => checkSong(e, song));
  return inQueue;
}

/// Get queue index of song.
int queueIndexOf(Map<String, dynamic> song, {List<Map<String, dynamic>>? songMaps}) {
  if (songMaps != null) return songMaps.indexWhere((e) => checkSong(e, song));
  return audioHandler.queueSongMaps.indexWhere((e) => checkSong(e, song));
}

/// Get next song in queue.
Map<String, dynamic>? nextSong(Map<String, dynamic> song, {List<Map<String, dynamic>>? songMaps}) {
  final list = songMaps != null ? songMaps : audioHandler.queueSongMaps;
  final length = list.length;
  final index = list.indexWhere((e) => checkSong(e, song));
  if (index < 0 || index + 1 >= list.length) return null;
  if (length == 1) return song;
  if (index == (length - 1) &&
      repeatNotifier.value == AudioServiceRepeatMode.all)
    return list[0];
  return list[index + 1];
}

/// Get previous song in queue.
Map<String, dynamic>? previousSong(Map<String, dynamic> song, {List<Map<String, dynamic>>? songMaps}) {
  final list = songMaps != null ? songMaps : audioHandler.queueSongMaps;
  final length = list.length;
  final index = list.indexWhere((e) => checkSong(e, song));
  if (index < 0 || index - 1 < 0) return null;
  if (length == 1) return song;
  if (index == 0 && repeatNotifier.value == AudioServiceRepeatMode.all)
    return list[length - 1];
  return list[index - 1];
}

/// Set queue to playlist.
void setQueueToPlaylist(dynamic playlist, List<Map<String, dynamic>> songMaps) {
  clearSongQueue();
  activeQueue['id'] = playlist['id'];
  activeQueue['ytid'] = playlist['ytid'];
  activeQueue['title'] = playlist['title'];
  activeQueue['image'] = playlist['image'];
  activeQueue['source'] = playlist['source'];
  addSongsToQueue(songMaps);
}

/// Clear song queue.
void clearSongQueue() {
  activeQueue['id'] = '';
  activeQueue['ytid'] = '';
  activeQueue['title'] = 'No Songs in Queue';
  activeQueue['image'] = '';
  activeQueue['source'] = '';
  activeQueue['list'].clear();
  audioHandler.queueSongMaps.clear();
}
