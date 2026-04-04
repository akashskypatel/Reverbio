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
import 'package:reverbio/API/entities/song_likes.dart';
import 'package:reverbio/main.dart';

/// Unit tests for song like functions.
/// Tests updateSongLikeStatus, moveLikedSong, isSongAlreadyLiked.
void main() {
  setUp(() {
    userLikedSongsList.clear();
  });

  tearDown(() {
    userLikedSongsList.clear();
  });

  group('isSongAlreadyLiked', () {
    test('returns false for empty liked list', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      expect(isSongAlreadyLiked(song), isFalse);
    });

    test('returns false when song not in liked list', () {
      userLikedSongsList.add({'ytid': 'different_id', 'title': 'Other Song'});
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      expect(isSongAlreadyLiked(song), isFalse);
    });

    test('returns true when song is in liked list', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      userLikedSongsList.add(song);
      expect(isSongAlreadyLiked(song), isTrue);
    });

    test('returns false for null song', () {
      expect(isSongAlreadyLiked(null), isFalse);
    });

    test('returns false for non-Map song', () {
      expect(isSongAlreadyLiked('abc123'), isFalse);
    });
  });

  group('updateSongLikeStatus', () {
    test('adds song to liked list when add is true', () async {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      final result = await updateSongLikeStatus(song, true);
      expect(result, isTrue);
      expect(userLikedSongsList.length, equals(1));
      expect(isSongAlreadyLiked(song), isTrue);
    });

    test('removes song from liked list when add is false', () async {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      userLikedSongsList.add(song);
      expect(isSongAlreadyLiked(song), isTrue);
      final result = await updateSongLikeStatus(song, false);
      expect(result, isFalse);
      expect(userLikedSongsList.length, equals(0));
      expect(isSongAlreadyLiked(song), isFalse);
    });

    test('returns true when adding song', () async {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      final result = await updateSongLikeStatus(song, true);
      expect(result, isTrue);
    });

    test('returns false when removing song', () async {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      userLikedSongsList.add(song);
      final result = await updateSongLikeStatus(song, false);
      expect(result, isFalse);
    });

    test('handles null song gracefully', () async {
      final result = await updateSongLikeStatus(null, true);
      // Should return !add (false) due to exception handling
      expect(result, isFalse);
    });
  });

  group('moveLikedSong', () {
    test('moves song from old index to new index', () {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      final song2 = {'ytid': 'def456', 'title': 'Song 2'};
      final song3 = {'ytid': 'ghi789', 'title': 'Song 3'};
      userLikedSongsList.addAll([song1, song2, song3]);

      moveLikedSong(0, 2); // Move song1 from index 0 to index 2
      expect(userLikedSongsList.length, equals(3));
      expect(userLikedSongsList[0]['title'], equals('Song 2'));
      expect(userLikedSongsList[1]['title'], equals('Song 3'));
      expect(userLikedSongsList[2]['title'], equals('Song 1'));
    });

    test('moves song from new index to old index', () {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      final song2 = {'ytid': 'def456', 'title': 'Song 2'};
      final song3 = {'ytid': 'ghi789', 'title': 'Song 3'};
      userLikedSongsList.addAll([song1, song2, song3]);

      moveLikedSong(2, 0); // Move song3 from index 2 to index 0
      expect(userLikedSongsList.length, equals(3));
      expect(userLikedSongsList[0]['title'], equals('Song 3'));
      expect(userLikedSongsList[1]['title'], equals('Song 1'));
      expect(userLikedSongsList[2]['title'], equals('Song 2'));
    });
  });
}
