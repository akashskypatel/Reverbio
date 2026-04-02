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
import 'package:reverbio/API/entities/song.dart';

/// Unit tests for pure song metadata functions.
/// Tests checkSong, isSongValid, songTitle, songArtist, and combineArtists.
void main() {
  group('checkSong', () {
    test('returns true for matching ytid', () {
      final a = {'ytid': 'abc123'};
      final b = {'ytid': 'abc123'};
      expect(checkSong(a, b), isTrue);
    });

    test('returns true for matching mbid', () {
      final a = {'mbid': 'xyz789'};
      final b = {'mbid': 'xyz789'};
      expect(checkSong(a, b), isTrue);
    });

    test('returns true for matching id', () {
      final a = {'id': 'song1'};
      final b = {'id': 'song1'};
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

    test('returns false when one map is null', () {
      final a = {'ytid': 'abc123'};
      expect(checkSong(a, null), isFalse);
    });
  });

  group('isSongValid', () {
    test('returns true for valid song with ytid', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      expect(isSongValid(song), isTrue);
    });

    test('returns true for valid song with mbid', () {
      final song = {'mbid': 'xyz789', 'title': 'Test Song'};
      expect(isSongValid(song), isTrue);
    });

    test('returns false for null song', () {
      expect(isSongValid(null), isFalse);
    });

    test('returns false for empty map', () {
      expect(isSongValid({}), isFalse);
    });

    test('returns false for map with only ytid null', () {
      final song = {'ytid': null};
      expect(isSongValid(song), isFalse);
    });

    test('returns false for map with only title', () {
      final song = {'title': 'Test Song'};
      expect(isSongValid(song), isFalse);
    });

    test('returns true for partial map with ytid', () {
      final song = {'ytid': 'abc123'};
      expect(isSongValid(song), isTrue);
    });
  });

  group('songTitle', () {
    test('returns title from map', () {
      final song = {'title': 'Test Song', 'artist': 'Artist'};
      expect(songTitle(song), equals('Test Song'));
    });

    test('returns null for missing title', () {
      final song = {'artist': 'Artist'};
      expect(songTitle(song), isNull);
    });

    test('returns null for null map', () {
      expect(songTitle(null), isNull);
    });

    test('returns empty string for empty title', () {
      final song = {'title': ''};
      expect(songTitle(song), equals(''));
    });
  });

  group('songArtist', () {
    test('returns artist from map', () {
      final song = {'title': 'Test Song', 'artist': 'Artist'};
      expect(songArtist(song), equals('Artist'));
    });

    test('returns null for missing artist', () {
      final song = {'title': 'Test Song'};
      expect(songArtist(song), isNull);
    });

    test('returns null for null map', () {
      expect(songArtist(null), isNull);
    });
  });

  group('combineArtists', () {
    test('returns single artist', () {
      final song = {'artist': 'Artist'};
      expect(combineArtists(song), equals('Artist'));
    });

    test('returns combined artists from list', () {
      final song = {'artists': ['Artist1', 'Artist2']};
      expect(combineArtists(song), equals('Artist1, Artist2'));
    });

    test('returns null for missing artist', () {
      final song = {'title': 'Test Song'};
      expect(combineArtists(song), isNull);
    });

    test('returns null for null map', () {
      expect(combineArtists(null), isNull);
    });

    test('returns empty string for empty artists list', () {
      final song = {'artists': []};
      expect(combineArtists(song), equals(''));
    });
  });
}
