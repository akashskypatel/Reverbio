/*
 * Unit tests for NotifiableFuture.
 * Tests state machine and basic functionality.
 */

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/utilities/notifiable_future.dart';

void main() {
  group('NotifiableFuture initial state', () {
    test('default constructor has idle state', () {
      final nf = NotifiableFuture<int>();
      expect(nf.state, equals(FutureTrackerState.idle));
      expect(nf.isLoading, isFalse);
      expect(nf.hasData, isFalse);
      expect(nf.hasResult, isFalse);
      expect(nf.error, isNull);
    });

    test('constructor with initialData has correct data', () {
      final nf = NotifiableFuture<int>(42);
      expect(nf.data, equals(42));
      expect(nf.state, equals(FutureTrackerState.idle));
    });
  });

  group('NotifiableFuture runFuture — success path', () {
    test('state transitions idle → loading → success', () async {
      final nf = NotifiableFuture<int>();
      final states = <FutureTrackerState>[];
      nf.addListener(() => states.add(nf.state));

      final completer = Completer<int>();
      final runFuture = nf.runFuture(completer.future);

      expect(nf.state, equals(FutureTrackerState.loading));

      completer.complete(42);
      await runFuture;

      expect(nf.state, equals(FutureTrackerState.success));
      expect(states, containsAll([FutureTrackerState.loading, FutureTrackerState.success]));
    });

    test('result holds resolved value', () async {
      final nf = NotifiableFuture<int>();
      final completer = Completer<int>();
      final runFuture = nf.runFuture(completer.future);

      completer.complete(42);
      await runFuture;

      expect(nf.result, equals(42));
    });

    test('isLoading is true while pending', () async {
      final nf = NotifiableFuture<int>();
      final completer = Completer<int>();
      nf.runFuture(completer.future);

      expect(nf.isLoading, isTrue);

      completer.complete(42);
      await nf.completerFuture;

      expect(nf.isLoading, isFalse);
    });
  });

  group('NotifiableFuture dispose() — R3 regression', () {
    test('after dispose runFuture throws StateError', () {
      final nf = NotifiableFuture<int>();
      nf.dispose();

      expect(
        () => nf.runFuture(Future.value(42)),
        throwsA(isA<StateError>()),
      );
    });

    test('after dispose listener count is 0', () {
      final nf = NotifiableFuture<int>();
      nf.addListener(() {});
      nf.dispose();

      expect(nf.hasListeners, isFalse);
    });
  });

  group('NotifiableFuture reset / updateData / setData / setResult', () {
    test('reset clearData clears initialData', () {
      final nf = NotifiableFuture<int>(42);
      nf.reset(clearData: true);

      expect(nf.data, isNull);
    });

    test('updateData updates initialData and clears error', () {
      final nf = NotifiableFuture<int>();
      nf.updateData(99);

      expect(nf.data, equals(99));
      expect(nf.error, isNull);
    });

    test('setData null does not update initialData', () {
      final nf = NotifiableFuture<int>(42);
      nf.setData(null);

      expect(nf.data, equals(42));
    });

    test('setResult null does not update result', () {
      final nf = NotifiableFuture<int>();
      nf.runFuture(Future.value(42));
      nf.setResult(null);

      expect(nf.result, isNull);
    });
  });

  group('NotifiableFuture copyValuesFrom', () {
    test('copies state fields from another NotifiableFuture', () async {
      final source = NotifiableFuture<int>(10);
      final completer = Completer<int>();
      source.runFuture(completer.future);

      final target = NotifiableFuture<int>();
      target.copyValuesFrom(source);

      completer.complete(42);
      await source.completerFuture;

      expect(target.result, equals(42));
    });

    test('does nothing if disposed', () {
      final source = NotifiableFuture<int>(10);
      final target = NotifiableFuture<int>();
      target.dispose();

      target.copyValuesFrom(source);

      expect(target.data, isNull);
    });
  });
}
