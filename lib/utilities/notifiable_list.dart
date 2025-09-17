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

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:reverbio/services/hive_service.dart';

class NotifiableList<T> with ChangeNotifier, ListMixin<T> {
  NotifiableList._internal(this._boxName, this._category);
  factory NotifiableList._() => NotifiableList.from([]);
  factory NotifiableList.from(Iterable<T> items) =>
      NotifiableList._()..addAll(items);
  factory NotifiableList.fromHive(String boxName, String category) =>
      NotifiableList._internal(boxName, category).._fromHive(boxName, category);

  Future<void> _fromHive(String boxName, String category) async {
    final items = await HiveService.getData(boxName, category);
    _items.addAll(items);
    addListener(_addOrUpdateListener);
  }

  final List<T> _items = [];
  final String? _boxName, _category;

  void _addOrUpdateListener() {
    HiveService.addOrUpdateData(_boxName!, _category!, _items);
  }

  @override
  void dispose() {
    removeListener(_addOrUpdateListener);
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

  void addOrUpdate(T item, bool Function(T) predicate) {
    final index = _items.indexWhere(predicate);
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

  bool updateWhere(T item, bool Function(T) predicate) {
    final index = _items.indexWhere(predicate);
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
      return true;
    }
    return false;
  }

  T? find(bool Function(T) predicate) {
    try {
      return _items.firstWhere(predicate);
    } catch (e) {
      return null;
    }
  }

  bool containsWhere(bool Function(T) predicate) {
    return _items.any(predicate);
  }

  List<T> whereToList(bool Function(T) predicate) {
    return _items.where(predicate).toList();
  }
}
