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
import 'package:reverbio/API/entities/song_metadata.dart';
import 'package:reverbio/main.dart';

/// Unit tests for song comparison functions.
/// Tests checkSong, checkTitleAndArtist, and getSongHashCode.
void main() {
  group('checkSong', () {
    group('with string IDs', () {
      test('returns true for matching ytid strings', () {
        expect(checkSong('abc123', 'abc123'), isTrue);
      });

      test('returns false for non-matching ytid strings', () {
        expect(checkSong('abc123', 'def456'), isFalse);
      });

      test('returns false for empty strings', () {
        expect(checkSong('', 'abc123'), isFalse);
      });

      test('returns false when one is empty', () {
        expect(checkSong('', 'abc123'), isFalse);
      });
    });

    group('with Map songs', () {
      test('returns true for matching ytid', () {
        final a = {'ytid': 'abc123', 'title': 'Song A'};
        final b = {'ytid': 'abc123', 'title': 'Song B'};
        expect(checkSong(a, b), isTrue);
      });

      test('returns true for matching mbid', () {
        final a = {'mbid': 'xyz789', 'title': 'Song A'};
        final b = {'mbid': 'xyz789', 'title': 'Song B'};
        expect(checkSong(a, b), isTrue);
      });

      test('returns true for matching id', () {
        final a = {'id': 'song1', 'title': 'Song A'};
        final b = {'id': 'song1', 'title': 'Song B'};
        expect(checkSong(a, b), isTrue);
      });

      test('returns false for non-matching ids', () {
        final a = {'ytid': 'abc123'};
        final b = {'ytid': 'def456'};
        expect(checkSong(a, b), isFalse);
      });

      test('returns false for empty maps', () {
        expect(checkSong({}, {}), isFalse);
      });

      test('returns false when one is null', () {
        final a = {'ytid': 'abc123'};
        expect(checkSong(a, null), isFalse);
      });

      test('returns false when one is empty map', () {
        final a = {'ytid': 'abc123'};
        expect(checkSong(a, {}), isFalse);
      });
    });

    group('with mixed types', () {
      test('returns true for string id matching Map ytid', () {
        final song = {'ytid': 'abc123', 'title': 'Test Song'};
        expect(checkSong('abc123', song), isTrue);
      });

      test('returns true for Map ytid matching string id', () {
        final song = {'ytid': 'abc123', 'title': 'Test Song'};
        expect(checkSong(song, 'abc123'), isTrue);
      });
    });

    group('fallback to title/artist', () {
      test('returns true for matching title and artist when no ids', () {
        final a = {'title': 'Test Song', 'artist': 'Test Artist'};
        final b = {'title': 'Test Song', 'artist': 'Test Artist'};
        expect(checkSong(a, b), isTrue);
      });

      test('returns false for different title when no ids', () {
        final a = {'title': 'Song A', 'artist': 'Artist A'};
        final b = {'title': 'Song B', 'artist': 'Artist A'};
        expect(checkSong(a, b), isFalse);
      });

      test('returns false for different artist when no ids', () {
        final a = {'title': 'Song A', 'artist': 'Artist A'};
        final b = {'title': 'Song A', 'artist': 'Artist B'};
        expect(checkSong(a, b), isFalse);
      });
    });
  });

  group('checkTitleAndArtist', () {
    test('returns true for exact match', () {
      final a = {'title': 'Test Song', 'artist': 'Test Artist'};
      final b = {'title': 'Test Song', 'artist': 'Test Artist'};
      expect(checkTitleAndArtist(a, b), isTrue);
    });

    test('returns false for different title', () {
      final a = {'title': 'Song A', 'artist': 'Artist'};
      final b = {'title': 'Song B', 'artist': 'Artist'};
      expect(checkTitleAndArtist(a, b), isFalse);
    });

    test('returns false for different artist', () {
      final a = {'title': 'Song', 'artist': 'Artist A'};
      final b = {'title': 'Song', 'artist': 'Artist B'};
      expect(checkTitleAndArtist(a, b), isFalse);
    });

    test('returns false for null song', () {
      final b = {'title': 'Song', 'artist': 'Artist'};
      expect(checkTitleAndArtist(null, b), isFalse);
    });

    test('returns false for non-Map song', () {
      final b = {'title': 'Song', 'artist': 'Artist'};
      expect(checkTitleAndArtist('not a map', b), isFalse);
    });

    test('returns false for empty maps', () {
      expect(checkTitleAndArtist({}, {}), isFalse);
    });
  });

  group('getSongHashCode', () {
    test('returns null for null song', () {
      expect(getSongHashCode(null), isNull);
    });

    test('returns null for empty map', () {
      expect(getSongHashCode({}), isNull);
    });

    test('returns null for song without title', () {
      final song = {'artist': 'Test Artist'};
      expect(getSongHashCode(song), isNull);
    });

    test('returns same hash for songs with same title and artist', () {
      final a = {'title': 'Test Song', 'artist': 'Test Artist'};
      final b = {'title': 'Test Song', 'artist': 'Test Artist'};
      final hashA = getSongHashCode(a);
      final hashB = getSongHashCode(b);
      expect(hashA, equals(hashB));
    });

    test('returns different hash for songs with different title', () {
      final a = {'title': 'Song A', 'artist': 'Artist'};
      final b = {'title': 'Song B', 'artist': 'Artist'};
      final hashA = getSongHashCode(a);
      final hashB = getSongHashCode(b);
      expect(hashA, isNot(equals(hashB)));
    });
  });
}
