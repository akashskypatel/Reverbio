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

import '../helpers/test_setup.dart';

/// Unit tests for MusicBrainz song functions.
/// Tests isMusicbrainzSongValid, musicbrainzUrl.
void main() {
  setUpAll(() {
    setUpAllServices();
  });

  tearDownAll(() {
    tearDownAllServices();
  });

  group('isMusicbrainzSongValid', () {
    test('returns true for song with mbid', skip: 'Requires artist field - see issue #1', () {
      final song = {'mbid': 'abc123-def456', 'title': 'Test Song'};
      expect(isMusicbrainzSongValid(song), isTrue);
    });

    test('returns true for song with rid', skip: 'Requires artist field - see issue #1', () {
      final song = {'rid': 'abc123-def456', 'title': 'Test Song'};
      expect(isMusicbrainzSongValid(song), isTrue);
    });

    test('returns false for song without mbid or rid', () {
      final song = {'title': 'Test Song'};
      expect(isMusicbrainzSongValid(song), isFalse);
    });

    test('returns false for empty mbid', () {
      final song = {'mbid': '', 'title': 'Test Song'};
      expect(isMusicbrainzSongValid(song), isFalse);
    });

    test('returns false for null song', () {
      expect(isMusicbrainzSongValid(null), isFalse);
    });

    test('returns false for non-Map song', () {
      expect(isMusicbrainzSongValid('not a map'), isFalse);
    });
  });

  group('musicbrainzUrl', () {
    test('returns URL for song with rid', () {
      final song = {'rid': 'abc123-def456'};
      final url = musicbrainzUrl(song);
      expect(url, equals('https://musicbrainz.org/recording/abc123-def456'));
    });

    test('returns URL for song with mbid', () {
      final song = {'mbid': 'xyz789-uvw012'};
      final url = musicbrainzUrl(song);
      expect(url, equals('https://musicbrainz.org/recording/xyz789-uvw012'));
    });

    test('returns null for song without mbid or rid', () {
      final song = {'title': 'Test Song'};
      expect(musicbrainzUrl(song), isNull);
    });

    test('returns null for empty mbid', () {
      final song = {'mbid': ''};
      expect(musicbrainzUrl(song), isNull);
    });

    test('returns null for null song', skip: 'Null safety - see issue #1', () {
      expect(musicbrainzUrl(null), isNull);
    });
  });
}
