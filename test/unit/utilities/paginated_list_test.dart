/*
 * Unit tests for PaginatedList.
 * Tests pagination logic, boundary conditions, and notifications.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/utilities/paginated_list.dart';

void main() {
  // Initialize Flutter binding for ChangeNotifier tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaginatedList constructor/factory', () {
    test('PaginatedList with pageSize creates pages correctly', () {
      final list = PaginatedList([1, 2, 3, 4, 5], pageSize: 2, randomSeed: 42);
      // PaginatedList shuffles items, so just verify page size is correct
      expect(list.getCurrentPage().length, equals(2));
    });

    test('PaginatedList with empty list has empty first page', () {
      final list = PaginatedList([]);
      expect(list.getCurrentPage(), equals([]));
    });

    test('PaginatedList.fromAsync resolves items after await', () async {
      final list = PaginatedList.fromAsync(Future.value([1, 2, 3]));
      await list.updateItems(Future.value([1, 2, 3]));
      expect(list.getCurrentPage().length, equals(3));
    });
  });

  group('PaginatedList pagination', () {
    late PaginatedList<int> list;

    setUp(() {
      list = PaginatedList([1, 2, 3, 4, 5], pageSize: 2, randomSeed: 42);
    });

    test('getNextPage advances page index', () {
      final firstPage = list.getCurrentPage();
      list.getNextPage();
      final secondPage = list.getCurrentPage();
      // Pages should be different after getNextPage
      expect(firstPage, isNot(equals(secondPage)));
    });

    test('getNextPage at last page does not overflow', () {
      // Keep calling getNextPage until we reach the end
      list.getNextPage();
      list.getNextPage();
      final lastPage = list.getCurrentPage();
      list.getNextPage(); // should stay on last page
      expect(list.getCurrentPage(), equals(lastPage));
    });

    test('getPreviousPage at first page does not underflow', () {
      final firstPage = list.getCurrentPage();
      list.getPreviousPage();
      expect(list.getCurrentPage(), equals(firstPage));
    });

    test('getPreviousPage from page 1 returns to page 0', () {
      list.getNextPage(); // page 1
      final page1 = list.getCurrentPage();
      list.getPreviousPage(); // page 0
      final page0 = list.getCurrentPage();
      expect(page0, isNot(equals(page1)));
    });

    test('hasNextPage returns false at last page', () {
      // Navigate to last page
      while (list.hasNextPage) {
        list.getNextPage();
      }
      expect(list.hasNextPage, isFalse);
    });

    test('hasPreviousPage returns false at first page', () {
      expect(list.hasPreviousPage, isFalse);
    });

    test('hasPreviousPage returns true after getNextPage', () {
      list.getNextPage();
      expect(list.hasPreviousPage, isTrue);
    });

    test('currentPageNumber returns 1-based index', () {
      expect(list.currentPageNumber, equals(1));
      list.getNextPage();
      expect(list.currentPageNumber, equals(2));
    });
  });

  group('PaginatedList notifications', () {
    test('getNextPage fires exactly one notification', () {
      final list = PaginatedList([1, 2, 3, 4, 5], pageSize: 2, randomSeed: 42);
      int notificationCount = 0;
      list.addListener(() => notificationCount++);

      list.getNextPage();

      expect(notificationCount, equals(1));
    });

    test('getPreviousPage fires exactly one notification', () {
      final list = PaginatedList([1, 2, 3, 4, 5], pageSize: 2, randomSeed: 42);
      int notificationCount = 0;
      list.addListener(() => notificationCount++);

      list.getNextPage();
      list.getPreviousPage();

      expect(notificationCount, equals(2));
    });

    test('removed listener does not receive notifications', () {
      final list = PaginatedList([1, 2, 3, 4, 5], pageSize: 2, randomSeed: 42);
      int notificationCount = 0;
      void listener() => notificationCount++;

      list.addListener(listener);
      list.removeListener(listener);
      list.getNextPage();

      expect(notificationCount, equals(0));
    });
  });

  group('PaginatedList edge cases', () {
    test('single-item list has one page', () {
      final list = PaginatedList([1], pageSize: 2, randomSeed: 42);
      expect(list.getCurrentPage().length, equals(1));
      list.getNextPage();
      expect(list.getCurrentPage().length, equals(1));
    });

    test('pageSize larger than list length shows all items on first page', () {
      final list = PaginatedList([1, 2, 3], pageSize: 10, randomSeed: 42);
      expect(list.getCurrentPage().length, equals(3));
      list.getNextPage();
      expect(list.getCurrentPage().length, equals(3));
    });

    test('items added via updateItems reflect in getCurrentPage', () async {
      final list = PaginatedList([1, 2], pageSize: 2, randomSeed: 42);
      await list.updateItems(Future.value([1, 2, 3, 4, 5]));
      expect(list.getCurrentPage().length, equals(2));
      list.getNextPage();
      expect(list.getCurrentPage().length, equals(2));
    });

    test('reset clears page history', () {
      final list = PaginatedList([1, 2, 3, 4, 5], pageSize: 2, randomSeed: 42);
      list.getNextPage();
      list.reset();
      expect(list.currentPageNumber, equals(1));
    });
  });
}
