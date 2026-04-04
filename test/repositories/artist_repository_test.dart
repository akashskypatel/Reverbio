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
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/repositories/artist_repository.dart';
import 'package:reverbio/repositories/impl/artist_repository_impl.dart';

/// Unit tests for ArtistRepository implementation.
/// Tests getArtistDetails, updateLikeStatus, searchArtistsDetails.
void main() {
  late ArtistRepository repository;

  setUp(() {
    repository = ArtistRepositoryImpl();
  });

  group('ArtistRepositoryImpl', () {
    group('getArtistDetails', () {
      test('returns map for valid artist with mbid', () async {
        final artist = {'mb': 'abc123', 'name': 'Test Artist'};
        final result = await repository.getArtistDetails(artist);
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns map for artist with id', () async {
        final artist = {'id': 'mb=abc123', 'name': 'Test Artist'};
        final result = await repository.getArtistDetails(artist);
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns map for empty artist', () async {
        final result = await repository.getArtistDetails({});
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns map for null artist', () async {
        final result = await repository.getArtistDetails(null);
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('updateLikeStatus', () {
      test('completes without error for add', () async {
        final artist = {'mb': 'abc123', 'name': 'Test Artist'};
        expect(() => repository.updateLikeStatus(artist, true), returnsNormally);
      });

      test('completes without error for remove', () async {
        final artist = {'mb': 'abc123', 'name': 'Test Artist'};
        expect(() => repository.updateLikeStatus(artist, false), returnsNormally);
      });
    });

    group('searchArtistsDetails', () {
      test('returns list for valid query', () async {
        final result = await repository.searchArtistsDetails(['Test Artist']);
        expect(result, isA<List<dynamic>>());
      });

      test('returns list for empty query', () async {
        final result = await repository.searchArtistsDetails(['']);
        expect(result, isA<List<dynamic>>());
      });

      test('returns list for multiple queries', () async {
        final result = await repository.searchArtistsDetails(['Artist1', 'Artist2']);
        expect(result, isA<List<dynamic>>());
      });
    });
  });
}
