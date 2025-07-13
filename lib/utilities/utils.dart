import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:reverbio/extensions/common.dart';
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

  Future<T> runFuture(Future<T> future) async {
    if (!isLoading && !isComplete) {
      isLoading = true;
      completer = Completer<T>();

      await future
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

String sanitizeSongTitle(String title) {
  final wordsPatternForSongTitle = RegExp(
    //r'\b(?:official(?:\s(?:music|lyrics?|dtmf|audio|vi[sz]uali[sz]er|hd|4k)?\s*(?:video|dtmf|audio|vi[sz]uali[sz]er)?)|lyrics?(?:\s(?:music)?\s*(?:video|visuali[sz]er|vizuali[sz]er)))\b',
    r'(\bofficial\b|\bmusic\b|\blyrics?\b|\bdtmf\b|\bvideo\b|\baudio\b|\bvi[sz]uali[sz]er?\b|\bhd\b|\b4k\b|\bhigh\b|\bquality\b)+?',
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
    '  ': '-',
    '—': '-',
    '–': '-',
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

  return finalTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
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
  final formattedTitle = sanitizeSongTitle(title);
  final strings = sanitizeSongTitle(formattedTitle).split(RegExp('-|—|–'));
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

T? pickRandomItem<T>(List<T> list) {
  if (list.isEmpty) {
    return null;
  }
  final random = Random();
  return list[random.nextInt(list.length)];
}

bool isUrl(String input) {
  try {
    final uri = Uri.parse(input.trim());
    return uri.hasScheme &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'ftp' ||
            uri.scheme == 'ftps') &&
        uri.host.isNotEmpty;
  } catch (_) {
    return false;
  }
}

bool isFilePath(String input) {
  final path = input.trim();

  if (isUrl(input)) return false;

  final windowsDriveLetter = RegExp(r'^[a-zA-Z]:\\');
  if (windowsDriveLetter.hasMatch(path)) {
    return true;
  }

  if (path.startsWith('/')) {
    return true;
  }

  if (path.startsWith('file://')) {
    return true;
  }

  if (path.contains(Platform.pathSeparator)) {
    return true;
  }

  if (File(path).existsSync()) {
    return true;
  }

  return false;
}

Future<bool> doesFileExist(String path) async {
  try {
    final file = File(path);
    return await file.exists();
  } catch (e) {
    return false; // Invalid path or permissions issue
  }
}

Future<int> checkUrl(String url) async {
  try {
    if (isFilePath(url)) return (await doesFileExist(url)) ? 200 : 400;
    final response = await http.head(Uri.parse(url));
    return response.statusCode;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}', e, stackTrace);
    rethrow;
  }
}

String? tryEncode(data) {
  try {
    return jsonEncode(data);
  } catch (e) {
    return null;
  }
}

dynamic tryDecode(data) {
  try {
    return jsonDecode(data);
  } catch (e) {
    return null;
  }
}

DateTime tryParseDate(String date) {
  try {
    if (DateTime.tryParse(date) != null) return DateTime.parse(date);
    if (int.tryParse(date) != null) return DateTime(int.parse(date));
    return DateTime.now();
  } catch (e) {
    return DateTime.now();
  }
}

String removeDuplicates(String input, {int phraseLength = 1}) {
  // Matches words + adjacent punctuation
  final tokenPattern = RegExp(r"(([\p{L}\p{M}\w'-]+)([,.!?;:]|\s+)?)", unicode: true);
  final tokens = tokenPattern.allMatches(input).map((m) => m.group(0)!).toList();
  
  final seenPhrases = <String>{};
  final buffer = StringBuffer();
  var i = 0;

  while (i <= tokens.length - phraseLength) {
    final phraseTokens = tokens.sublist(i, i + phraseLength);
    final originalPhrase = phraseTokens.join();
    final normalizedPhrase = phraseTokens.join()
        .replaceAll(RegExp(r"[^\p{L}\p{M}\w'-]", unicode: true), '')
        .toLowerCase();

    if (normalizedPhrase.isNotEmpty && !seenPhrases.contains(normalizedPhrase)) {
      seenPhrases.add(normalizedPhrase);
      buffer.write(' $originalPhrase');
    }

    i += 1;
  }

  // Add remaining tokens
  while (i < tokens.length) {
    buffer.write(tokens[i]);
    i++;
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}