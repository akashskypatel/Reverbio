import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/common_variables.dart';

class CancelledException implements Exception {
  @override
  String toString() => 'Operation was cancelled';
}

class FutureTracker<T> {
  Completer<T>? completer;
  bool isLoading = false;
  bool get isComplete => completer?.isCompleted ?? false;

  Future<T> runFuture(Future<T> future) {
    if (!isLoading && !isComplete) {
      isLoading = true;
      completer = Completer<T>();

      future
          .then((result) {
            if (!completer!.isCompleted) {
              completer!.complete(result);
            }
            isLoading = false;
          })
          .catchError((error) {
            if (!completer!.isCompleted) {
              completer!.completeError(error);
            }
            isLoading = false;
          });
    }

    return completer!.future;
  }

  void reset() {
    if (!isComplete && !isLoading) {
      completer?.completeError(CancelledException());
    }
    completer = null;
    isLoading = false;
  }
}

BorderRadius getItemBorderRadius(int index, int totalLength) {
  const defaultRadius = BorderRadius.zero;
  if (totalLength == 1) {
    return commonCustomBarRadius; // Only one item
  } else if (index == 0) {
    return commonCustomBarRadiusFirst; // First item
  } else if (index == totalLength - 1) {
    return commonCustomBarRadiusLast; // Last item
  }
  return defaultRadius; // Default for middle items
}

Locale getLocaleFromLanguageCode(String? languageCode) {
  // Early return for null case
  if (languageCode == null) {
    return const Locale('en');
  }

  // Handle codes with script parts
  if (languageCode.contains('-')) {
    final parts = languageCode.split('-');
    final baseLanguage = parts[0];
    final script = parts[1];

    // Try to find exact match with script
    for (final locale in appSupportedLocales) {
      if (locale.languageCode == baseLanguage && locale.scriptCode == script) {
        return locale;
      }
    }

    // Fall back to base language only
    return Locale(baseLanguage);
  }

  // Handle simple language codes
  for (final locale in appSupportedLocales) {
    if (locale.languageCode == languageCode) {
      return locale;
    }
  }

  // Default fallback
  return const Locale('en');
}

List<Map<String, dynamic>> safeConvert(dynamic input) {
  if (input is List) {
    return input
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }
  return [];
}

bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width > 480;

List<T> pickRandomItems<T>(List<T> items, int n, {int? seed}) {
  if (n >= items.length) {
    // Return fully shuffled list when n >= length
    return List<T>.from(items)
      ..shuffle(Random(seed ?? DateTime.now().millisecondsSinceEpoch));
  }

  // Otherwise return n random items
  final random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
  return (List<T>.from(items)..shuffle(random)).take(n).toList();
}

T pickRandomItem<T>(List<T> list) {
  if (list.isEmpty) {
    throw ArgumentError('List must not be empty');
  }
  final random = Random();
  return list[random.nextInt(list.length)];
}
