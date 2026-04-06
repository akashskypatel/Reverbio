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

import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song_metadata.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/plugins_manager.dart';

/// H.2 fix: Extract like/unlike functions from song.dart
/// Small, well-bounded domain. Imports only song_state.dart and song_metadata.dart.

/// Update the like status of a song (add or remove from liked songs).
Future<bool> updateSongLikeStatus(dynamic song, bool add) async {
  try {
    // R1 fix: Check for null before dereferencing
    if (song == null) throw Exception('Song is null');
    final songId = parseEntityId(song);
    if (songId.isEmpty) throw Exception('ID is null or empty');
    song['id'] = songId;
    if (add) {
      userLikedSongsList.addOrUpdate(song, checkSong);
      song['song'] = songTitle(song);
      await PM.triggerHook(song, 'onEntityLiked');
    } else {
      userLikedSongsList.removeWhere((s) => checkSong(s, song));
    }
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return !add;
  }
}

/// Move a liked song from one position to another in the liked songs list.
void moveLikedSong(int oldIndex, int newIndex) {
  final _song = userLikedSongsList[oldIndex];
  // R13 fix: Adjust newIndex when moving down to account for removal shift
  if (oldIndex < newIndex) newIndex--;
  userLikedSongsList
    ..removeAt(oldIndex)
    ..insert(newIndex, _song);
}

/// Check if a song is already in the liked songs list.
bool isSongAlreadyLiked(songToCheck) =>
    songToCheck is Map &&
    userLikedSongsList.any((song) => checkSong(song, songToCheck));
