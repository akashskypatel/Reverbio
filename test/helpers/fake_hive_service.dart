/*
 * Test helpers for HiveService unit tests.
 * Uses hive_test package to provide in-memory Hive boxes.
 */

import 'package:hive_test/hive_test.dart';

/// Sets up in-memory Hive for tests.
/// Call this in setUp() before tests that need Hive.
Future<void> setUpHive() async {
  await setUpTestHive();
}

/// Tears down in-memory Hive after tests.
/// Call this in tearDown() after tests that need Hive.
Future<void> tearDownHive() async {
  await tearDownTestHive();
}
