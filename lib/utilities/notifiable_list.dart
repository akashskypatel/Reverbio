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
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/utilities/notifiable_future.dart'
    show FutureTrackerState;

class NotifiableList<T> with ChangeNotifier, ListMixin<T> {
  // R4 fix: Static registry to track all instances for flush on shutdown
  static final Set<NotifiableList> _instances = {};
  
  NotifiableList() : _boxName = null, _category = null, _isInitialized = true;
  NotifiableList._internal(
    this._boxName,
    this._category, {
    bool Function(T, T)? test,
    Iterable<T>? initialItems,
    T Function(T)? minimizeFunction,
  }) : _minimize = minimizeFunction {
    if (initialItems != null) {
      _items.addAll(initialItems);
    }
    if (_boxName == null || _category == null) {
      _isInitialized = true;
      _initializationCompleter.complete(_items);
    } else {
      _initializeFromHive(test);
    }
  }
  NotifiableList._internalAsync(Future<Iterable<T>> itemsFuture)
    : _boxName = null,
      _category = null {
    _initializeFromAsync(itemsFuture);
  }
  factory NotifiableList.from(Iterable<T> items) =>
      NotifiableList._internal(null, null, initialItems: items);
  factory NotifiableList.fromAsync(Future<Iterable<T>> itemsFuture) =>
      NotifiableList._internalAsync(itemsFuture);

  factory NotifiableList.fromHive(
    String boxName,
    String category, {
    T Function(T)? minimizeFunction,
  }) {
    return NotifiableList._internal(
      boxName,
      category,
      minimizeFunction: minimizeFunction,
    );
  }
  // R7 fix: Note intentional asymmetry - _initializeFromAsync does not add writeToCache listener
  // because it's used for non-Hive async data sources that shouldn't be persisted.
  // Only _initializeFromHive adds the writeToCache listener for Hive-backed lists.
  Future<void> _initializeFromAsync(Future<Iterable<T>> itemsFuture) async {
    notifyListeners();
    try {
      final value = await itemsFuture;
      _items.addAll(value);
      _isInitialized = true;
      _initializationCompleter.complete(_items);
    } catch (e, stackTrace) {
      _isInitialized = true;
      _initializationCompleter.completeError(e);
      _hasError = true;
      debugPrint('Error in ${stackTrace.getCurrentMethodName()}: $e');
    }
    notifyListeners();
  }

  Future<void> _initializeFromHive([bool Function(T, T)? test]) async {
    notifyListeners();
    if (_boxName == null || _category == null) {
      _isInitialized = true;
      return;
    }
    try {
      final value =
          await HiveService.getData<List<T>>(
            _boxName,
            _category,
            defaultValue: <T>[],
          ) ??
          <T>[];
      if (test != null)
        for (final item in value) {
          final index = _items.indexWhere((e) => test(e, item));
          if (index != -1) {
            _items[index] = item;
          } else {
            _items.add(item);
          }
        }
      else
        // R8 fix: Don't apply minimize on load - data is already minimized on write
        _items.addAll(value);
      addListener(writeToCache);
      _isInitialized = true;
      _initializationCompleter.complete(_items);
      // R4 fix: Register instance for flush on shutdown
      _instances.add(this);
    } catch (e, stackTrace) {
      _error = e;
      _stackTrace = stackTrace;
      _isInitialized = true;
      _initializationCompleter.completeError(e);
      _hasError = true;
      debugPrint('Error in ${stackTrace.getCurrentMethodName()}: $e');
    }
    notifyListeners();
  }

  final List<T> _items = [];
  final String? _boxName, _category;
  bool _isInitialized = false;
  bool _hasError = false;
  dynamic _error;
  StackTrace? _stackTrace;
  final Completer<Iterable<T>> _initializationCompleter =
      Completer<Iterable<T>>();
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 1000);
  T Function(T)? _minimize;
  bool get isLoading => !_isInitialized;
  bool get hasError => _hasError;
  bool get hasData => _items.isNotEmpty;
  Completer<Iterable<T>> get completer => _initializationCompleter;

  Future<Iterable<T>> ensureInitialized() async {
    if (_isInitialized) return _items;
    // R5 fix: Wait for initialization to complete if in progress
    if (!_initializationCompleter.isCompleted) {
      return _initializationCompleter.future;
    }
    // Initialization already completed (may have failed)
    // Note: If initialization failed, caller can check hasError property
    // Retry would require recreating the completer (not implemented)
    return _items;
  }

  void writeToCache() {
    if (_boxName == null || _category == null) return;

    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    // Start new debounce timer
    _debounceTimer = Timer(_debounceDuration, () {
      if (_minimize != null)
        HiveService.addOrUpdateData<List<T>>(
          _boxName,
          _category,
          _items.map(_minimize!).toList(),
        );
      else
        HiveService.addOrUpdateData<List<T>>(_boxName, _category, _items);
    });
  }

  // R4 fix: Flush pending writes immediately (bypass debounce)
  void flush() {
    if (_boxName == null || _category == null) return;
    // Cancel any pending timer
    _debounceTimer?.cancel();
    // Write immediately
    if (_minimize != null)
      HiveService.addOrUpdateData<List<T>>(
        _boxName,
        _category,
        _items.map(_minimize!).toList(),
      );
    else
      HiveService.addOrUpdateData<List<T>>(_boxName, _category, _items);
  }

  // R4 fix: Flush all instances (called on app shutdown)
  static void flushAll() {
    for (final instance in _instances) {
      instance.flush();
    }
  }

  @override
  void dispose() {
    if (_boxName != null && _category != null) {
      removeListener(writeToCache);
      // R4 fix: Flush pending writes before disposing
      flush();
    }
    _debounceTimer?.cancel(); // Cancel timer on dispose
    // R4 fix: Remove from registry
    _instances.remove(this);
    super.dispose();
  }

  // R4 fix: Evict items older than the specified TTL
  // Used for cache eviction based on cachedAt timestamp
  void evictOlderThan(Duration ttl) {
    final cutoff = DateTime.now().subtract(ttl);
    final toRemove = <int>[];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item is Map && item['cachedAt'] is String) {
        try {
          final cachedAt = DateTime.parse(item['cachedAt'] as String);
          if (cachedAt.isBefore(cutoff)) {
            toRemove.add(i);
          }
        } catch (_) {
          // Skip items with invalid cachedAt
        }
      }
    }
    // Remove in reverse order to maintain correct indices
    for (final index in toRemove.reversed) {
      _items.removeAt(index);
    }
    if (toRemove.isNotEmpty) {
      notifyListeners();
    }
  }

  @override
  int get length => _items.length;

  @override
  set length(int newLength) {
    _items.length = newLength;
    notifyListeners();
  }

  @override
  T operator [](int index) => _items[index];

  @override
  void operator []=(int index, T value) {
    _items[index] = value;
    notifyListeners();
  }

  @override
  void add(T element) {
    _items.add(element);
    notifyListeners();
  }

  @override
  void addAll(Iterable<T> iterable) {
    _items.addAll(iterable);
    notifyListeners();
  }

  @override
  void insert(int index, T element) {
    _items.insert(index, element);
    notifyListeners();
  }

  @override
  void insertAll(int index, Iterable<T> iterable) {
    _items.insertAll(index, iterable);
    notifyListeners();
  }

  @override
  bool remove(Object? element) {
    final removed = _items.remove(element);
    if (removed) notifyListeners();
    return removed;
  }

  @override
  T removeAt(int index) {
    final removed = _items.removeAt(index);
    notifyListeners();
    return removed;
  }

  @override
  void removeRange(int start, int end) {
    _items.removeRange(start, end);
    notifyListeners();
  }

  @override
  void clear() {
    _items.clear();
    notifyListeners();
  }

  @override
  List<T> toList({bool growable = true}) =>
      List<T>.from(_items, growable: growable);

  @override
  T removeLast() {
    final last = _items.removeLast();
    notifyListeners();
    return last;
  }

  @override
  void retainWhere(bool Function(T element) test) {
    final beforeLength = _items.length;
    _items.retainWhere(test);
    // R6 fix: Only notify if length changed (something was removed)
    if (_items.length != beforeLength) {
      notifyListeners();
    }
  }

  @override
  void removeWhere(bool Function(T) test) {
    final removed = _items.any(test);
    _items.removeWhere(test);
    if (removed) {
      notifyListeners();
    }
  }

  void addOrUpdate(T item, bool Function(T, T) predicate) {
    final index = _items.indexWhere((e) => predicate(e, item));
    if (index != -1) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  // R3 fix: Inline addOrUpdate logic to avoid O(n²) notifications
  void addOrUpdateAll(List<T> items, bool Function(T, T) predicate) {
    for (final item in items) {
      final index = _items.indexWhere((e) => predicate(e, item));
      if (index != -1) {
        _items[index] = item;
      } else {
        _items.add(item);
      }
    }
    // Single notification at end instead of per-item
    notifyListeners();
  }

  void batchUpdate(void Function(List<T>) updateFn) {
    updateFn(_items);
    notifyListeners();
  }

  void replaceAll(Iterable<T> newItems) {
    _items
      ..clear()
      ..addAll(newItems);
    notifyListeners();
  }

  int indexOfMatching(T item, bool Function(T, T) predicate) {
    return _items.indexWhere((e) => predicate(e, item));
  }

  bool updateMatching(T item, bool Function(T, T) predicate) {
    final index = _items.indexWhere((e) => predicate(e, item));
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool updateWhere(T item, bool Function(T) predicate) {
    final index = _items.indexWhere(predicate);
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
      return true;
    }
    return false;
  }

  T? findMatching(T item, bool Function(T, T) predicate) {
    try {
      return _items.firstWhere((e) => predicate(e, item));
    } catch (e) {
      return null;
    }
  }

  T? findWhere(bool Function(T) predicate) {
    try {
      return _items.firstWhere(predicate);
    } catch (e) {
      return null;
    }
  }

  bool containsMatching(T item, bool Function(T, T) predicate) {
    return _items.any((e) => predicate(e, item));
  }

  bool containsWhere(bool Function(T) predicate) {
    return _items.any(predicate);
  }

  List<T> whereToList(bool Function(T) predicate) {
    return _items.where(predicate).toList();
  }

  FutureTrackerState get state {
    if (isLoading) return FutureTrackerState.loading;
    if (hasError) return FutureTrackerState.error;
    // R8 fix: Distinguish "loaded but empty" from "never loaded"
    if (_isInitialized) return FutureTrackerState.success;
    if (hasData) return FutureTrackerState.success;
    return FutureTrackerState.idle;
  }

  // Helper method for easy widget building
  Widget build({
    required Widget Function(List<T>? data) data,
    Widget Function()? loading,
    Widget Function(dynamic error, StackTrace? stackTrace)? error,
    Widget Function()? idle,
  }) {
    return ListenableBuilder(
      listenable: this,
      builder: (context, child) {
        switch (state) {
          case FutureTrackerState.loading:
            return loading?.call() ?? const CircularProgressIndicator.adaptive();
          case FutureTrackerState.success:
            return data(_items);
          case FutureTrackerState.error:
            debugPrint('Error: $_error');
            return error?.call(_error, _stackTrace) ??
                Text(L10n.current.runtimeError);
          case FutureTrackerState.idle:
          default:
            return idle?.call() ?? const SizedBox.shrink();
        }
      },
    );
  }
}
