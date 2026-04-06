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
import 'package:reverbio/API/entities/song_state.dart';
import 'package:reverbio/main.dart';

/// H.3 fix: Extract cache functions from song.dart
/// Handles song caching and recently played tracking.

/// Get a song from the cache by matching song identity.
Map<String, dynamic>? getCachedSong(dynamic song) {
  try {
    dynamic cached = cachedSongsList.firstWhere(
      (e) => checkSong(song, e),
      orElse: () => <String, dynamic>{},
    );
    if (cached.isEmpty || !isSongValid(cached)) return null;
    cached = Map<String, dynamic>.from(cached);
    return cached;
  } catch (e, stackTrace) {
    logger.log('Error in getCachedSong:', e, stackTrace);
    return null;
  }
}

/// Add a song to the cache if it's valid.
void addSongToCache(Map<String, dynamic> song) {
  if (isSongValid(song)) {
    cachedSongsList.addOrUpdate(song, checkSong);
  }
}

/// Update the recently played list with a song.
Future<void> updateRecentlyPlayed(dynamic song) async {
  try {
    // R18 fix: Race condition - check isNotEmpty before accessing [0]
    if (userRecentlyPlayed.isNotEmpty &&
        checkSong(userRecentlyPlayed.first, song))
      return;
    // R1457 fix: Use batchUpdate to prevent multiple notifications
    userRecentlyPlayed.batchUpdate((list) {
      // Fix: Remove duplicates FIRST, then trim if over limit (old code order)
      list.removeWhere((s) => checkSong(s, song));
      if (list.length >= recentlyPlayedSongsLimit) {
        list.removeLast();
      }
      list.insert(0, song);
    });
  } catch (e, stackTrace) {
    logger.log('Error in updateRecentlyPlayed:', e, stackTrace);
    rethrow;
  }
}
