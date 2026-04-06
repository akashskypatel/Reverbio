/*
 * Unit tests for HiveService.
 * Tests type conversion and pure functions.
 * Note: Full Hive I/O tests require platform-specific setup.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/services/hive_service.dart';

void main() {
  group('HiveService.getDataByType<T> — pure static method', () {
    // These tests call the static method directly with no Hive I/O.
    // No setUp needed.

    group('Passthrough types (no conversion)', () {
      test('String passes through unchanged', () {
        expect(HiveService.getDataByType<String>('hello'), equals('hello'));
      });

      test('bool passes through unchanged', () {
        expect(HiveService.getDataByType<bool>(true), equals(true));
      });

      test('int passes through unchanged', () {
        expect(HiveService.getDataByType<int>(42), equals(42));
      });

      test('double passes through unchanged', () {
        expect(HiveService.getDataByType<double>(3.14), equals(3.14));
      });
    });

    group('List types', () {
      test('List<String> passes through', () {
        expect(
          HiveService.getDataByType<List<String>>(['a', 'b']),
          equals(['a', 'b']),
        );
      });

      test('List<String> with null returns defaultValue', () {
        expect(
          HiveService.getDataByType<List<String>>(null, defaultValue: ['x']),
          equals(['x']),
        );
      });
    });

    group('Map types', () {
      test('Map<String,dynamic> passes through', () {
        expect(
          HiveService.getDataByType<Map<String, dynamic>>({'k': 'v'}),
          equals({'k': 'v'}),
        );
      });

      test('Map<String,dynamic> with null returns defaultValue', () {
        expect(
          HiveService.getDataByType<Map<String, dynamic>>(
            null,
            defaultValue: {'d': 1},
          ),
          equals({'d': 1}),
        );
      });

      test('Map<String,dynamic> with null and no defaultValue returns empty', () {
        expect(
          HiveService.getDataByType<Map<String, dynamic>>(null),
          equals({}),
        );
      });

      test('Raw Map<dynamic,dynamic> input is converted to Map<String,dynamic>', () {
        final rawMap = <dynamic, dynamic>{'key': 'value', 'count': 42};
        // This must NOT throw a CastError
        final result = HiveService.getDataByType<Map<String, dynamic>>(rawMap);
        expect(result, isA<Map<String, dynamic>>());
        expect(result['key'], equals('value'));
        expect(result['count'], equals(42));
      });
    });

    group('Nullable Map — regression test', () {
      test('getDataByType<Map<String,dynamic>?> returns Map without CastError', () {
        final result = HiveService.getDataByType<Map<String, dynamic>?>(
          {'k': 'v'},
        );
        expect(result, isNotNull);
        expect(result!['k'], equals('v'));
      });

      test('Hive-style _Map<dynamic,dynamic> converts correctly', () {
        final rawDynamicMap = <dynamic, dynamic>{'key': 'value'};
        final result = HiveService.getDataByType<Map<String, dynamic>?>(
          rawDynamicMap,
        );
        expect(result, isNotNull);
        expect(result!['key'], equals('value'));
      });

      test('getDataByType<Map<String,dynamic>?>(null) returns null', () {
        expect(
          HiveService.getDataByType<Map<String, dynamic>?>(null),
          isNull,
        );
      });
    });

    group('List of Maps', () {
      test('List<Map<String,dynamic>> converts each element', () {
        final result = HiveService.getDataByType<List<Map<String, dynamic>>>(
          [{'a': 1}, {'b': 2}],
        );
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(result.length, equals(2));
        expect(result[0]['a'], equals(1));
        expect(result[1]['b'], equals(2));
      });

      test('Raw List<Map<dynamic,dynamic>> from Hive is correctly converted', () {
        final rawList = <Map<dynamic, dynamic>>[
          <dynamic, dynamic>{'a': 1},
          <dynamic, dynamic>{'b': 2},
        ];
        final result = HiveService.getDataByType<List<Map<String, dynamic>>>(
          rawList,
        );
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(result.length, equals(2));
        expect(result[0]['a'], equals(1));
        expect(result[1]['b'], equals(2));
      });
    });
  });

  group('HiveService.getDataByType — edge cases', () {
    test('getDataByType<dynamic> returns value unchanged', () {
      const value = 'test';
      final result = HiveService.getDataByType<dynamic>(value);
      expect(result, equals(value));
    });

    test('getDataByType with correct type returns converted value', () {
      final original = {'key': 'value'};
      final result = HiveService.getDataByType<Map<String, dynamic>>(original);
      expect(result, isA<Map<String, dynamic>>());
      expect(result['key'], equals('value'));
    });
  });
}
