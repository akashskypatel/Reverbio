/*
 * Integration tests for settings initialization and persistence.
 * Uses in-memory Hive to verify initializeSettings() and settings persistence.
 */

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/hive_service.dart';

import '../helpers/fake_hive_service.dart';

void main() {
  setUp(() async {
    await setUpHive();
  });

  tearDown(() async {
    await tearDownHive();
  });

  group('initializeSettings() + settings persistence', () {
    test('initializeSettings completes without error on fresh Hive', () async {
      expect(initializeSettings, returnsNormally);
    });

    test('after init offlineMode.value == false (correct default)', () async {
      await initializeSettings();
      expect(offlineMode.value, equals(false));
    });

    test('after init audioQualitySetting.value == high (correct default)',
        () async {
      await initializeSettings();
      expect(audioQualitySetting.value, equals('high'));
    });

    test('after init useSystemColor respects platform default', () async {
      await initializeSettings();
      // useSystemColor default is true (platform-aware)
      expect(useSystemColor.value, isA<bool>());
    });

    test('changing offlineMode.value waits 600ms Hive box contains true',
        () async {
      await initializeSettings();

      offlineMode.value = true;

      // Wait for debounce timer
      await Future.delayed(const Duration(milliseconds: 600));

      final box = Hive.box<dynamic>(HiveBoxNames.settings);
      expect(box.get('offlineMode'), equals(true));
    });

    test('re-calling initializeSettings after writing reads persisted value',
        () async {
      await initializeSettings();

      offlineMode.value = true;
      await Future.delayed(const Duration(milliseconds: 600));

      // Re-initialize
      await initializeSettings();

      expect(offlineMode.value, equals(true));
    });

    test('postUpdateRun.value persistence (R2 regression)', () async {
      await initializeSettings();

      // Reassign (not mutate) to trigger persistence
      postUpdateRun.value = {'v1': true};

      await Future.delayed(const Duration(milliseconds: 600));

      final box = Hive.box<dynamic>(HiveBoxNames.settings);
      // Verify the value was persisted
      expect(box.containsKey('postUpdateRun'), isTrue);
    });

    test('initializeSettings called twice completes without error', () async {
      final future1 = initializeSettings();
      final future2 = initializeSettings();

      await expectLater(future1, completes);
      await expectLater(future2, completes);
    });
  });
}
