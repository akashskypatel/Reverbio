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
import 'package:reverbio/API/entities/song_offline.dart';

import '../helpers/test_setup.dart';

/// Unit tests for offline song quality verification.
/// Tests verifyOfflineSongQuality and _isValidAudioHeader.
void main() {
  setUpAll(() {
    setUpAllServices();
  });

  tearDownAll(() {
    tearDownAllServices();
  });

  group('verifyOfflineSongQuality', () {
    test('returns invalid for null song', () async {
      final result = await verifyOfflineSongQuality(null);
      expect(result.isValid, isFalse);
    });

    test('returns invalid for empty song', () async {
      final result = await verifyOfflineSongQuality({});
      expect(result.isValid, isFalse);
    });

    test('returns invalid for song without offlineAudioPath', () async {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      final result = await verifyOfflineSongQuality(song);
      expect(result.isValid, isFalse);
    });

    test('returns invalid for non-existent file', () async {
      final song = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'offlineAudioPath': '/nonexistent/path/file.mp3',
      };
      final result = await verifyOfflineSongQuality(song);
      expect(result.isValid, isFalse);
      expect(result.message, contains('not found'));
    });
  });

  group('OfflineSongQualityResult', () {
    test('invalid factory creates invalid result', () {
      final result = OfflineSongQualityResult.invalid('Test error');
      expect(result.isValid, isFalse);
      expect(result.message, equals('Test error'));
    });

    test('valid factory creates valid result', () {
      final result = OfflineSongQualityResult.valid(
        fileSize: 1024,
        bitrate: 320,
      );
      expect(result.isValid, isTrue);
      expect(result.fileSize, equals(1024));
      expect(result.bitrate, equals(320));
    });

    test('valid factory with defaults', () {
      final result = OfflineSongQualityResult.valid();
      expect(result.isValid, isTrue);
      expect(result.fileSize, equals(0));
      expect(result.bitrate, isNull);
    });
  });
}
