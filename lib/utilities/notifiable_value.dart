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
 *
 *
 *     For more information about Reverbio, including how to contribute,
 *     please visit: https://github.com/akashskypatel/Reverbio
 */

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:reverbio/services/hive_service.dart';

class NotifiableValue<T> extends ValueNotifier<T> {
  // R5 fix: Add non-Hive constructor for non-nullable fields
  NotifiableValue(super.value) : _boxName = null, _category = null;
  NotifiableValue._internal(this._boxName, this._category, super.value);
  factory NotifiableValue.fromHive(
    String boxName,
    String category, {
    required T defaultValue,
  }) {
    return NotifiableValue._internal(boxName, category, defaultValue);
  }
  final String? _boxName;
  final String? _category;
  bool _isInitialized = false;
  bool _disposed = false;
  Completer<void>? _initializationCompleter;
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  // R6 fix: Static list to track all instances for shutdown flush
  static final Set<NotifiableValue> _instances = {};

  Future<void> _initializeFromHive() async {
    _instances.add(this);
    if (_boxName == null || _category == null) {
      _isInitialized = true;
      return;
    }
    _initializationCompleter = Completer<void>();
    try {
      final storedValue = await HiveService.getData<T?>(
        _boxName,
        _category,
        defaultValue: value,
      );
      // R2 fix: Assign value before adding listener to prevent spurious write-back
      value = storedValue ?? value;
      addListener(_addOrUpdateListener);
      _isInitialized = true;
      _initializationCompleter!.complete();
    } catch (e) {
      _isInitialized = true;
      _initializationCompleter!.completeError(e);
    }
  }

  Future<void> ensureInitialized(T defaultValue) async {
    if (_isInitialized) return;
    // R4 fix: Create completer before calling _initializeFromHive to prevent race condition
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }
    _initializationCompleter = Completer<void>();
    value = defaultValue;
    await _initializeFromHive();
  }

  void _addOrUpdateListener() {
    if (_disposed) return;
    if (_boxName == null || _category == null) return;

    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    // Start new debounce timer
    _debounceTimer = Timer(_debounceDuration, () {
      if (!_disposed) {
        HiveService.addOrUpdateData<T>(_boxName, _category, value);
      }
    });
  }

  // R6 fix: Instance method to flush pending write immediately
  Future<void> flush() async {
    if (_disposed || _boxName == null || _category == null) return;
    _debounceTimer?.cancel();
    await HiveService.addOrUpdateData<T>(_boxName, _category, value);
  }

  // R6 fix: Static method to flush all pending writes before shutdown
  static Future<void> flushAll() async {
    for (final instance in _instances) {
      await instance.flush();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _instances.remove(this);
    _debounceTimer?.cancel();
    // Remove listener before disposing
    removeListener(_addOrUpdateListener);
    super.dispose();
  }
}
