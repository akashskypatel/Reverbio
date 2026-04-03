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

/// Abstract repository interface for Song operations.
/// Provides a testable seam between business logic and storage/network layers.
abstract class SongRepository {
  /// Get song info/metadata for a song.
  Future<Map<String, dynamic>> getSongInfo(Map song);

  /// Get the streaming URL for a song.
  Future<dynamic> getSongUrl(Map song);

  /// Update the like status of a song.
  Future<void> updateLikeStatus(Map song, bool add);

  /// Check if two song references point to the same song.
  bool checkSong(dynamic a, dynamic b);

  /// Validate that a song map has required fields.
  bool isSongValid(Map song);
}
