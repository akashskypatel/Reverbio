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

import 'package:reverbio/API/entities/song.dart' as song_entity;
import 'package:reverbio/repositories/song_repository.dart';

/// Concrete implementation of [SongRepository].
/// Delegates to existing entity functions in lib/API/entities/song.dart.
/// This is a thin wrapper that provides a testable seam.
class SongRepositoryImpl implements SongRepository {
  @override
  Future<Map<String, dynamic>> getSongInfo(Map song) async {
    return song_entity.getSongInfo(song);
  }

  @override
  Future<dynamic> getSongUrl(Map song) async {
    return song_entity.getSongUrl(song);
  }

  @override
  Future<void> updateLikeStatus(Map song, bool add) async {
    await song_entity.updateSongLikeStatus(song, add);
  }

  @override
  bool checkSong(dynamic a, dynamic b) {
    return song_entity.checkSong(a, b);
  }

  @override
  bool isSongValid(Map song) {
    return song_entity.isSongValid(song);
  }
}
