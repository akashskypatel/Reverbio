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

import 'package:reverbio/main.dart';

class CancelledException implements Exception {
  @override
  String toString() => 'Operation was cancelled';
}

class FutureTracker<T> {
  FutureTracker(this.data);
  T? data;
  dynamic result;
  Completer<T>? completer;
  bool isLoading = false;
  bool isCancelled = false;
  bool get isComplete => completer?.isCompleted ?? false;

  Future<T> runFuture(Future<T> future) async {
    if (!isLoading && !isComplete) {
      isLoading = true;
      completer = Completer<T>();
      await future
          .then((result) {
            if (!completer!.isCompleted) {
              completer!.complete(result);
              this.result = result;
            }
            isLoading = false;
          })
          .catchError((error) {
            logger.log(
              'Error occurred in FutureTracker runFuture',
              error,
              null,
            );
            if (!completer!.isCompleted) {
              completer!.completeError(error);
            }
            isLoading = false;
          });
    }

    return completer!.future;
  }

  void cancel() {
    if (!isComplete && !isLoading) {
      completer?.completeError(CancelledException());
      completer?.future.timeout(Duration.zero);
      completer?.future.ignore();
    }
    isLoading = false;
    isCancelled = true;
  }
}