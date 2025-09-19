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

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';

const List<Map<String, dynamic>> _categories = [
  {'box': 'user', 'category': 'likedAlbums', 'default': []},
  {'box': 'user', 'category': 'likedArtists', 'default': []},
  {'box': 'user', 'category': 'likedSongs', 'default': []},
  {'box': 'user', 'category': 'likedPlaylists', 'default': []},
  {'box': 'user', 'category': 'playlists', 'default': []},
  {'box': 'user', 'category': 'customPlaylists', 'default': []},
  {'box': 'user', 'category': 'offlinePlaylists', 'default': []},
  {'box': 'cache', 'category': 'cachedAlbums', 'default': []},
  {'box': 'cache', 'category': 'cachedArtists', 'default': []},
  {'box': 'cache', 'category': 'cachedSongs', 'default': []},
  {'box': 'userNoBackup', 'category': 'offlineSongs', 'default': []},
  {'box': 'userNoBackup', 'category': 'recentlyPlayedSongs', 'default': []},
  {'box': 'userNoBackup', 'category': 'searchHistory', 'default': []},
  {'box': 'settings', 'category': 'pluginData', 'default': []},
  {'box': 'settings', 'category': 'playNextSongAutomatically', 'default': true},
  {'box': 'settings', 'category': 'useSystemColor', 'default': true},
  {'box': 'settings', 'category': 'usePureBlackColor', 'default': false},
  {'box': 'settings', 'category': 'offlineMode', 'default': false},
  {'box': 'settings', 'category': 'predictiveBack', 'default': false},
  {'box': 'settings', 'category': 'sponsorBlockSupport', 'default': true},
  {'box': 'settings', 'category': 'skipNonMusic', 'default': true},
  {'box': 'settings', 'category': 'audioQuality', 'default': 'high'},
  {'box': 'settings', 'category': 'pluginsSupport', 'default': false},
  {'box': 'settings', 'category': 'language', 'default': 'English'},
  {'box': 'settings', 'category': 'themeMode', 'default': 'dark'},
  {'box': 'settings', 'category': 'accentColor', 'default': 0xff91cef4},
  {'box': 'settings', 'category': 'volume', 'default': 100},
  {'box': 'settings', 'category': 'prepareNextSong', 'default': true},
  {'box': 'settings', 'category': 'useProxies', 'default': true},
  {'box': 'settings', 'category': 'autoCacheOffline', 'default': false},
  {'box': 'settings', 'category': 'postUpdateRun', 'default': {}},
  {'box': 'settings', 'category': 'streamRequestTimeout', 'default': 30},
  {'box': 'settings', 'category': 'audioDevice', 'default': null},
  {
    'box': 'settings',
    'category': 'offlineDirectory',
    'default': getApplicationSupportDirectory,
  },
];

Future<void> addOrUpdateData(String category, String key, dynamic value) async {
  try {
    final _box = await _openBox(category);
    if (category == 'cache') {
      await _box.put('${key}_date', DateTime.now());
    }
    await _box.put(key, value);
  } catch (e, stackTrace) {
    logger.log(
      'Error in ${stackTrace.getCurrentMethodName()} writing $category, $key:',
      e,
      stackTrace,
    );
  }
}

Future getData(
  String category,
  String key, {
  dynamic defaultValue,
  Duration cachingDuration = const Duration(days: 30),
}) async {
  final _box = await _openBox(category);
  if (category == 'cache') {
    final cacheIsValid = await isCacheValid(_box, key, cachingDuration);
    if (!cacheIsValid) {
      deleteData(category, key);
      return null;
    }
  }
  return await _box.get(key, defaultValue: defaultValue);
}

void deleteData(String category, String key) async {
  final _box = await _openBox(category);
  await _box.delete(key);
}

Future<void> clearCache() async {
  final _cacheBox = await _openBox('cache');
  await _cacheBox.clear();
}

Future<bool> isCacheValid(Box box, String key, Duration cachingDuration) async {
  final date = box.get('${key}_date');
  if (date == null) {
    return false;
  }
  final age = DateTime.now().difference(date);
  return age < cachingDuration;
}

Future<Box> _openBox(String category) async {
  if (Hive.isBoxOpen(category)) {
    return Hive.box(category);
  } else {
    return Hive.openBox(category);
  }
}

Future<String> backupData(BuildContext context) async {
  final boxNames = ['user', 'settings'];
  final dlPath = await FilePicker.platform.getDirectoryPath();

  if (dlPath == null) {
    return '${context.l10n!.chooseBackupDir}!';
  }

  try {
    for (final boxName in boxNames) {
      final sourceFile = File('$dlPath/$boxName.hive');
      final box = await _openBox(boxName);

      if (await sourceFile.exists()) {
        await sourceFile.delete();
      }

      await box.compact();
      await File(box.path!).copy(sourceFile.path);
    }
    return '${context.l10n!.backedupSuccess}!';
  } catch (e, stackTrace) {
    return '${context.l10n!.backupError}: $e\n$stackTrace';
  }
}

Future<String> restoreData(BuildContext context) async {
  final boxNames = ['user', 'settings'];
  final backupFiles = await FilePicker.platform.pickFiles(allowMultiple: true);

  if (backupFiles == null || backupFiles.files.isEmpty) {
    return '${context.l10n!.chooseBackupFiles}!';
  }

  try {
    for (final boxName in boxNames) {
      final _file = backupFiles.files.firstWhere(
        (file) => file.name == '$boxName.hive',
        orElse:
            () => PlatformFile(
              name: '',
              size: 0,
            ), // Create a PlatformFile with null path if not found
      );

      if (_file.path != null && _file.path!.isNotEmpty && _file.size != 0) {
        final sourceFilePath = _file.path!;
        final sourceFile = File(sourceFilePath);

        final box = await _openBox(boxName);
        final boxPath = box.path;
        await box.close();

        if (boxPath != null) {
          await sourceFile.copy(boxPath);
        }
      } else {
        logger.log(
          'Source file for $boxName not found while restoring data.',
          null,
          null,
        );
      }
    }

    return '${context.l10n!.restoredSuccess}!';
  } catch (e, stackTrace) {
    logger.log('${context.l10n!.restoreError}:', e, stackTrace);
    return '${context.l10n!.restoreError}: $e\n$stackTrace';
  }
}
