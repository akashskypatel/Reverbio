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

/// Abstract repository interface for Playlist operations.
/// Provides a testable seam between business logic and storage/network layers.
abstract class PlaylistRepository {
  /// Get all playlists, optionally filtered to liked only.
  Future<List<Map<String, dynamic>>> getPlaylists({bool onlyLiked = false});

  /// Get info/metadata for a specific playlist.
  Future<Map<String, dynamic>> getPlaylistInfo(Map playlist);

  /// Create a new custom playlist with the given name.
  Future<Map<String, dynamic>> createCustomPlaylist(String name);

  /// Update the playlist list (refresh from storage/network).
  Future<void> updatePlaylistList(String playlistId);

  /// Update the like status of a playlist.
  Future<void> updateLikeStatus(Map playlist, bool add);
}
