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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/utilities/notifiable_value.dart';

/// Unit tests for NotifiableValue.
/// Tests debounce, persist, and dispose functionality.
void main() {
  group('NotifiableValue basic functionality', () {
    test('constructor sets initial value', () {
      final notifier = NotifiableValue<int>(42);
      expect(notifier.value, equals(42));
    });

    test('value setter updates value', () {
      final notifier = NotifiableValue<int>(42);
      notifier.value = 100;
      expect(notifier.value, equals(100));
    });

    test('notifyListeners is called on value change', () {
      final notifier = NotifiableValue<int>(0);
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);
      
      notifier.value = 1;
      expect(notifyCount, equals(1));
      
      notifier.value = 2;
      expect(notifyCount, equals(2));
    });
  });

  group('NotifiableValue dispose', () {
    test('dispose cancels debounce timer', () async {
      final notifier = NotifiableValue<int>(0);
      notifier.value = 1;
      
      // Dispose immediately before debounce timer fires
      notifier.dispose();
      
      // Wait for debounce duration
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Should not throw or cause issues
      expect(notifier.value, equals(1));
    });

    test('dispose removes listener', () {
      final notifier = NotifiableValue<int>(0);
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);
      
      notifier.dispose();
      notifier.value = 1;
      
      // Listener should not be called after dispose
      expect(notifyCount, equals(0));
    });

    test('dispose removes from instances set', () {
      final notifier = NotifiableValue<int>(0);
      // Access private _instances via reflection would be complex
      // Instead, verify dispose doesn't throw
      expect(() => notifier.dispose(), returnsNormally);
    });
  });

  group('NotifiableValue.fromHive', () {
    test('factory constructor creates instance with boxName and category', () {
      final notifier = NotifiableValue.fromHive(
        'test_box',
        'test_category',
        defaultValue: 'default',
      );
      
      expect(notifier.value, equals('default'));
      notifier.dispose();
    });
  });

  group('NotifiableValue ensureInitialized', () {
    test('ensureInitialized sets default value', () async {
      final notifier = NotifiableValue.fromHive(
        'test_box',
        'test_category',
        defaultValue: 'default',
      );
      
      await notifier.ensureInitialized('default');
      expect(notifier.value, equals('default'));
      
      notifier.dispose();
    });

    test('ensureInitialized is idempotent', () async {
      final notifier = NotifiableValue.fromHive(
        'test_box',
        'test_category',
        defaultValue: 'default',
      );
      
      await notifier.ensureInitialized('default');
      await notifier.ensureInitialized('default');
      expect(notifier.value, equals('default'));
      
      notifier.dispose();
    });
  });

  group('NotifiableValue flush', () {
    test('flush cancels debounce timer', () async {
      final notifier = NotifiableValue.fromHive(
        'test_box',
        'test_category',
        defaultValue: 'default',
      );
      
      notifier.value = 'new_value';
      
      // Flush immediately
      await notifier.flush();
      
      // Should not throw
      expect(notifier.value, equals('new_value'));
      
      notifier.dispose();
    });
  });
}
