/*
 * Smoke test to verify test infrastructure is working.
 * Tests HiveBoxNames constants.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/services/hive_service.dart';

void main() {
  group('HiveBoxNames constants', () {
    test('settings box name is correct', () {
      expect(HiveBoxNames.settings, 'settings');
    });

    test('user box name is correct', () {
      expect(HiveBoxNames.user, 'user');
    });

    test('userNoBackup box name is correct', () {
      expect(HiveBoxNames.userNoBackup, 'userNoBackup');
    });

    test('cache box name is correct', () {
      expect(HiveBoxNames.cache, 'cache');
    });
  });
}
