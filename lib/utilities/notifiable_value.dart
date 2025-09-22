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

class NotifiableValue<T> extends ValueNotifier {
  NotifiableValue._internal(this._boxName, this._category, super.value);
  factory NotifiableValue.fromHive(
    String boxName,
    String category, {
    required T defaultValue,
  }) {
    return NotifiableValue._internal(boxName, category, defaultValue);
  }
  final String? _boxName, _category;
  bool _isInitialized = false;
  Completer<void>? _initializationCompleter;
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  Future<void> _initializeFromHive() async {
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
      addListener(_addOrUpdateListener);
      value = storedValue ?? value;
      _isInitialized = true;
      _initializationCompleter!.complete();
    } catch (e) {
      _isInitialized = true;
      _initializationCompleter!.completeError(e);
    }
  }

  Future<void> ensureInitialized(T defaultValue) async {
    if (_isInitialized) return;
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }
    value = defaultValue;
    await _initializeFromHive();
  }

  void _addOrUpdateListener() {
    if (_boxName == null || _category == null) return;

    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    // Start new debounce timer
    _debounceTimer = Timer(_debounceDuration, () {
      HiveService.addOrUpdateData(_boxName, _category, value);
    });
  }
}
