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

import 'package:reverbio/API/entities/album.dart' as album_entity;
import 'package:reverbio/repositories/album_repository.dart';

/// Concrete implementation of [AlbumRepository].
/// Delegates to existing entity functions in lib/API/entities/album.dart.
/// This is a thin wrapper that provides a testable seam.
class AlbumRepositoryImpl implements AlbumRepository {
  @override
  Future<Map<String, dynamic>> getAlbumInfo(dynamic album) async {
    return album_entity.getAlbumInfo(album);
  }

  @override
  Future<Map<String, dynamic>> getAlbumCoverArt(Map album) async {
    return album_entity.getAlbumCoverArt(album as Map<String, dynamic>);
  }

  @override
  Future<void> updateLikeStatus(Map album, bool add) async {
    await album_entity.updateAlbumLikeStatus(album, add);
  }

  @override
  void queueAlbumInfoRequest(dynamic album) {
    album_entity.queueAlbumInfoRequest(album);
  }
}
