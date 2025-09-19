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
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/screens/settings_page.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/style/reverbio_icons.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const androidDeviceTypes = {
  19: {'id': 'TYPE_AUX_LINE', 'name': 'AUX Line', 'include': true},
  30: {'id': 'TYPE_BLE_BROADCAST', 'name': 'BLE Broadcast', 'include': true},
  26: {'id': 'TYPE_BLE_HEADSET', 'name': 'BLE Headset', 'include': true},
  27: {'id': 'TYPE_BLE_SPEAKER', 'name': 'BLE Speaker', 'include': true},
  8: {'id': 'TYPE_BLUETOOTH_A2DP', 'name': 'Bluetooth A2DP', 'include': true},
  7: {'id': 'TYPE_BLUETOOTH_SCO', 'name': 'Bluetooth SCO', 'include': true},
  1: {
    'id': 'TYPE_BUILTIN_EARPIECE',
    'name': 'Built-in Earpiece',
    'include': false,
  },
  15: {'id': 'TYPE_BUILTIN_MIC', 'name': 'Built-in Mic', 'include': false},
  2: {
    'id': 'TYPE_BUILTIN_SPEAKER',
    'name': 'Built-in Speaker',
    'include': true,
  },
  24: {
    'id': 'TYPE_BUILTIN_SPEAKER_SAFE',
    'name': 'Built-in Speaker Safe',
    'include': false,
  },
  21: {'id': 'TYPE_BUS', 'name': 'BUS', 'include': true},
  13: {'id': 'TYPE_DOCK', 'name': 'Dock', 'include': true},
  31: {'id': 'TYPE_DOCK_ANALOG', 'name': 'Dock Analog', 'include': true},
  14: {'id': 'TYPE_FM', 'name': 'FM', 'include': true},
  16: {'id': 'TYPE_FM_TUNER', 'name': 'FM Tuner', 'include': true},
  9: {'id': 'TYPE_HDMI', 'name': 'HDMI', 'include': true},
  10: {'id': 'TYPE_HDMI_ARC', 'name': 'HDMI ARC', 'include': true},
  29: {'id': 'TYPE_HDMI_EARC', 'name': 'HDMI E-ARC', 'include': true},
  23: {'id': 'TYPE_HEARING_AID', 'name': 'Hearing Aid', 'include': true},
  20: {'id': 'TYPE_IP', 'name': 'IP', 'include': true},
  5: {'id': 'TYPE_LINE_ANALOG', 'name': 'Line Analog', 'include': true},
  6: {'id': 'TYPE_LINE_DIGITAL', 'name': 'Line Digital', 'include': true},
  32: {
    'id': 'TYPE_MULTICHANNEL_GROUP',
    'name': 'Multi-channel Group',
    'include': true,
  },
  25: {'id': 'TYPE_REMOTE_SUBMIX', 'name': 'Remote SubMix', 'include': true},
  18: {'id': 'TYPE_TELEPHONY', 'name': 'Telephony', 'include': false},
  17: {'id': 'TYPE_TV_TUNER', 'name': 'TV Tuner', 'include': true},
  0: {'id': 'TYPE_UNKNOWN', 'name': 'Unknown', 'include': true},
  12: {'id': 'TYPE_USB_ACCESSORY', 'name': 'USB Accessory', 'include': true},
  11: {'id': 'TYPE_USB_DEVICE', 'name': 'USB Device', 'include': true},
  22: {'id': 'TYPE_USB_HEADSET', 'name': 'USB Headset', 'include': true},
  4: {
    'id': 'TYPE_WIRED_HEADPHONES',
    'name': 'Wired Headphones',
    'include': true,
  },
  3: {'id': 'TYPE_WIRED_HEADSET', 'name': 'Wired Headset', 'include': true},
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

String getFormattedDateTimeNow() {
  return '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}T${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}';
}

String sanitizeSongTitle(String title) {
  var finalTitle = title.replaceAll(boundExtrasRegex, '');

  finalTitle =
      finalTitle.replaceAll(unboundExtrasRegex, '').isNotEmpty
          ? finalTitle.replaceAll(unboundExtrasRegex, '').sanitized
          : finalTitle.sanitized;

  return finalTitle.collapsed;
}

List<String> splitArtists(String input) {
  return input
      .split(artistSplitRegex)
      .where((artist) => artist.trim().isNotEmpty)
      .map((artist) => artist.sanitized)
      .toList();
}

Map<String, dynamic> tryParseTitleAndArtist(Video song) {
  final sdRx = RegExp(r'(^(?:\s*-\s*-*))|((?:\s*\-*)*\-\s*$)');
  //final mdRx = RegExp(r'(-(?:\s*-)+)');
  final musicData = song.musicData;
  final formattedTitle =
      sanitizeSongTitle(song.title).replaceAll(sdRx, '').collapsed;
  final cleanTitle =
      formattedTitle
          .replaceAll(separatorRegex, '')
          .replaceAll(sdRx, '')
          .collapsed;
  final strings =
      sanitizeSongTitle(
          formattedTitle,
        ).split(RegExp('-')).map((s) => s.sanitized).toList()
        ..removeWhere((e) => e.isEmpty);
  final artists = splitArtists(formattedTitle)..removeWhere((e) => e.isEmpty);
  final formattedAuthor = song.author.sanitized;
  final formattedArtist =
      artists.length != 1
          ? artists.join(', ')
          : artists.first == cleanTitle
          ? formattedAuthor
          : artists.first;
  if (strings.length > 2) {
    strings.removeWhere((value) => int.tryParse(value.trim()) != null);
  }
  if (musicData.isNotEmpty) {
    for (final data in musicData) {
      final videoExtras = boundExtrasRegex.firstMatch(data.song ?? song.title);
      final musicExtras = boundExtrasRegex.firstMatch(song.title);
      final extrasCheck =
          (videoExtras?[0] != null
              ? videoExtras![0]!.cleansed.toLowerCase()
              : null) ==
          (musicExtras?[0] != null
              ? musicExtras![0]!.cleansed.toLowerCase()
              : null);
      final title =
          extrasCheck
              ? (data.song ?? formattedTitle)
              : (data.song ?? formattedTitle).replaceAll(boundExtrasRegex, '');
      final artist = data.artist ?? formattedArtist;
      if (weightedRatio(title, formattedTitle) >= 90 &&
          weightedRatio(artist, formattedArtist) >= 90)
        return {
          'artist': data.artist ?? formattedArtist,
          'title': title,
          'musicData': [
            {'title': data.song, 'artist': data.artist, 'album': data.album},
          ],
        };
    }
  }
  final quoted = [
    ...singleQuotedRegEx.allMatches(song.title.sanitized),
    ...doubleQuotedRegEx.allMatches(song.title.sanitized),
  ];
  if (strings.length == 1 &&
      quoted.isNotEmpty &&
      quoted.length == 1 &&
      (quoted[0].namedGroup('value') != null ||
          quoted[0].namedGroup('value')!.isNotEmpty)) {
    final title = quoted[0].namedGroup('value')!;
    final artist =
        sanitizeSongTitle(song.title)
            .replaceAll(
              RegExp(quoted[0].namedGroup('value')!, caseSensitive: false),
              '',
            )
            .replaceAll(allSymbolsRegex, '')
            .collapsed;
    return {
      'title': title.replaceAll(sdRx, '').collapsed,
      'artist': artist.replaceAll(sdRx, ''),
      'musicData': musicData.map(
        (e) => {'title': e.song, 'artist': e.artist, 'album': e.album},
      ),
    };
  } else if (strings.length == 2 && quoted.isEmpty) {
    if (weightedRatio(strings.last, formattedAuthor) >= 50)
      return {
        'artist': strings.last.replaceAll(sdRx, '').collapsed,
        'title': strings.first.replaceAll(sdRx, '').collapsed.trim(),
        'musicData': musicData.map(
          (e) => {'title': e.song, 'artist': e.artist, 'album': e.album},
        ),
      };
    return {
      'title': strings.last.replaceAll(sdRx, '').collapsed.trim(),
      'artist': strings.first.replaceAll(sdRx, '').collapsed,
      'musicData': musicData.map(
        (e) => {'title': e.song, 'artist': e.artist, 'album': e.album},
      ),
    };
  } else {
    if (quoted.isNotEmpty) {
      final title = quoted[0].namedGroup('value')!;
      final truncatedTitle =
          formattedTitle.replaceFirstSubsequence(title).collapsed;
      final artist =
          '$truncatedTitle - $formattedAuthor'.collapsed
              .split(RegExp('-'))
              .map(
                (e) =>
                    e
                        .replaceAll(allSymbolsRegex, '')
                        .replaceAll(sdRx, '')
                        .collapsed,
              )
              .toSet()
            ..removeWhere((e) => e.isEmpty);
      return {
        'title': title.replaceAll(sdRx, '').collapsed,
        'artist': artist.join(', '),
        'musicData': musicData.map(
          (e) => {'title': e.song, 'artist': e.artist, 'album': e.album},
        ),
      };
    } else {
      final truncatedTitle = cleanTitle.replaceFirstSubsequence(
        formattedArtist,
      );
      return {
        'title':
            truncatedTitle.isNotEmpty
                ? truncatedTitle.replaceAll(sdRx, '').collapsed
                : formattedTitle.replaceAll(sdRx, '').collapsed,
        'artist': formattedArtist,
        'musicData': musicData.map(
          (e) => {'title': e.song, 'artist': e.artist, 'album': e.album},
        ),
      };
    }
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
  try {
    final schema = Uri.file(input).scheme;
    return schema == 'file';
  } catch (_) {
    return false;
  }
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
  } catch (_) {
    return 400;
  }
}

String? tryEncode(object) {
  try {
    final seen = <Object?>{};

    return jsonEncode(
      object,
      toEncodable: (value) {
        if (value != null && (value is Map || value is Iterable)) {
          if (seen.contains(value)) {
            return null;
          }
          seen.add(value);
        }
        return value;
      },
    );
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

DateTime tryParseDate(String? date) {
  try {
    if (date == null) return DateTime.now();
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

  return buffer.toString().collapsed;
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
    '.mp4',
    '.oga',
    '.ogg',
    '.oma',
    '.tta',
    '.wav',
    '.wsaud',
    '.webm',
    '.weba',
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
    if (obj == null) return null;
    if (obj['validImage'] != null) {
      if (isFilePath(obj['validImage']))
        return Uri.file(obj['validImage']);
      else if (await checkUrl(obj['validImage'].toString()) <= 300)
        return Uri.parse(obj['validImage']);
    }
    final images = parseImage(obj) ?? [];
    if (images.isEmpty) return null;
    for (final path in images) {
      if (isFilePath(path) && doesFileExist(path)) {
        obj['validImage'] = path;
        await cacheEntity(obj);
        return Uri.file(path);
      } else {
        final imageUrl = Uri.parse(path);
        if (await checkUrl(imageUrl.toString()) <= 300) {
          obj['validImage'] = imageUrl.toString();
          await cacheEntity(obj);
          return imageUrl;
        }
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

String joinIfNotEmpty(List<String?> strings, String separator) {
  return [
    for (final s in strings)
      if (s != null && s.trim().isNotEmpty) s,
  ].join(separator);
}

List<String> splitLatinNonLatin(String text) {
  // Matches sequences of Latin characters
  final latinPattern = RegExp(
    r'[\u0000-\u007F\u0080-\u00FF\u0100-\u017F\u0180-\u024F\u1E00-\u1EFF]+',
  );

  // Matches sequences of non-Latin characters
  final nonLatinPattern = RegExp(
    r'[^\u0000-\u007F\u0080-\u00FF\u0100-\u017F\u0180-\u024F\u1E00-\u1EFF]+',
  );

  final List<String> result = [];
  int index = 0;

  while (index < text.length) {
    // Try to match Latin characters first
    final latinMatch = latinPattern.matchAsPrefix(text, index);
    if (latinMatch != null) {
      result.add(latinMatch.group(0)!);
      index = latinMatch.end;
      continue;
    }

    // Then try to match non-Latin characters
    final nonLatinMatch = nonLatinPattern.matchAsPrefix(text, index);
    if (nonLatinMatch != null) {
      result.add(nonLatinMatch.group(0)!);
      index = nonLatinMatch.end;
      continue;
    }

    // If neither matches (shouldn't happen), advance by one character
    index++;
  }

  return result;
}

String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference =
      dateTime.isAfter(now)
          ? dateTime.difference(now)
          : now.difference(dateTime);

  final suffix = dateTime.isAfter(now) ? '' : '';

  if (difference.inSeconds < 60) {
    return '${difference.inSeconds}s$suffix';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m$suffix';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h$suffix';
  } else if (difference.inDays < 30) {
    return '${difference.inDays}d$suffix';
  } else if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return '${months}mo$suffix';
  } else {
    final years = (difference.inDays / 365).floor();
    return '${years}y$suffix';
  }
}

/// Check if a and b are within a certain percentage of each other,
/// where percentage is provided as a whole number (ex. 15 for 15%).
bool withinPercent(double a, double b, double percentage) {
  if (a == b && b == 0) return true;
  final maxVal = max(a.abs(), b.abs());
  return (a - b).abs() / maxVal <= percentage / 100;
}

Map<String, dynamic> copyMap(Map<dynamic, dynamic>? original) {
  final Map<String, dynamic> copy = {};
  try {
    if (original == null) return copy;
    for (final key in original.keys) {
      final String stringKey = key.toString();
      final value = original[key];

      if (value == null) {
        copy[stringKey] = null;
      } else if (value is Map<dynamic, dynamic>) {
        copy[stringKey] = copyMap(value);
      } else if (value is List) {
        copy[stringKey] = _deepCopyList(value);
      } else if (value is DateTime) {
        copy[stringKey] = DateTime.fromMillisecondsSinceEpoch(
          value.millisecondsSinceEpoch,
        );
      } else if (value is Set) {
        copy[stringKey] = Set.from(value.map(_deepCopyValue));
      } else if (value is num || value is bool || value is String) {
        copy[stringKey] = value; // Primitive types are immutable
      } else {
        // For custom objects, use toString() or handle as needed
        copy[stringKey] = value.toString();
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}', e, stackTrace);
    throw FormatException('Error copying map. $e', stackTrace);
  }
  return copy;
}

dynamic _deepCopyList(List<dynamic> original) {
  return original.map((item) {
    if (item == null) return null;
    if (item is Map<dynamic, dynamic>) return copyMap(item);
    if (item is List) return _deepCopyList(item);
    if (item is DateTime)
      return DateTime.fromMillisecondsSinceEpoch(item.millisecondsSinceEpoch);
    if (item is Set) return Set.from(item.map(_deepCopyValue));
    if (item is num || item is bool || item is String) return item;
    return item.toString(); // Fallback for custom objects
  }).toList();
}

dynamic _deepCopyValue(dynamic value) {
  if (value == null) return null;
  if (value is Map<dynamic, dynamic>) return copyMap(value);
  if (value is List) return _deepCopyList(value);
  if (value is DateTime)
    return DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);
  if (value is Set) return Set.from(value.map(_deepCopyValue));
  if (value is num || value is bool || value is String) return value;
  return value.toString(); // Fallback for custom objects
}

Future<void> checkInternetConnection() async {
  final context = NavigationManager().context;
  try {
    Future<bool> testConnection() async {
      try {
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('https://www.google.com/generate_204'),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 5),
        );
        client.close();
        return response.statusCode == 204 || response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }

    if (!(await testConnection()) && !offlineMode.value)
      await showDialog(
        barrierDismissible: false,
        requestFocus: true,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(context.l10n!.noInternet),
            content: Text(context.l10n!.noInternetMessage),
            actions: [
              TextButton(
                child: Text(context.l10n!.retry.toUpperCase()),
                onPressed: () {
                  unawaited(checkInternetConnection());
                  context.pop();
                },
              ),
              TextButton(
                child: Text(context.l10n!.offlineMode.toUpperCase()),
                onPressed: () async {
                  await toggleOfflineMode(context, true);
                },
              ),
            ],
          );
        },
      );
  } catch (_) {}
}

String getFileExtension(String filePath) {
  return RegExp(r'(\.[^\.]+$)').firstMatch(filePath)?.group(1) ?? '';
}

String getExtensionFromMime(String? mimeType) {
  if (mimeType == null) return 'bin';

  final extensions = {
    'image/jpg': 'jpg',
    'image/png': 'png',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'image/bmp': 'bmp',
    'image/x-icon': 'ico',
    'audio/weba': 'webm',
    'audio/webm': 'webm',
  };

  final extension =
      extensionFromMime(mimeType) ??
      extensions[mimeType.toLowerCase()] ??
      'bin';

  return '.$extension';
}

String? getMimeTypeFromFile(String filePath) {
  try {
    final file = File(filePath);
    final raf = file.openSync();

    try {
      const bytesToRead = 128;
      final buffer = List<int>.filled(bytesToRead, 0);
      final bytesRead = raf.readIntoSync(buffer, 0, bytesToRead);

      final headerBytes =
          bytesRead < bytesToRead ? buffer.sublist(0, bytesRead) : buffer;

      return lookupMimeType(file.path, headerBytes: headerBytes);
    } finally {
      raf.closeSync();
    }
  } catch (e) {
    return null;
  }
}

Locale parseLocale(String languageCode) {
  final parts = languageCode.split('-');
  if (parts.length > 1) {
    return Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]);
  }
  return Locale(languageCode);
}
