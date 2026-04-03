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

import 'package:reverbio/API/entities/playlist.dart' as playlist_entity;
import 'package:reverbio/API/entities/playlist_result.dart' show PlaylistOperationResult;
import 'package:reverbio/repositories/playlist_repository.dart';

/// Concrete implementation of [PlaylistRepository].
/// Delegates to existing entity functions in lib/API/entities/playlist.dart.
/// This is a thin wrapper that provides a testable seam.
class PlaylistRepositoryImpl implements PlaylistRepository {
  @override
  Future<List> getPlaylists({bool onlyLiked = false}) async {
    return playlist_entity.getPlaylists(onlyLiked: onlyLiked);
  }

  @override
  Future<Map?> getPlaylistInfo(Map playlist) async {
    return playlist_entity.getPlaylistInfo(playlist);
  }

  @override
  PlaylistOperationResult createCustomPlaylist(String name) {
    return playlist_entity.createCustomPlaylist(name);
  }

  @override
  Future<void> updatePlaylistList(String playlistId) async {
    await playlist_entity.updatePlaylistList(playlistId);
  }

  @override
  Future<void> updateLikeStatus(Map playlist, bool add) async {
    await playlist_entity.updatePlaylistLikeStatus(playlist, add);
  }
}
