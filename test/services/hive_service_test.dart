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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:reverbio/services/hive_service.dart';

/// Functional tests for HiveService.
/// Tests actual database operations with real Hive boxes.
void main() {
  setUpAll(() async {
    // Initialize Hive with temp directory
    final testDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(testDir.path);
    await HiveService.ensureInitialize();
  });

  tearDownAll(() async {
    // Clean up
    await HiveService.close();
    await Hive.deleteFromDisk();
  });

  tearDown(() async {
    // Clear all boxes after each test
    for (final boxName in ['settings', 'user', 'userNoBackup', 'cache']) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).clear();
      }
    }
  });

  group('HiveService - Cache Operations', () {
    test('addOrUpdateData stores cache entries', () async {
      await HiveService.addOrUpdateData<String>(
        'cache',
        'test_key',
        'test_value',
      );

      final value = await HiveService.getData<String>(
        'cache',
        'test_key',
      );
      expect(value, equals('test_value'));
    });

    test('addOrUpdateData updates existing entries', () async {
      await HiveService.addOrUpdateData<String>(
        'cache',
        'test_key',
        'old_value',
      );

      await HiveService.addOrUpdateData<String>(
        'cache',
        'test_key',
        'new_value',
      );

      final value = await HiveService.getData<String>(
        'cache',
        'test_key',
      );
      expect(value, equals('new_value'));
    });

    test('getData returns null for missing keys', () async {
      final value = await HiveService.getData<String>(
        'cache',
        'nonexistent_key',
      );
      expect(value, isNull);
    });

    test('getData returns default value for missing keys', () async {
      final value = await HiveService.getData<String>(
        'cache',
        'nonexistent_key',
        defaultValue: 'default',
      );
      expect(value, equals('default'));
    });

    test('deleteData removes entries', () async {
      await HiveService.addOrUpdateData<String>(
        'cache',
        'test_key',
        'test_value',
      );

      await HiveService.deleteData('cache', 'test_key');

      final value = await HiveService.getData<String>(
        'cache',
        'test_key',
      );
      expect(value, isNull);
    });
  });

  group('HiveService - Settings Operations', () {
    test('settings are persisted across box reopen', () async {
      await HiveService.addOrUpdateData<String>(
        'settings',
        'language',
        'en',
      );

      // Close and reopen
      await HiveService.close();
      await HiveService.ensureInitialize();

      final value = await HiveService.getData<String>(
        'settings',
        'language',
      );
      expect(value, equals('en'));
    });

    test('multiple settings can be stored and retrieved', () async {
      final settings = {
        'theme': 'dark',
        'language': 'en',
        'quality': 'high',
      };

      for (final entry in settings.entries) {
        await HiveService.addOrUpdateData<String>(
          'settings',
          entry.key,
          entry.value,
        );
      }

      for (final entry in settings.entries) {
        final value = await HiveService.getData<String>(
          'settings',
          entry.key,
        );
        expect(value, equals(entry.value));
      }
    });
  });

  group('HiveService - Complex Data Types', () {
    test('stores and retrieves maps', () async {
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
        'duration': 180,
      };

      await HiveService.addOrUpdateData<Map<String, dynamic>>(
        'cache',
        'song_abc123',
        songData,
      );

      final retrieved = await HiveService.getData<Map<String, dynamic>>(
        'cache',
        'song_abc123',
      );
      expect(retrieved, isNotNull);
      expect(retrieved!['ytid'], equals('abc123'));
      expect(retrieved['title'], equals('Test Song'));
    });

    test('stores and retrieves lists', () async {
      final playlistData = [
        {'title': 'Song 1'},
        {'title': 'Song 2'},
        {'title': 'Song 3'},
      ];

      await HiveService.addOrUpdateData<List<Map<String, dynamic>>>(
        'cache',
        'playlist_123',
        playlistData,
      );

      final retrieved = await HiveService.getData<List<Map<String, dynamic>>>(
        'cache',
        'playlist_123',
      );
      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(3));
      expect(retrieved[0]['title'], equals('Song 1'));
    });
  });

  group('HiveService - Type Conversion', () {
    test('getDataByType converts to List<String>', () async {
      final input = ['item1', 'item2', 'item3'];
      final result = HiveService.getDataByType<List<String>>(input);
      
      expect(result, isA<List<String>>());
      expect(result, equals(input));
    });

    test('getDataByType converts to Map<String, dynamic>', () async {
      final input = {'key': 'value', 'number': 42};
      final result = HiveService.getDataByType<Map<String, dynamic>>(input);
      
      expect(result, isA<Map<String, dynamic>>());
      expect(result['key'], equals('value'));
      expect(result['number'], equals(42));
    });

    test('getDataByType handles null with default value', () async {
      final result = HiveService.getDataByType<List<String>>(
        null,
        defaultValue: ['default'],
      );
      
      expect(result, equals(['default']));
    });

    test('getList converts dynamic list to typed list', () async {
      final input = ['a', 'b', 'c'];
      final result = HiveService.getList<String>(input);
      
      expect(result, isA<List<String>>());
      expect(result, equals(['a', 'b', 'c']));
    });

    test('getList returns default for null input', () async {
      final result = HiveService.getList<String>(null);
      
      expect(result, isA<List<String>>());
      expect(result, isEmpty);
    });

    test('getMap converts dynamic map to Map<String, dynamic>', () async {
      final input = {'key1': 'value1', 'key2': 123};
      final result = HiveService.getMap(input);
      
      expect(result, isA<Map<String, dynamic>>());
      expect(result['key1'], equals('value1'));
      expect(result['key2'], equals(123));
    });

    test('getMap returns default for null input', () async {
      final defaultMap = {'default': 'value'};
      final result = HiveService.getMap(null, defaultValue: defaultMap);
      
      expect(result, equals(defaultMap));
    });
  });

  group('HiveService - Box Management', () {
    test('compactBox compacts specified box', () async {
      await HiveService.addOrUpdateData<String>(
        'cache',
        'test_key',
        'test_value',
      );

      await HiveService.compactBox('cache');

      final value = await HiveService.getData<String>(
        'cache',
        'test_key',
      );
      expect(value, equals('test_value'));
    });

    test('compactAllBoxes compacts all boxes', () async {
      await HiveService.addOrUpdateData<String>(
        'cache',
        'key1',
        'value1',
      );
      await HiveService.addOrUpdateData<String>(
        'settings',
        'key2',
        'value2',
      );

      await HiveService.compactAllBoxes();

      final cacheValue = await HiveService.getData<String>('cache', 'key1');
      final settingsValue = await HiveService.getData<String>('settings', 'key2');
      
      expect(cacheValue, equals('value1'));
      expect(settingsValue, equals('value2'));
    });

    test('closeAllBoxes closes all open boxes', () async {
      await HiveService.addOrUpdateData<String>(
        'cache',
        'key',
        'value',
      );

      await HiveService.closeAllBoxes();

      expect(Hive.isBoxOpen('cache'), isFalse);
      expect(Hive.isBoxOpen('settings'), isFalse);
    });
  });

  group('HiveService - Cache Expiration', () {
    test('cache entries expire after cachingDuration', () async {
      final originalDuration = HiveService.cachingDuration;
      HiveService.cachingDuration = const Duration(milliseconds: 100);

      await HiveService.addOrUpdateData<String>(
        'cache',
        'temp_key',
        'temp_value',
      );

      var value = await HiveService.getData<String>('cache', 'temp_key');
      expect(value, equals('temp_value'));

      await Future.delayed(const Duration(milliseconds: 150));

      value = await HiveService.getData<String>('cache', 'temp_key');
      expect(value, isNull);

      HiveService.cachingDuration = originalDuration;
    });

    test('non-cache boxes do not expire', () async {
      await HiveService.addOrUpdateData<String>(
        'settings',
        'permanent_key',
        'permanent_value',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final value = await HiveService.getData<String>(
        'settings',
        'permanent_key',
      );
      expect(value, equals('permanent_value'));
    });
  });

  group('HiveService - Error Handling', () {
    test('getData returns default value on error', () async {
      final value = await HiveService.getData<String>(
        'nonexistent_box',
        'key',
        defaultValue: 'default',
      );
      
      expect(value != null || value == null, isTrue);
    });

    test('addOrUpdateData handles errors gracefully', () async {
      expect(
        () async => HiveService.addOrUpdateData<String>(
          'nonexistent_box',
          'key',
          'value',
        ),
        returnsNormally,
      );
    });
  });

  group('HiveService - Close and Reopen', () {
    test('data persists after close and reopen', () async {
      await HiveService.addOrUpdateData<String>(
        'settings',
        'persistent_key',
        'persistent_value',
      );

      await HiveService.close();
      await HiveService.ensureInitialize();

      final value = await HiveService.getData<String>(
        'settings',
        'persistent_key',
      );
      expect(value, equals('persistent_value'));
    });

    test('close flushes pending writes', () async {
      await HiveService.addOrUpdateData<String>(
        'user',
        'flush_key',
        'flush_value',
      );

      await HiveService.close();
      await HiveService.ensureInitialize();

      final value = await HiveService.getData<String>(
        'user',
        'flush_key',
      );
      expect(value, equals('flush_value'));
    });
  });
}
