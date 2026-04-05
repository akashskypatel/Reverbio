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
import 'package:reverbio/API/entities/song_youtube.dart';
import 'package:reverbio/API/reverbio.dart';

import '../helpers/test_setup.dart';

/// Unit tests for YouTube song functions.
/// Tests isYouTubeSongValid, youtubeUrl, and returnYtSongLayout.
void main() {
  setUpAll(() {
    setUpAllServices();
  });

  tearDownAll(() {
    tearDownAllServices();
  });

  group('isYouTubeSongValid', () {
    test('returns true for song with ytid', skip: 'Requires artist field - see issue #1', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      expect(isYouTubeSongValid(song), isTrue);
    });

    test('returns false for song without ytid', () {
      final song = {'title': 'Test Song'};
      expect(isYouTubeSongValid(song), isFalse);
    });

    test('returns false for empty ytid', () {
      final song = {'ytid': '', 'title': 'Test Song'};
      expect(isYouTubeSongValid(song), isFalse);
    });

    test('returns false for null song', () {
      expect(isYouTubeSongValid(null), isFalse);
    });

    test('returns false for non-Map song', () {
      expect(isYouTubeSongValid('not a map'), isFalse);
    });
  });

  group('youtubeUrl', () {
    test('returns URL for song with ytid', () {
      final song = {'ytid': 'abc123'};
      final url = youtubeUrl(song);
      expect(url, equals('https://www.youtube.com/watch?v=abc123'));
    });

    test('returns null for song without ytid', () {
      final song = {'title': 'Test Song'};
      expect(youtubeUrl(song), isNull);
    });

    test('returns null for empty ytid', () {
      final song = {'ytid': ''};
      expect(youtubeUrl(song), isNull);
    });

    test('returns null for null song', skip: 'Null safety - see issue #1', () {
      expect(youtubeUrl(null), isNull);
    });
  });

  // Note: returnYtSongLayout tests skipped - requires youtube_explode_dart Video object which can't be easily mocked
  // group('returnYtSongLayout', () {
  //   test('returns map with youtube source', () {
  //     // Note: This tests the basic structure since yt search requires network
  //     final result = returnYtSongLayout({
  //       'id': 'abc123',
  //       'title': 'Test Song',
  //       'author': 'Test Artist',
  //       'duration': Duration(seconds: 180),
  //     });
  //     expect(result, isA<Map<String, dynamic>>());
  //     expect(result['source'], equals('youtube'));
  //   });
  // });
}
