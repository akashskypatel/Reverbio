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
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song_cache.dart';
import 'package:reverbio/API/entities/song_state.dart';
import 'package:reverbio/main.dart';

/// Unit tests for song cache functions.
/// Tests getCachedSong, addSongToCache, updateRecentlyPlayed.
void main() {
  setUp(() {
    // Clear cache and recently played before each test
    cachedSongsList.clear();
    userRecentlyPlayed.clear();
  });

  tearDown(() {
    // Clean up after each test
    cachedSongsList.clear();
    userRecentlyPlayed.clear();
  });

  group('getCachedSong', () {
    test('returns null for empty cache', () {
      final result = getCachedSong({'ytid': 'abc123'});
      expect(result, isNull);
    });

    test('returns null when song not in cache', () {
      cachedSongsList.add({'ytid': 'different_id', 'title': 'Other Song'});
      final result = getCachedSong({'ytid': 'abc123'});
      expect(result, isNull);
    });

    test('returns cached song when found by ytid', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      cachedSongsList.add(song);
      final result = getCachedSong({'ytid': 'abc123'});
      expect(result, isNotNull);
      expect(result!['title'], equals('Test Song'));
    });

    test('returns cached song when found by mbid', () {
      final song = {'mbid': 'xyz789', 'title': 'Test Song'};
      cachedSongsList.add(song);
      final result = getCachedSong({'mbid': 'xyz789'});
      expect(result, isNotNull);
      expect(result!['title'], equals('Test Song'));
    });

    test('returns copy of cached song (not same reference)', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      cachedSongsList.add(song);
      final result = getCachedSong({'ytid': 'abc123'});
      expect(result, isNotNull);
      expect(identical(result, song), isFalse);
    });
  });

  group('addSongToCache', () {
    test('adds valid song to cache', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      addSongToCache(song);
      expect(cachedSongsList.length, equals(1));
      expect(cachedSongsList.first['title'], equals('Test Song'));
    });

    test('does not add empty song to cache', () {
      addSongToCache({});
      expect(cachedSongsList.length, equals(0));
    });

    test('does not add null song to cache', () {
      addSongToCache(null as dynamic);
      expect(cachedSongsList.length, equals(0));
    });

    test('does not add duplicate song to cache', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      addSongToCache(song);
      addSongToCache(song);
      expect(cachedSongsList.length, equals(1));
    });

    test('updates existing song in cache', () {
      final song1 = {'ytid': 'abc123', 'title': 'Old Title'};
      final song2 = {'ytid': 'abc123', 'title': 'New Title'};
      addSongToCache(song1);
      addSongToCache(song2);
      expect(cachedSongsList.length, equals(1));
      expect(cachedSongsList.first['title'], equals('New Title'));
    });
  });

  group('updateRecentlyPlayed', () {
    test('adds song to empty recently played list', () async {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      await updateRecentlyPlayed(song);
      expect(userRecentlyPlayed.length, equals(1));
      expect(userRecentlyPlayed.first['title'], equals('Test Song'));
    });

    test('adds song to beginning of list', () async {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      final song2 = {'ytid': 'def456', 'title': 'Song 2'};
      await updateRecentlyPlayed(song1);
      await updateRecentlyPlayed(song2);
      expect(userRecentlyPlayed.length, equals(2));
      expect(userRecentlyPlayed.first['title'], equals('Song 2'));
    });

    test('moves existing song to beginning', () async {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      final song2 = {'ytid': 'def456', 'title': 'Song 2'};
      await updateRecentlyPlayed(song1);
      await updateRecentlyPlayed(song2);
      await updateRecentlyPlayed(song1);
      expect(userRecentlyPlayed.length, equals(2));
      expect(userRecentlyPlayed.first['title'], equals('Song 1'));
    });

    test('removes oldest song when limit reached', () async {
      // Save and modify limit for this test
      final originalLimit = recentlyPlayedSongsLimit;
      // Note: recentlyPlayedSongsLimit is a const, so we test with default behavior
      // Add more songs than the default limit (100) to verify trimming works
      for (var i = 0; i < 102; i++) {
        await updateRecentlyPlayed({'ytid': 'song$i', 'title': 'Song $i'});
      }
      expect(userRecentlyPlayed.length, lessThanOrEqualTo(recentlyPlayedSongsLimit));
      expect(userRecentlyPlayed.first['title'], equals('Song 101'));
    });
  });
}
