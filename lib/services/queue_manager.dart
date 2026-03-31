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
import 'package:reverbio/main.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/widgets/song_bar.dart';

/// Phase 4.B.3: Queue management functions
/// Handles queue state, operations, and helper functions

// R26 fix: Typed Map instead of untyped Map
final Map<String, dynamic> activeQueue = {
  'id': '',
  'ytid': '',
  'title': 'No Songs in Queue',
  'image': '',
  'source': '',
  'list': [],
};

/// Update media item queue in audio handler
void updateMediaItemQueue(List<SongBar> songBars) {
  audioHandler.queue.add(songBars.map((e) => e.mediaItem).whereType<MediaItem>().toList());
}

/// Add multiple songs to queue
void addSongsToQueue(List<SongBar> songBars) {
  for (final songBar in songBars) {
    addSongToQueue(songBar);
  }
}

/// Add single song to queue
void addSongToQueue(SongBar songBar) {
  if (!isSongInQueue(songBar)) {
    activeQueue['list'].add(songBar.song);
    audioHandler.queueSongBars.add(songBar);
    if (songBar.mediaItem != null) {
      audioHandler.queue.add(audioHandler.queue.value + [songBar.mediaItem!]);
    }
  }
}

/// Remove song from queue
bool removeSongFromQueue(SongBar songBar) {
  final val = activeQueue['list'].remove(songBar.song);
  audioHandler.queueSongBars.removeWhere((e) => e.equals(songBar));
  updateMediaItemQueue(audioHandler.queueSongBars);
  return val;
}

/// Check if song is in queue
bool isSongInQueue(SongBar songBar) {
  final inQueue =
      audioHandler.queueSongBars.where((e) {
        return e.equals(songBar);
      }).isNotEmpty;
  return inQueue;
}

/// Get queue index of song
int queueIndexOf(SongBar songBar, {List<SongBar>? songBars}) {
  if (songBars != null) return songBars.indexWhere((e) => e.equals(songBar));
  return audioHandler.queueSongBars.indexWhere((e) => e.equals(songBar));
}

/// Get next song in queue
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

/// Get previous song in queue
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

/// Set queue to playlist
void setQueueToPlaylist(dynamic playlist, List<SongBar> songBars) {
  clearSongQueue();
  activeQueue['id'] = playlist['id'];
  activeQueue['ytid'] = playlist['ytid'];
  activeQueue['title'] = playlist['title'];
  activeQueue['image'] = playlist['image'];
  activeQueue['source'] = playlist['source'];
  addSongsToQueue(songBars);
}

/// Clear song queue
void clearSongQueue() {
  activeQueue['id'] = '';
  activeQueue['ytid'] = '';
  activeQueue['title'] = 'No Songs in Queue';
  activeQueue['image'] = '';
  activeQueue['source'] = '';
  activeQueue['list'].clear();
  audioHandler.queueSongBars.clear();
}
