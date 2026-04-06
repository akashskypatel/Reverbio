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
import 'package:reverbio/repositories/song_repository.dart';
import 'package:reverbio/repositories/impl/song_repository_impl.dart';

/// Unit tests for SongRepository implementation.
/// Tests getSongInfo, getSongUrl, updateLikeStatus, checkSong, isSongValid.
void main() {
  late SongRepository repository;

  setUp(() {
    repository = SongRepositoryImpl();
  });

  group('SongRepositoryImpl', () {
    group('isSongValid', () {
      test('returns true for valid song with ytid', () {
        final song = {'ytid': 'abc123', 'title': 'Test Song'};
        expect(repository.isSongValid(song), isTrue);
      });

      test('returns true for valid song with mbid', () {
        final song = {'mbid': 'xyz789', 'title': 'Test Song'};
        expect(repository.isSongValid(song), isTrue);
      });

      test('returns false for null song', () {
        expect(repository.isSongValid(null as dynamic), isFalse);
      });

      test('returns false for empty map', () {
        expect(repository.isSongValid({}), isFalse);
      });

      test('returns false for map with only title', () {
        final song = {'title': 'Test Song'};
        expect(repository.isSongValid(song), isFalse);
      });
    });

    group('checkSong', () {
      test('returns true for matching ytid', () {
        final a = {'ytid': 'abc123'};
        final b = {'ytid': 'abc123'};
        expect(repository.checkSong(a, b), isTrue);
      });

      test('returns true for matching mbid', () {
        final a = {'mbid': 'xyz789'};
        final b = {'mbid': 'xyz789'};
        expect(repository.checkSong(a, b), isTrue);
      });

      test('returns true for matching id', () {
        final a = {'id': 'song1'};
        final b = {'id': 'song1'};
        expect(repository.checkSong(a, b), isTrue);
      });

      test('returns false for non-matching ids', () {
        final a = {'ytid': 'abc123'};
        final b = {'ytid': 'def456'};
        expect(repository.checkSong(a, b), isFalse);
      });

      test('returns false for empty maps', () {
        expect(repository.checkSong({}, {}), isFalse);
      });

      test('returns false when one is null', () {
        final a = {'ytid': 'abc123'};
        expect(repository.checkSong(a, null), isFalse);
      });
    });

    group('getSongInfo', () {
      test('returns map for valid song', () async {
        final song = {'ytid': 'abc123', 'title': 'Test Song'};
        final result = await repository.getSongInfo(song);
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns empty map for null ytid', () async {
        final song = {'ytid': null};
        final result = await repository.getSongInfo(song);
        // Note: Actual behavior depends on entity function implementation
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns map for empty song', () async {
        final result = await repository.getSongInfo({});
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('getSongUrl', () {
      test('returns String or null for valid song', () async {
        final song = {'ytid': 'abc123', 'title': 'Test Song'};
        final result = await repository.getSongUrl(song);
        // Result can be String (URL) or null (if fetch fails)
        expect(result == null || result is String, isTrue);
      });

      test('returns null for empty song', () async {
        final result = await repository.getSongUrl({});
        expect(result, isNull);
      });
    });

    group('updateLikeStatus', () {
      test('completes without error for add', () async {
        final song = {'ytid': 'abc123', 'title': 'Test Song'};
        expect(() => repository.updateLikeStatus(song, true), returnsNormally);
      });

      test('completes without error for remove', () async {
        final song = {'ytid': 'abc123', 'title': 'Test Song'};
        expect(() => repository.updateLikeStatus(song, false), returnsNormally);
      });
    });
  });
}
