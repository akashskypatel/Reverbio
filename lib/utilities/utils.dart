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

String getFormattedDateTimeNow() {
  return '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}T${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}';
}

String formatSongTitle(String title) {
  final wordsPatternForSongTitle = RegExp(
    r'\b(?:official(?:\s(?:music|lyrics?|audio|visuali[sz]er|vizuali[sz]er|hd|4k)?\s*(?:video|audio|visuali[sz]er|vizuali[sz]er)?)|lyrics?(?:\s(?:music)?\s*(?:video|visuali[sz]er|vizuali[sz]er)))\b',
    caseSensitive: false,
  );

  final replacementsForSongTitle = {
    '[': '',
    ']': '',
    '(': '',
    ')': '',
    '|': '',
    '&amp;': '&',
    '&#039;': "'",
    '&quot;': '"',
  };
  final pattern = RegExp(
    replacementsForSongTitle.keys.map(RegExp.escape).join('|'),
  );

  var finalTitle =
      title
          .replaceAllMapped(
            pattern,
            (match) => replacementsForSongTitle[match.group(0)] ?? '',
          )
          .trimLeft();

  finalTitle = finalTitle.replaceAll(wordsPatternForSongTitle, '');

  return finalTitle;
}

List<String> splitArtists(String input) {
  final artistSplitRegex = RegExp(
    r'''(?:\s*(?:,\s*|\s+&\s+|\s+(?:and|with|ft(?:\.)|feat(?:\.|uring)?)\s+|\s*\/\s*|\s*\\\s*|\s*\+\s*|\s*;\s*|\s*[|]\s*|\s* vs(?:\.)?\s*|\s* x\s*|\s*,\s*(?:and|&)\s*)(?![^()]*\)))''',
    caseSensitive: false,
  );
  return input
      .split(artistSplitRegex)
      .where((artist) => artist.trim().isNotEmpty)
      .map((artist) => artist.trim())
      .toList();
}

Map<String, String> tryParseTitleAndArtist(String title) {
  final formattedTitle = formatSongTitle(title);
  final strings = formatSongTitle(formattedTitle).split('-');
  final artists = splitArtists(formattedTitle);
  if (strings.length > 2) {
    strings.removeWhere((value) => int.tryParse(value.trim()) != null);
  }
  if (strings.length == 2) {
    return {'title': strings.last.trim(), 'artist': strings.first.trim()};
  } else {
    return {
      'title': formattedTitle,
      'artist': artists.isNotEmpty ? artists.join(', ') : formattedTitle,
    };
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
