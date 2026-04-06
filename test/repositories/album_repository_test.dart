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
import 'package:reverbio/repositories/album_repository.dart';
import 'package:reverbio/repositories/impl/album_repository_impl.dart';

/// Unit tests for AlbumRepository implementation.
/// Tests getAlbumInfo, getAlbumCoverArt, updateLikeStatus, queueAlbumInfoRequest.
void main() {
  late AlbumRepository repository;

  setUp(() {
    repository = AlbumRepositoryImpl();
  });

  group('AlbumRepositoryImpl', () {
    group('getAlbumInfo', () {
      test('returns map for valid album with mbid', () async {
        final album = {'mbid': 'abc123', 'title': 'Test Album'};
        final result = await repository.getAlbumInfo(album);
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns map for album with id', () async {
        final album = {'id': 'album1', 'title': 'Test Album'};
        final result = await repository.getAlbumInfo(album);
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns map for empty album', () async {
        final result = await repository.getAlbumInfo({});
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns map for null album', () async {
        final result = await repository.getAlbumInfo(null);
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('getAlbumCoverArt', () {
      test('returns map for valid album', () async {
        final album = {'mbid': 'abc123', 'title': 'Test Album'};
        final result = await repository.getAlbumCoverArt(album);
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns map for album without mbid', () async {
        final album = {'title': 'Test Album'};
        final result = await repository.getAlbumCoverArt(album);
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns map for empty album', () async {
        final result = await repository.getAlbumCoverArt({});
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('updateLikeStatus', () {
      test('completes without error for add', () async {
        final album = {'mbid': 'abc123', 'title': 'Test Album'};
        expect(() => repository.updateLikeStatus(album, true), returnsNormally);
      });

      test('completes without error for remove', () async {
        final album = {'mbid': 'abc123', 'title': 'Test Album'};
        expect(() => repository.updateLikeStatus(album, false), returnsNormally);
      });
    });

    group('queueAlbumInfoRequest', () {
      test('completes without error for valid album', () {
        final album = {'mbid': 'abc123', 'title': 'Test Album'};
        expect(() => repository.queueAlbumInfoRequest(album), returnsNormally);
      });

      test('completes without error for empty album', () {
        expect(() => repository.queueAlbumInfoRequest({}), returnsNormally);
      });

      test('completes without error for null album', () {
        expect(() => repository.queueAlbumInfoRequest(null), returnsNormally);
      });
    });
  });
}
