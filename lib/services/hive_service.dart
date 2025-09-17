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

  // Box names and categories
  static const _boxNames = ['settings', 'user', 'userNoBackup', 'cache'];

  static Future<void> ensureInitialize() async {
    await Hive.initFlutter('reverbio');
    for (final box in _boxNames) {
      await _openBox(box);
    }
  }

  static dynamic getCategoryValue(String boxName, String category) async {
    final _box = await _openBox(boxName);
    final value = _box.get(category);
    if (value is List) {
      if (value is List<String>) return List<String>.from(value);
      if (value is List<Map>)
        try {
          return value.map(Map<String, dynamic>.from).toList();
        } catch (_) {
          return value.map(Map<dynamic, dynamic>.from).toList();
        }
    }
    return value;
  }

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

  static Future<void> addOrUpdateData(
    String boxName,
    String category,
    dynamic value,
  ) async {
    final box = _openBoxes[boxName] ?? await _openBox(boxName);
    await box.put(category, value);
    if (category == 'cache') {
      await box.put('${category}_date', DateTime.now());
    }
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

  static Future<void> closeAllBoxes() async {
    for (final box in _openBoxes.values) {
      if (box.isOpen) {
        await box.close();
      }
    }
    _openBoxes.clear();
    _openingBoxes.clear();
  }

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

  static Future<bool> _isCacheValid(
    Box box,
    String key,
    Duration cachingDuration,
  ) async {
    final date = box.get('${key}_date');
    if (date == null) {
      return false;
    }
    final age = DateTime.now().difference(date);
    return age < cachingDuration;
  }

  static Future<void> clearCache() async {
    await _openBoxes['cache']?.clear();
  }

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

  static Map<String, int> getBoxStats(String category) {
    final box = _openBoxes[category];
    if (box == null || !box.isOpen) return {};

    return {'keys': box.length, 'isOpen': box.isOpen ? 1 : 0};
  }
}
