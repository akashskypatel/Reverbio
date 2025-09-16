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

import 'package:flutter/material.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/widgets/spinner.dart';

enum FutureTrackerState { idle, loading, success, error, cancelled }

class CancelledException implements Exception {
  CancelledException([this.message = 'Operation cancelled']);
  final String message;

  @override
  String toString() => message;
}

class NotifiableFuture<T> with ChangeNotifier {
  factory NotifiableFuture([T? initialData]) =>
      NotifiableFuture._internal(initialData);
  factory NotifiableFuture.withFuture(T? initialData, Future<T> future) {
    final _new = NotifiableFuture._internal(initialData)..runFuture(future);
    return _new;
  }
  factory NotifiableFuture.fromValue(T? initialData, {T? resultValue}) {
    final _new = NotifiableFuture._internal(initialData)
      .._runFutureValue(resultValue ?? initialData);
    return _new;
  }
  factory NotifiableFuture.copyFrom(NotifiableFuture<T> other) {
    final _new =
        NotifiableFuture._internal(other.data)
          .._error = other._error
          .._isCancelled = other._isCancelled
          .._isLoading = other._isLoading
          .._result = other._result
          .._stackTrace = other._stackTrace;
    if (other._completer != null) {
      // Create a fresh completer for the new instance
      _new._completer = Completer<T>();

      other._completer!.future.then(
        (value) {
          if (!_new._isCancelled) {
            _new
              .._result = value
              .._isLoading = false;
            _new._completer?.complete(value);
            _new.notifyListeners();
          }
        },
        onError: (err, st) {
          _new
            .._error = err
            .._stackTrace = st
            .._isLoading = false;
          if (!(_new._completer?.isCompleted ?? true)) {
            _new._completer?.completeError(err, st);
          }
          _new.notifyListeners();
        },
      );
    }
    return _new;
  }
  NotifiableFuture._internal([T? initialData]) : _initialData = initialData;
  T? _initialData;
  dynamic _error;
  StackTrace? _stackTrace;
  Completer<T>? _completer;
  bool _isLoading = false;
  bool _isCancelled = false;
  T? _result;

  T? get data => _initialData;
  dynamic get error => _error;
  StackTrace? get stackTrace => _stackTrace;
  bool get isLoading => _isLoading;
  bool get isCancelled => _isCancelled;
  bool get isComplete => _completer?.isCompleted ?? false;
  bool get hasError => _error != null;
  bool get hasData => _initialData != null;
  bool get hasResult => _result != null;
  Completer<T>? get completer => _completer;
  Future<T?>? get completerFuture => completer?.future;
  T? get result => _result;
  T? get resultOrData => _result ?? _initialData;
  
  void copyValuesFrom(NotifiableFuture<T> other) {
    _error = other._error;
    _isCancelled = other._isCancelled;
    _isLoading = other._isLoading;
    _result = other._result;
    _stackTrace = other._stackTrace;
    _initialData = other._initialData;

    // Mirror completer state if present
    if (other._completer != null) {
      _completer ??= Completer<T>();
      other._completer!.future.then(
        (value) {
          if (!_isCancelled) {
            _result = value;
            _isLoading = false;
            if (!(_completer?.isCompleted ?? true)) {
              _completer?.complete(value);
            }
            notifyListeners();
          }
        },
        onError: (err, st) {
          _error = err;
          _stackTrace = st;
          _isLoading = false;
          if (!(_completer?.isCompleted ?? true)) {
            _completer?.completeError(err, st);
          }
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  void setData(T? newData) {
    if (newData != null) _initialData = newData;
    notifyListeners();
  }

  void setResult(T? newData) {
    if (newData != null) _result = newData;
    notifyListeners();
  }

  void _runFutureValue(T? value) {
    _completer = Completer<T>()..complete(value);
    _isLoading = false;
    _isCancelled = false;
    _result = value;
    notifyListeners();
  }

  Future<T?> runFuture(Future<T> future, {bool forceRefresh = false}) async {
    // If already loading and not forcing refresh, return current future
    if (_isLoading && !forceRefresh && _completer != null) {
      notifyListeners();
      return _completer!.future;
    }

    // Reset state for new future (but preserve existing data unless forceRefresh)
    _resetState(clearData: forceRefresh);
    _isLoading = true;
    _isCancelled = false;
    _completer = Completer<T>();

    notifyListeners();

    try {
      _result = await future;

      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(_result);
      }

      _isLoading = false;
      notifyListeners();
      return _result;
    } catch (error, stackTrace) {
      _error = error;
      _stackTrace = stackTrace;
      _isLoading = false;

      if (_completer != null && !_completer!.isCompleted) {
        _completer!.completeError(error, stackTrace);
      }

      notifyListeners();
      rethrow;
    }
  }

  Future<T?> runFutureIfNotComplete(Future<T> future) async {
    if (isComplete && hasData) {
      return _initialData as T;
    }
    return runFuture(future);
  }

  void cancel() {
    if (_isLoading && _completer != null && !_completer!.isCompleted) {
      _completer!.completeError(CancelledException());
      _isCancelled = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset({bool clearData = false}) {
    _resetState(clearData: clearData);
    notifyListeners();
  }

  void updateData(T newData) {
    _initialData = newData;
    _error = null;
    _stackTrace = null;
    _isCancelled = false;
    notifyListeners();
  }

  void _resetState({bool clearData = false}) {
    _error = null;
    _stackTrace = null;
    _completer = null;
    _isLoading = false;
    _isCancelled = false;
    _result = null;
    if (clearData) {
      _initialData = null;
    }
    notifyListeners();
  }

  FutureTrackerState get state {
    if (_isLoading) return FutureTrackerState.loading;
    if (_isCancelled) return FutureTrackerState.cancelled;
    if (hasError) return FutureTrackerState.error;
    if (isComplete && _result != null) return FutureTrackerState.success;
    return FutureTrackerState.idle;
  }

  // Helper method for easy widget building
  Widget build({
    required Widget Function()? loading,
    required Widget Function(T? data) data,
    required Widget Function(dynamic error, StackTrace? stackTrace) error,
    Widget Function()? idle,
    Widget Function()? cancelled,
  }) {
    switch (state) {
      case FutureTrackerState.loading:
        return loading?.call() ?? const Spinner();
      case FutureTrackerState.success:
        return data(_result);
      case FutureTrackerState.error:
        logger.log(
          'Error in ${stackTrace?.getCurrentMethodName()}:',
          _error,
          stackTrace,
        );
        return error(_error, _stackTrace);
      case FutureTrackerState.cancelled:
        return cancelled?.call() ?? const Text('Operation cancelled');
      case FutureTrackerState.idle:
        return idle?.call() ?? const SizedBox.shrink();
    }
  }

  @override
  void dispose() {
    _completer = null;
    _initialData = null;
    _result = null;
    _error = null;
    _stackTrace = null;
    super.dispose();
  }
}
