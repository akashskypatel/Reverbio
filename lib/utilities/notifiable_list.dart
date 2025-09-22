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
import 'package:reverbio/main.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/utilities/notifiable_future.dart'
    show FutureTrackerState;
import 'package:reverbio/widgets/spinner.dart';

class NotifiableList<T> with ChangeNotifier, ListMixin<T> {
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
    _initializeFromHive(test);
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
  Future<void> _initializeFromAsync(Future<Iterable<T>> itemsFuture) async {
    _initializationCompleter = Completer<void>();
    try {
      final value = await itemsFuture;
      addAll(value);
      _isInitialized = true;
      _initializationCompleter!.complete();
    } catch (e, stackTrace) {
      _isInitialized = true;
      _initializationCompleter!.completeError(e);
      _hasError = true;
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    notifyListeners();
  }

  Future<void> _initializeFromHive([bool Function(T, T)? test]) async {
    if (_boxName == null || _category == null) {
      _isInitialized = true;
      return;
    }
    _initializationCompleter = Completer<void>();
    try {
      final value =
          (await HiveService.getData<List<T>>(_boxName, _category, defaultValue: _items) ?? _items)
              as List<T>;
      if (test != null)
        for (final item in value)
          addOrUpdate(_minimize == null ? item : _minimize!(item), test);
      else
        addAll(value.map((e) => _minimize == null ? e : _minimize!(e)));
      addListener(writeToCache);
      _isInitialized = true;
      _initializationCompleter!.complete();
    } catch (e, stackTrace) {
      _error = e;
      _stackTrace = stackTrace;
      _isInitialized = true;
      _initializationCompleter!.completeError(e);
      _hasError = true;
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    notifyListeners();
  }

  final List<T> _items = [];
  final String? _boxName, _category;
  bool _isInitialized = false;
  bool _hasError = false;
  dynamic _error;
  StackTrace? _stackTrace;
  Completer<void>? _initializationCompleter;
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 1000);
  T Function(T)? _minimize;
  bool get isLoading => !_isInitialized;
  bool get hasError => _hasError;
  bool get hasData => _items.isNotEmpty;

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }
    await _initializeFromHive();
  }

  void writeToCache() {
    if (_boxName == null || _category == null) return;

    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    // Start new debounce timer
    _debounceTimer = Timer(_debounceDuration, () {
      if (_minimize != null)
        HiveService.addOrUpdateData(
          _boxName,
          _category,
          _items.map(_minimize!).toList(),
        );
      else
        HiveService.addOrUpdateData(_boxName, _category, _items);
    });
  }

  @override
  void dispose() {
    if (_boxName != null && _category != null) {
      removeListener(writeToCache);
    }
    _debounceTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
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
    _items.retainWhere(test);
    notifyListeners();
  }

  @override
  bool removeWhere(bool Function(T) test) {
    final removed = _items.any(test);
    _items.removeWhere(test);
    if (removed) {
      notifyListeners();
    }
    return removed;
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
    switch (state) {
      case FutureTrackerState.loading:
        return loading?.call() ?? const Spinner();
      case FutureTrackerState.success:
        return data(_items);
      case FutureTrackerState.error:
        logger.log(
          'Error in ${_stackTrace?.getCurrentMethodName()}:',
          _error,
          _stackTrace,
        );
        return error?.call(_error, _stackTrace) ??
            Text(L10n.current.runtimeError);
      case FutureTrackerState.idle:
      default:
        return idle?.call() ?? const SizedBox.shrink();
    }
  }
}
