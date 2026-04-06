/*
 * Unit tests for formatter.dart - formatDuration function.
 * Tests time formatting edge cases.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/utilities/formatter.dart';

void main() {
  group('formatDuration', () {
    test('formats zero as 00:00', () {
      expect(formatDuration(0), equals('00:00'));
    });

    test('formats seconds under 1 minute', () {
      expect(formatDuration(59), equals('00:59'));
    });

    test('formats exact minute', () {
      expect(formatDuration(60), equals('01:00'));
    });

    test('formats minutes and seconds', () {
      expect(formatDuration(125), equals('02:05'));
    });

    test('formats 9 minutes 59 seconds', () {
      expect(formatDuration(599), equals('09:59'));
    });

    test('formats 10 minutes', () {
      expect(formatDuration(600), equals('10:00'));
    });

    test('formats exact hour', () {
      expect(formatDuration(3600), equals('01:00:00'));
    });

    test('formats hour with minutes and seconds', () {
      expect(formatDuration(3661), equals('01:01:01'));
    });

    test('formats 2 hours 2 minutes 2 seconds', () {
      expect(formatDuration(7322), equals('02:02:02'));
    });

    test('formats 10 hours', () {
      expect(formatDuration(36000), equals('10:00:00'));
    });
  });
}
