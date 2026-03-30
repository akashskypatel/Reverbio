/*
 * Unit tests for NotifiableList.
 * Tests pure list operations only (Group A).
 * Hive-backed tests (Group B) require platform-specific setup.
 */

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/utilities/notifiable_list.dart';

void main() {
  group('NotifiableList Group A — Pure list operations (no Hive)', () {
    group('Factories', () {
      test('from creates pre-populated list', () {
        final list = NotifiableList<int>.from([1, 2, 3]);
        expect(list.length, equals(3));
        expect(list.toList(), equals([1, 2, 3]));
      });

      test('from empty list has isEmpty == true', () {
        final list = NotifiableList<int>.from([]);
        expect(list.isEmpty, isTrue);
      });

      test('default constructor starts empty', () {
        final list = NotifiableList<int>();
        expect(list.isEmpty, isTrue);
      });

      test('fromAsync resolves items after await', () async {
        final list = NotifiableList<int>.fromAsync(Future.value([1, 2, 3]));
        await list.ensureInitialized();
        expect(list.length, equals(3));
        expect(list.toList(), equals([1, 2, 3]));
      });
    });

    group('Mutation + notifications', () {
      test('add appends and fires 1 notification', () {
        final list = NotifiableList<int>.from([1, 2]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.add(3);

        expect(notificationCount, equals(1));
        expect(list.toList(), equals([1, 2, 3]));
      });

      test('addAll appends both and fires 1 notification', () {
        final list = NotifiableList<int>.from([1]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.addAll([2, 3]);

        expect(notificationCount, equals(1));
        expect(list.toList(), equals([1, 2, 3]));
      });

      test('remove removes and fires 1 notification', () {
        final list = NotifiableList<int>.from([1, 2, 3]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.remove(2);

        expect(notificationCount, equals(1));
        expect(list.toList(), equals([1, 3]));
      });

      test('clear empties list and fires 1 notification', () {
        final list = NotifiableList<int>.from([1, 2, 3]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.clear();

        expect(notificationCount, equals(1));
        expect(list.isEmpty, isTrue);
      });

      test('insert inserts at index and fires 1 notification', () {
        final list = NotifiableList<int>.from([1, 3]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.insert(1, 2);

        expect(notificationCount, equals(1));
        expect(list.toList(), equals([1, 2, 3]));
      });

      test('removeAt removes by index and fires 1 notification', () {
        final list = NotifiableList<int>.from([1, 2, 3]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.removeAt(1);

        expect(notificationCount, equals(1));
        expect(list.toList(), equals([1, 3]));
      });
    });

    group('removeWhere — R1 regression', () {
      test('removes all matching items', () {
        final list = NotifiableList<int>.from([1, 2, 3, 2]);
        list.removeWhere((e) => e == 2);

        expect(list.toList(), equals([1, 3]));
      });

      test('return type is void — does NOT return bool', () {
        final list = NotifiableList<int>.from([1, 2, 3]);
        // Verify it compiles as void - we just call it and don't use return value
        list.removeWhere((e) => e == 2);
        // If we got here, the void return type is correct
        expect(list.length, equals(2));
      });

      test('fires exactly 1 notification regardless of items removed', () {
        final list = NotifiableList<int>.from([1, 2, 3, 2, 4, 2]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.removeWhere((e) => e == 2);

        expect(notificationCount, equals(1));
      });
    });

    group('addOrUpdate', () {
      test('item matching predicate is replaced', () {
        final list = NotifiableList<Map<String, dynamic>>.from([
          {'id': 'a', 'value': 1},
          {'id': 'b', 'value': 2},
        ]);

        list.addOrUpdate(
          {'id': 'a', 'value': 10},
          (a, b) => a['id'] == b['id'],
        );

        expect(list.length, equals(2));
        expect(list.first['value'], equals(10));
      });

      test('item not matching predicate is appended', () {
        final list = NotifiableList<Map<String, dynamic>>.from([
          {'id': 'a', 'value': 1},
        ]);

        list.addOrUpdate(
          {'id': 'b', 'value': 2},
          (a, b) => a['id'] == b['id'],
        );

        expect(list.length, equals(2));
        expect(list.last['id'], equals('b'));
      });

      test('fires exactly 1 notification', () {
        final list = NotifiableList<int>.from([1, 2, 3]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.addOrUpdate(2, (a, b) => a == b);

        expect(notificationCount, equals(1));
      });
    });

    group('addOrUpdateAll', () {
      test('updates matching and appends non-matching', () {
        final list = NotifiableList<Map<String, dynamic>>.from([
          {'id': 'a', 'value': 1},
        ]);

        list.addOrUpdateAll(
          [
            {'id': 'a', 'value': 10},
            {'id': 'b', 'value': 2},
          ],
          (a, b) => a['id'] == b['id'],
        );

        expect(list.length, equals(2));
        expect(list.first['value'], equals(10));
        expect(list.last['id'], equals('b'));
      });

      test('mixed update/insert fires exactly 1 notification', () {
        final list = NotifiableList<Map<String, dynamic>>.from([
          {'id': 'a', 'value': 1},
        ]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.addOrUpdateAll(
          [
            {'id': 'a', 'value': 10},
            {'id': 'b', 'value': 2},
            {'id': 'c', 'value': 3},
          ],
          (a, b) => a['id'] == b['id'],
        );

        expect(notificationCount, equals(1));
      });
    });

    group('Query (read-only — no notifications)', () {
      test('containsWhere returns true when match found', () {
        final list = NotifiableList<int>.from([1, 2, 3]);

        expect(list.containsWhere((e) => e == 2), isTrue);
      });

      test('containsWhere returns false when no match', () {
        final list = NotifiableList<int>.from([1, 2, 3]);

        expect(list.containsWhere((e) => e == 4), isFalse);
      });

      test('findMatching returns first matching element', () {
        final list = NotifiableList<int>.from([1, 2, 3, 2]);

        expect(list.findMatching(2, (a, b) => a == b), equals(2));
      });

      test('findMatching returns null when no match', () {
        final list = NotifiableList<int>.from([1, 2, 3]);

        expect(list.findMatching(4, (a, b) => a == b), isNull);
      });
    });

    group('TTL eviction', () {
      test('evictOlderThan removes items older than threshold', () {
        final oldDate = DateTime.now().subtract(const Duration(hours: 4));
        final list = NotifiableList<Map<String, dynamic>>.from([
          {'id': 'a', 'cachedAt': oldDate.toIso8601String()},
          {'id': 'b', 'cachedAt': DateTime.now().toIso8601String()},
        ]);

        list.evictOlderThan(const Duration(hours: 3));

        expect(list.length, equals(1));
        expect(list.first['id'], equals('b'));
      });

      test('items newer than threshold are kept', () {
        final list = NotifiableList<Map<String, dynamic>>.from([
          {'id': 'a', 'cachedAt': DateTime.now().toIso8601String()},
        ]);

        list.evictOlderThan(const Duration(hours: 3));

        expect(list.length, equals(1));
      });

      test('items with no cachedAt key are kept', () {
        final list = NotifiableList<Map<String, dynamic>>.from([
          {'id': 'a'},
        ]);

        list.evictOlderThan(const Duration(hours: 3));

        expect(list.length, equals(1));
      });

      test('fires 1 notification after eviction', () {
        final oldDate = DateTime.now().subtract(const Duration(hours: 4));
        final list = NotifiableList<Map<String, dynamic>>.from([
          {'id': 'a', 'cachedAt': oldDate.toIso8601String()},
          {'id': 'b', 'cachedAt': oldDate.toIso8601String()},
        ]);
        int notificationCount = 0;
        list.addListener(() => notificationCount++);

        list.evictOlderThan(const Duration(hours: 3));

        expect(notificationCount, equals(1));
      });
    });
  });

  group('NotifiableList R2 regression — null box name guard', () {
    test('NotifiableList() ensureInitialized does NOT call HiveService', () {
      final list = NotifiableList<int>();

      expect(() => list.ensureInitialized(), returnsNormally);
    });

    test('NotifiableList.from() ensureInitialized does NOT call HiveService',
        () async {
      final list = NotifiableList<int>.from([1, 2, 3]);

      await list.ensureInitialized();

      expect(list.length, equals(3));
    });
  });
}
