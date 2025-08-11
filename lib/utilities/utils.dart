import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/style/reverbio_icons.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const androidDeviceTypes = {
  19: {'id': 'TYPE_AUX_LINE', 'name': 'AUX Line'},
  30: {'id': 'TYPE_BLE_BROADCAST', 'name': 'BLE Broadcast'},
  26: {'id': 'TYPE_BLE_HEADSET', 'name': 'BLE Headset'},
  27: {'id': 'TYPE_BLE_SPEAKER', 'name': 'BLE Speaker'},
  8: {'id': 'TYPE_BLUETOOTH_A2DP', 'name': 'Bluetooth A2DP'},
  7: {'id': 'TYPE_BLUETOOTH_SCO', 'name': 'Bluetooth SCO'},
  1: {'id': 'TYPE_BUILTIN_EARPIECE', 'name': 'Built-in Earpiece'},
  15: {'id': 'TYPE_BUILTIN_MIC', 'name': 'Built-in Mic'},
  2: {'id': 'TYPE_BUILTIN_SPEAKER', 'name': 'Built-in Speaker'},
  24: {'id': 'TYPE_BUILTIN_SPEAKER_SAFE', 'name': 'Built-in Speaker Safe'},
  21: {'id': 'TYPE_BUS', 'name': 'BUS'},
  13: {'id': 'TYPE_DOCK', 'name': 'Dock'},
  31: {'id': 'TYPE_DOCK_ANALOG', 'name': 'Dock Analog'},
  14: {'id': 'TYPE_FM', 'name': 'FM'},
  16: {'id': 'TYPE_FM_TUNER', 'name': 'FM Tuner'},
  9: {'id': 'TYPE_HDMI', 'name': 'HDMI'},
  10: {'id': 'TYPE_HDMI_ARC', 'name': 'HDMI ARC'},
  29: {'id': 'TYPE_HDMI_EARC', 'name': 'HDMI E-ARC'},
  23: {'id': 'TYPE_HEARING_AID', 'name': 'Hearing Aid'},
  20: {'id': 'TYPE_IP', 'name': 'IP'},
  5: {'id': 'TYPE_LINE_ANALOG', 'name': 'Line Analog'},
  6: {'id': 'TYPE_LINE_DIGITAL', 'name': 'Line Digital'},
  32: {'id': 'TYPE_MULTICHANNEL_GROUP', 'name': 'Multi-channel Group'},
  25: {'id': 'TYPE_REMOTE_SUBMIX', 'name': 'Remote SubMix'},
  18: {'id': 'TYPE_TELEPHONY', 'name': 'Telephony'},
  17: {'id': 'TYPE_TV_TUNER', 'name': 'TV Tuner'},
  0: {'id': 'TYPE_UNKNOWN', 'name': 'Unknown'},
  12: {'id': 'TYPE_USB_ACCESSORY', 'name': 'USB Accessory'},
  11: {'id': 'TYPE_USB_DEVICE', 'name': 'USB Device'},
  22: {'id': 'TYPE_USB_HEADSET', 'name': 'USB Headset'},
  4: {'id': 'TYPE_WIRED_HEADPHONES', 'name': 'Wired Headphones'},
  3: {'id': 'TYPE_WIRED_HEADSET', 'name': 'Wired Headset'},
};

Map getAudioDeviceCategory(String category, {BuildContext? context}) {
  context = context ?? NavigationManager().context;
  final categoryOrder = <String, dynamic>{
    'Android Auto': {
      'order': 1,
      'localization': context.l10n!.androidAuto,
      'icon': ReverbioIcons.android_auto_monochrome,
    },
    'Car Audio': {
      'order': 2,
      'localization': context.l10n!.carAudio,
      'icon': FluentIcons.vehicle_car_24_filled,
    },
    'Bluetooth': {
      'order': 3,
      'localization': context.l10n!.bluetooth,
      'icon': FluentIcons.bluetooth_24_filled,
    },
    'AUX': {
      'order': 4,
      'localization': context.l10n!.aux,
      'icon': FluentIcons.connector_24_filled,
    },
    'Radio': {
      'order': 5,
      'localization': context.l10n!.radio,
      'icon': Icons.radio,
    },
    'Hearing Aid': {
      'order': 6,
      'localization': context.l10n!.hearingAid,
      'icon': Icons.hearing,
    },
    'Wired Headphones': {
      'order': 7,
      'localization': context.l10n!.wiredHeadphones,
      'icon': FluentIcons.headphones_24_filled,
    },
    'USB Audio': {
      'order': 8,
      'localization': context.l10n!.usbAudio,
      'icon': FluentIcons.speaker_usb_24_filled,
    },
    'Docking Station': {
      'order': 9,
      'localization': context.l10n!.dockingStation,
      'icon': FluentIcons.dock_24_filled,
    },
    'Phone Speaker': {
      'order': 10,
      'localization': context.l10n!.phoneSpeaker,
      'icon': FluentIcons.speaker_2_24_filled,
    },
    'Phone Earpiece': {
      'order': 11,
      'localization': context.l10n!.phoneEarpiece,
      'icon': FluentIcons.call_24_filled,
    },
    'HDMI': {
      'order': 12,
      'localization': context.l10n!.hdmi,
      'icon': FluentIcons.tv_usb_24_filled,
    },
    'Other': {
      'order': 13,
      'localization': context.l10n!.other,
      'icon': FluentIcons.speaker_box_24_filled,
    },
  };

  return categoryOrder[category];
}

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
    //r'\b(?:official(?:\s(?:music|lyrics?|audio|vi[sz]uali[sz]er|hd|4k)?\s*(?:video|audio|vi[sz]uali[sz]er)?)|lyrics?(?:\s(?:music)?\s*(?:video|visuali[sz]er|vizuali[sz]er)))\b',
    r'(\bofficial\b|\bmusic\b|\blyrics?\b|\bvideo\b|\baudio\b|\bvi[sz]uali[sz]er?\b|\bhd\b|\b4k\b|\bhigh\b|\bquality\b)+?',
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
    '“': '"',
    '”': '"',
    '‘': "'",
    '’': "'",
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
      .map(
        (artist) =>
            artist
                .replaceAll(specialRegex, '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim(),
      )
      .toList();
}

Map<String, String> tryParseTitleAndArtist(dynamic song) {
  final title = song is Video ? song.title : song;
  final formattedTitle = sanitizeSongTitle(title);
  final strings = sanitizeSongTitle(formattedTitle).split(RegExp('-|—|–'));
  final artists = splitArtists(formattedTitle);
  if (strings.length > 2) {
    strings.removeWhere((value) => int.tryParse(value.trim()) != null);
  }
  if (strings.length == 2) {
    if (song is Video &&
        strings.last.trim().contains(sanitizeSongTitle(song.author)))
      return {'artist': strings.last.trim(), 'title': strings.first.trim()};
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

bool isLargeScreen({BuildContext? context}) {
  context = context ?? NavigationManager().context;
  return MediaQuery.of(context).size.height <
          MediaQuery.of(context).size.width ||
      MediaQuery.of(context).size.width > 540;
}

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

  return false;
}

bool doesFileExist(String path) {
  try {
    final file = File(path);
    return file.existsSync();
  } catch (e) {
    return false; // Invalid path or permissions issue
  }
}

Future<int> checkUrl(String url) async {
  try {
    if (isFilePath(url)) return (doesFileExist(url)) ? 200 : 400;
    final response = await http.head(Uri.parse(url));
    if (response.statusCode == 403 && Uri.parse(url).host == 'youtube.com') {
      showToast(NavigationManager().context.l10n!.youtubeInaccessible);
      logger.log('Forbidden error trying to play YouTube Stream', {
        'message': response.body,
        'status': response.statusCode,
      }, null);
    }
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
  final tokenPattern = RegExp(
    r"(([\p{L}\p{M}\w'-]+)([,.!?;:]|\s+)?)",
    unicode: true,
  );
  final tokens =
      tokenPattern.allMatches(input).map((m) => m.group(0)!).toList();

  final seenPhrases = <String>{};
  final buffer = StringBuffer();
  var i = 0;

  while (i <= tokens.length - phraseLength) {
    final phraseTokens = tokens.sublist(i, i + phraseLength);
    final originalPhrase = phraseTokens.join();
    final normalizedPhrase =
        phraseTokens
            .join()
            .replaceAll(RegExp(r"[^\p{L}\p{M}\w'-]", unicode: true), '')
            .toLowerCase();

    if (normalizedPhrase.isNotEmpty &&
        !seenPhrases.contains(normalizedPhrase)) {
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

bool isImage(String path) {
  const imageExtensions = ['.jpeg', '.jpg', '.png', '.gif', '.webp', '.bmp'];
  return imageExtensions.contains(extension(path));
}

bool isAudio(String path) {
  const audioExtensions = [
    '.aac',
    '.adts',
    '.aif',
    '.aiff',
    '.aptx',
    '.aptx_hd',
    '.ast',
    '.avi',
    '.caf',
    '.cavsvideo',
    '.daud',
    '.flac',
    '.mp2',
    '.mp3',
    '.m4a',
    '.oga',
    '.ogg',
    '.oma',
    '.tta',
    '.wav',
    '.wsaud',
  ];
  return audioExtensions.contains(extension(path));
}

Set<String> _parseMapForImage(Map map, Set<String> images) {
  for (final key in map.keys) {
    if (map[key] is String && isImage(map[key]))
      images.add(map[key]);
    else if (map[key] is List) {
      final res = _parseListForImage(map[key], images);
      images.addAll(res);
    } else if (map[key] is Map) {
      final res = _parseMapForImage(map[key], images);
      images.addAll(res);
    }
  }
  return images;
}

Set<String> _parseListForImage(List list, Set<String> images) {
  for (final item in list) {
    if (item is String && (isUrl(item) || isFilePath(item)))
      images.add(item);
    else if (item is Map) {
      final res = _parseMapForImage(item, images);
      images.addAll(res);
    } else if (item is List) {
      final res = _parseListForImage(item, images);
      images.addAll(res);
    }
  }
  return images;
}

List<String> _parseImagePath(dynamic obj) {
  final images = <String>{};
  if (obj is String && (isUrl(obj) || isFilePath(obj))) images.add(obj);
  if (obj is Map) {
    final res = _parseMapForImage(obj, images);
    images.addAll(res);
  }
  if (obj is List) {
    final res = _parseListForImage(obj, images);
    images.addAll(res);
  }
  return images.toList();
}

List<String>? parseImage(dynamic obj) {
  final images = <String>{};
  if (obj == null) return null;
  if (obj is Map && obj['offlineArtworkPath'] != null) {
    if (obj['offlineArtworkPath'] is String)
      images.add(obj['offlineArtworkPath']);
    else if (obj['offlineArtworkPath'] is Map ||
        obj['offlineArtworkPath'] is List) {
      final res = _parseImagePath(obj['offlineArtworkPath']);
      images.addAll(res);
    }
  }
  if (obj is Map && obj['image'] != null) {
    if (obj['image'] is String && obj['image'].isNotEmpty)
      images.add(obj['image']);
    else if (obj['image'] is Map || obj['image'] is List) {
      final res = _parseImagePath(obj['image']);
      images.addAll(res);
    }
  }
  if (obj is Map && obj['images'] != null) {
    if (obj['images'] is String)
      images.add(obj['images']);
    else if (obj['images'] is Map || obj['images'] is List) {
      final res = _parseImagePath(obj['images']);
      images.addAll(res);
    }
  }
  if (obj is Map && obj['highResImage'] != null) {
    if (obj['highResImage'] is String)
      images.add(obj['highResImage']);
    else if (obj['highResImage'] is Map || obj['highResImage'] is List) {
      final res = _parseImagePath(obj['highResImage']);
      images.addAll(res);
    }
  }
  if (obj is Map && obj['lowResImage'] != null) {
    if (obj['lowResImage'] is String)
      images.add(obj['lowResImage']);
    else if (obj['lowResImage'] is Map || obj['lowResImage'] is List) {
      final res = _parseImagePath(obj['lowResImage']);
      images.addAll(res);
    }
  }
  if (obj is Map &&
      obj['discogs'] != null &&
      obj['discogs'] is Map &&
      obj['discogs']['images'] != null) {
    final res = _parseImagePath(obj['discogs']['images']);
    images.addAll(res);
  }
  if (obj is Map && obj['youtube'] != null && obj['youtube'] is Map) {
    if (obj['youtube']['logoUrl'] != null &&
        obj['youtube']['logoUrl'].isNotEmpty)
      images.add(obj['youtube']['logoUrl']);
    if (obj['youtube']['bannerUrl'] != null &&
        obj['youtube']['bannerUrl'].isNotEmpty)
      images.add(obj['youtube']['bannerUrl']);
  }
  return images.isNotEmpty ? images.toList() : null;
}

Future<Uri?> getValidImage(dynamic obj) async {
  try {
    final images = parseImage(obj) ?? [];
    if (images.isEmpty) return null;
    for (final path in images) {
      if (isFilePath(path) && doesFileExist(path))
        return Uri.file(path);
      else {
        final imageUrl = Uri.parse(path);
        if (await checkUrl(imageUrl.toString()) <= 300) return imageUrl;
      }
    }
    return null;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}', e, stackTrace);
  }
  return null;
}

int? parseTimeStringToSeconds(String timeString) {
  if (!timeString.contains(':') && int.tryParse(timeString) == null)
    return null;
  final parts =
      timeString
          .split(':')
          .reversed
          .toList(); // Reverse to [seconds, minutes, hours]
  if (parts.isEmpty || parts.length > 3) {
    return null;
  }

  int seconds = 0;
  for (int i = 0; i < parts.length; i++) {
    final value = int.tryParse(parts[i]) ?? 0;
    seconds +=
        value *
        (i == 0
            ? 1
            : i == 1
            ? 60
            : 3600);
  }
  return seconds;
}

Duration? tryParseDuration(String timeString) {
  final seconds = parseTimeStringToSeconds(timeString);
  if (seconds == null) return null;
  return Duration(seconds: seconds);
}

String stableHash(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}

bool isMobilePlatform() {
  return Platform.isAndroid || Platform.isIOS;
}
