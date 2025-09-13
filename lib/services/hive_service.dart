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
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';

class HiveService {
  factory HiveService() => _instance;
  HiveService._internal();
  // Singleton instance
  static final HiveService _instance = HiveService._internal();

  // Isolate communication
  static late Isolate _isolate;

  // Box caching
  static final Map<String, Box> _openBoxes = {};
  static final Map<String, Completer<Box>> _openingBoxes = {};

  // Stream controllers for each category
  static final Map<String, StreamController<dynamic>> _streamControllers = {};

  // Box names and categories
  static const _boxNames = ['settings', 'user', 'userNoBackup', 'cache'];
  static final List<Map<String, dynamic>> _categories = [
    {'box': 'user', 'category': 'likedAlbums', 'default': []},
    {'box': 'cache', 'category': 'cachedAlbums', 'default': []},
    {'box': 'user', 'category': 'likedArtists', 'default': []},
    {'box': 'cache', 'category': 'cachedArtists', 'default': []},
    {'box': 'user', 'category': 'playlists', 'default': []},
    {'box': 'user', 'category': 'customPlaylists', 'default': []},
    {'box': 'user', 'category': 'offlinePlaylists', 'default': []},
    {'box': 'user', 'category': 'likedPlaylists', 'default': []},
    {'box': 'user', 'category': 'recentlyPlayedSongs', 'default': []},
    {'box': 'user', 'category': 'likedSongs', 'default': []},
    {'box': 'cache', 'category': 'cachedSongs', 'default': []},
    {'box': 'userNoBackup', 'category': 'offlineSongs', 'default': []},
    {'box': 'user', 'category': 'searchHistory', 'default': []},
    {'box': 'settings', 'category': 'pluginData', 'default': []},
    {
      'box': 'settings',
      'category': 'playNextSongAutomatically',
      'default': true,
    },
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
    {'box': 'settings', 'category': 'offlineDirectory', 'default': ''},
  ];

  static Stream<dynamic> get likedAlbumsStream =>
      streamFor('user', 'likedAlbums');

  static Stream<dynamic> get likedArtistsStream =>
      streamFor('user', 'likedArtists');

  static Stream<dynamic> get likedSongsStream =>
      streamFor('user', 'likedSongs');

  static Stream<dynamic> get playlistsStream => streamFor('user', 'playlists');

  static Stream<dynamic> get customPlaylistsStream =>
      streamFor('user', 'customPlaylists');

  static Stream<dynamic> get offlinePlaylistsStream =>
      streamFor('user', 'offlinePlaylists');

  static Stream<dynamic> get likedPlaylistsStream =>
      streamFor('user', 'likedPlaylists');

  static Stream<dynamic> get offlineSongsStream =>
      streamFor('userNoBackup', 'offlineSongs');

  // Preload commonly used boxes
  static Future<void> ensureInitialize() async {
    await Hive.initFlutter('reverbio');
    for (final box in _boxNames) {
      await _openBox(box);
    }
  }

  // Preload all categories with default values
  static Future<void> _preloadAllCategories() async {
    final List<Future> futures = [];

    for (final categoryConfig in _categories) {
      final category = categoryConfig['category'] as String;
      final box = categoryConfig['box'] as String;
      final defaultValue = categoryConfig['default'];
      futures.add(
        _ensureCategoryInitialized(
          box,
          category,
          defaultValue is Function ? await defaultValue() : defaultValue,
        ),
      );
    }

    await Future.wait(futures);
  }

  // Ensure category is initialized with default value
  static Future<void> _ensureCategoryInitialized(
    String boxName,
    String category,
    dynamic defaultValue,
  ) async {
    try {
      final box = _openBoxes[boxName] ?? await _openBox(boxName);
      if (!box.containsKey(category)) {
        await addOrUpdateData(boxName, category, defaultValue);
      }
      if (!_streamControllers.containsKey(category)) {}
      // Get value and add to stream (replaces _categoryCaches)
      final value = box.get(category, defaultValue: defaultValue);
      if (value is List) {
        for (final item in value) {
          _streamControllers[category]?.add(item);
        }
      } else {
        _streamControllers[category]?.add(value);
      }
    } catch (e, stackTrace) {
      logger.log('Error initializing category $category:', e, stackTrace);
    }
  }

  // Get stream for any category
  static Stream<dynamic> streamFor(String boxName, String category) {
    if (!_streamControllers.containsKey(category)) {
      // Create stream controller on-demand for dynamic categories
      _streamControllers[category] = StreamController<dynamic>.broadcast(
        onListen: () => _loadCategoryToCache(boxName, category),
      );
    }
    return _streamControllers[category]!.stream;
  }

  // Remove _categoryCaches and update getCategoryValue to use stream's last value
  static dynamic getCategoryValue(String boxName, String category) {
    final controller = _streamControllers[category];
    if (controller == null || !controller.hasListener) {
      _loadCategoryToCache(boxName, category);
    }

    return controller?.stream;
  }

  // Load category value into cache and notify stream
  static void _loadCategoryToCache(String boxName, String category) {
    try {
      final box = _openBoxes[boxName];
      if (box != null && box.isOpen) {
        final categoryConfig = _categories.firstWhere(
          (cat) => cat['category'] == category,
          orElse: () => {'default': null},
        );
        final defaultValue = categoryConfig['default'];
        final value = box.get(category, defaultValue: defaultValue);
        _streamControllers[category]?.add(value);
      }
    } catch (e, stackTrace) {
      logger.log('Error loading category $category to cache:', e, stackTrace);
    }
  }

  // Optimized box opening with caching
  static Future<Box> _openBox(String boxName) async {
    // Return cached open box
    if (_openBoxes.containsKey(boxName) && _openBoxes[boxName]!.isOpen) {
      return _openBoxes[boxName]!;
    }

    // Wait if box is currently being opened
    if (_openingBoxes.containsKey(boxName)) {
      return _openingBoxes[boxName]!.future;
    }

    // Open box with locking mechanism
    final completer = Completer<Box>();
    _openingBoxes[boxName] = completer;

    try {
      final box = await Hive.openBox(boxName);
      _openBoxes[boxName] = box;
      completer.complete(box);
      _openingBoxes.remove(boxName);
      return box;
    } catch (e) {
      completer.completeError(e);
      _openingBoxes.remove(boxName);
      rethrow;
    }
  }

  void close() async {
    await compactAllBoxes();
    await closeAllBoxes();
    await Hive.close();
    _isolate.kill();
  }

  // WRITE OPERATIONS (go to isolate)
  static Future<void> addOrUpdateData(
    String boxName,
    String key,
    dynamic value,
  ) async {
    final box = _openBoxes[boxName] ?? await _openBox(boxName);
    await box.put(key, value);
  }

  static Future<void> deleteData(String boxName, String key) async {
    final box = _openBoxes[boxName] ?? await _openBox(boxName);
    await box.delete(key);
  }

  static Future<void> clearBox(String boxName) async {
    final box = _openBoxes[boxName] ?? await _openBox(boxName);
    await box.clear();
  }

  static Future<void> compactBox(String boxName) async {
    final box = _openBoxes[boxName] ?? await _openBox(boxName);
    await box.compact();
  }

  static Future<void> compactAllBoxes() async {
    for (final box in _openBoxes.values) {
      if (box.isOpen) {
        await box.compact();
      }
    }
  }

  // Close all boxes (call on app termination)
  static Future<void> closeAllBoxes() async {
    for (final box in _openBoxes.values) {
      if (box.isOpen) {
        await box.close();
      }
    }
    _openBoxes.clear();
    _openingBoxes.clear();
  }

  // Optimized data reading
  static Future<dynamic> getData(
    String boxName,
    String key, {
    dynamic defaultValue,
    Duration cachingDuration = const Duration(days: 30),
  }) async {
    try {
      final box = await _openBox(boxName);

      if (boxName == 'cache') {
        final cacheIsValid = await _isCacheValid(box, key, cachingDuration);
        if (!cacheIsValid) {
          // Schedule deletion but don't wait for it
          unawaited(deleteData(boxName, key));
          unawaited(deleteData(boxName, '${key}_date'));
          return null;
        }
      }

      return box.get(key, defaultValue: defaultValue);
    } catch (e, stackTrace) {
      logger.log('Error reading data from $boxName/$key:', e, stackTrace);
      return defaultValue;
    }
  }

  // Cache validation
  static Future<bool> _isCacheValid(
    Box box,
    String key,
    Duration cachingDuration,
  ) async {
    try {
      final date = box.get('${key}_date');
      if (date == null) return false;

      final age = DateTime.now().difference(date);
      return age < cachingDuration;
    } catch (e) {
      return false;
    }
  }

  // Clear cache
  static Future<void> clearCache() async {
    await _openBoxes['cache']?.clear();
  }

  // Backup data with optimization
  static Future<String> backupData(BuildContext context) async {
    final boxNames = ['user', 'settings'];
    final dlPath = await FilePicker.platform.getDirectoryPath();

    if (dlPath == null) {
      return '${context.l10n!.chooseBackupDir}!';
    }

    try {
      for (final boxName in boxNames) {
        final box = await _openBox(boxName);
        final backupFile = File(
          '$dlPath${Platform.pathSeparator}$boxName.hive',
        );

        if (await backupFile.exists()) {
          await backupFile.delete();
        }

        // Compact before backup
        await box.compact();

        // Copy file directly
        final boxFile = File(box.path!);
        await boxFile.copy(backupFile.path);
      }
      return '${context.l10n!.backedupSuccess}!';
    } catch (e, stackTrace) {
      logger.log('Backup error:', e, stackTrace);
      return '${context.l10n!.backupError}: $e';
    }
  }

  // Restore data with optimization
  static Future<String> restoreData(BuildContext context) async {
    final boxNames = ['user', 'settings'];
    final backupFiles = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['hive'],
    );

    if (backupFiles == null || backupFiles.files.isEmpty) {
      return '${context.l10n!.chooseBackupFiles}!';
    }

    try {
      for (final boxName in boxNames) {
        final backupFile = backupFiles.files.firstWhere(
          (file) => file.name == '$boxName.hive',
          orElse: () => PlatformFile(name: '', size: 0),
        );

        if (backupFile.path != null && backupFile.size > 0) {
          final box = await _openBox(boxName);
          await box.close(); // Close before restoring

          // Copy backup file over existing box file
          final backup = File(backupFile.path!);
          final boxFile = File(box.path!);

          if (await boxFile.exists()) {
            await boxFile.delete();
          }

          await backup.copy(boxFile.path);

          // Reopen the box
          _openBoxes.remove(boxName);
          await _openBox(boxName);
        }
      }
      return '${context.l10n!.restoredSuccess}!';
    } catch (e, stackTrace) {
      logger.log('Restore error:', e, stackTrace);
      return '${context.l10n!.restoreError}: $e';
    }
  }

  // Get box statistics for debugging
  static Map<String, int> getBoxStats(String category) {
    final box = _openBoxes[category];
    if (box == null || !box.isOpen) return {};

    return {'keys': box.length, 'isOpen': box.isOpen ? 1 : 0};
  }
}
