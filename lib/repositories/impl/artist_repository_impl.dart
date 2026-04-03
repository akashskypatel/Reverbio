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

import 'package:reverbio/API/entities/artist.dart' as artist_entity;
import 'package:reverbio/repositories/artist_repository.dart';

/// Concrete implementation of [ArtistRepository].
/// Delegates to existing entity functions in lib/API/entities/artist.dart.
/// This is a thin wrapper that provides a testable seam.
class ArtistRepositoryImpl implements ArtistRepository {
  @override
  Future<Map<String, dynamic>> getArtistDetails(dynamic artist) async {
    return artist_entity.getArtistDetails(artist);
  }

  @override
  Future<void> updateLikeStatus(Map artist, bool add) async {
    await artist_entity.updateArtistLikeStatus(artist, add);
  }

  @override
  Future<List<dynamic>> searchArtistsDetails(List<String> query) async {
    return artist_entity.searchArtistsDetails(query);
  }
}
