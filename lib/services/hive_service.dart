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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/notifiable_value.dart';

abstract class HiveBoxNames {
  static const String settings = 'settings';
  static const String user = 'user';
  static const String userNoBackup = 'userNoBackup';
  static const String cache = 'cache';
}

class HiveService {
  factory HiveService() => _instance;
  HiveService._internal();
  // Singleton instance
  static final HiveService _instance = HiveService._internal();
  static final Completer _initCompleter = Completer();
  // Box caching
  static final Map<String, Completer<Box>> _openingBoxes = {};

  static bool isInitialized = false;

  static Duration cachingDuration = const Duration(days: 30);

  // Box names and categories
  static const _boxNames = [
    HiveBoxNames.settings,
    HiveBoxNames.user,
    HiveBoxNames.userNoBackup,
    HiveBoxNames.cache,
  ];

  static Future<void> ensureInitialize() async {
    if (_initCompleter.isCompleted) return;
    await Hive.initFlutter('reverbio');
    for (final box in _boxNames) {
      await _openBox(box);
    }
    isInitialized = true;
    _initCompleter.complete();
  }

  static Future<T?> getData<T>(
    String boxName,
    String category, {
    T? defaultValue,
  }) async {
    await _initCompleter.future;
    try {
      final _box = await _openBox(boxName);
      final value = _box.get(category, defaultValue: defaultValue);
      final returnValue = getDataByType<T>(value, defaultValue: defaultValue);
      if (boxName == HiveBoxNames.cache) {
        final cacheIsValid = _isCacheValid(_box, category, cachingDuration);
        if (!cacheIsValid) {
          // Schedule deletion but don't wait for it
          unawaited(deleteData(boxName, category));
          unawaited(deleteData(boxName, '${category}_date'));
          return null;
        }
      }
      return returnValue;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return defaultValue;
    }
  }

  static T getDataByType<T>(dynamic value, {dynamic defaultValue}) {
    // Handle type conversion for Hive data
    if (T == List<String>) {
      value = getList<String>(
        value,
        defaultValue: (defaultValue ?? <String>[]) as List<String>,
      );
    } else if (T == Map<String, dynamic>) {
      value = getMap(
        value,
        defaultValue: defaultValue as Map<String, dynamic>?,
      );
    } else if (T == List<Map<String, dynamic>>) {
      value = getList<Map<String, dynamic>>(
        value,
        defaultValue:
            (defaultValue ?? List<Map<String, dynamic>>.empty(growable: true))
                as List<Map<String, dynamic>>,
      );
    } else if (T == List<Map>) {
      // Handle List<Map> - Hive returns List<Map<dynamic, dynamic>>
      if (value is List) {
        value = value.whereType<Map>().map(Map<String, dynamic>.from).toList();
      } else {
        value = defaultValue ?? <Map<String, dynamic>>[];
      }
    }
    // Hive returns Map<dynamic, dynamic>; convert to Map<String, dynamic> for
    // nullable variants (e.g. T == Map<String, dynamic>?) that fall through the
    // T == Map<String, dynamic> branch above.
    if (value is Map && value is! Map<String, dynamic>) {
      value = Map<String, dynamic>.from(value);
    }
    return value as T;
  }

  static List<T> getList<T>(dynamic value, {List<T> defaultValue = const []}) {
    try {
      if (value == null) return defaultValue;
      if (value is List) {
        if ((T == Map<String, dynamic>) && value.every((e) => e is Map)) {
          return value
                  .whereType<Map>()
                  .map(
                    (e) => getMap(
                      e is Map<String, dynamic>
                          ? e
                          : Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList()
              as List<T>;
        } else if (value.every((e) => e is T)) {
          return value.toList().cast<T>();
        } else {
          return value.map((e) => e as T).toList();
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return defaultValue;
  }

  static Map<String, dynamic> getMap(
    dynamic value, {
    Map<String, dynamic>? defaultValue,
  }) {
    try {
      if (value == null) {
        return defaultValue ?? <String, dynamic>{};
      }
      if (value is Map) {
        // Convert Map<dynamic, dynamic> to Map<String, dynamic>
        return Map<String, dynamic>.from(value);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return defaultValue ?? <String, dynamic>{};
  }

  static Future<Box> _openBox(String boxName) async {
    // Return cached open box
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
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
      completer.complete(box);
      _openingBoxes.remove(boxName);
      return box;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      completer.completeError(e);
      _openingBoxes.remove(boxName);
      rethrow;
    }
  }

  static Future<void> close() async {
    // R6 fix: Flush all pending NotifiableValue writes before closing
    await NotifiableValue.flushAll();
    await compactAllBoxes();
    await closeAllBoxes();
    await Hive.close();
  }

  static Future<void> addOrUpdateData<T>(
    String boxName,
    String category,
    dynamic value,
  ) async {
    await _initCompleter.future;
    try {
      final box = await _openBox(boxName);
      final _newData = getDataByType<T>(value);
      await box.put(category, _newData);
      if (boxName == 'cache') {
        await box.put('${category}_date', DateTime.now());
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<void> deleteData(String boxName, String key) async {
    await _initCompleter.future;
    try {
      final box = await _openBox(boxName);
      await box.delete(key);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<void> clearBox(String boxName) async {
    await _initCompleter.future;
    final box = await _openBox(boxName);
    await box.clear();
  }

  static Future<void> compactBox(String boxName) async {
    await _initCompleter.future;
    final box = await _openBox(boxName);
    await box.compact();
  }

  static Future<void> compactAllBoxes() async {
    await _initCompleter.future;
    for (final box in _boxNames) {
      if (Hive.isBoxOpen(box)) {
        await Hive.box(box).compact();
      }
    }
  }

  static Future<void> closeAllBoxes() async {
    await _initCompleter.future;
    for (final box in _boxNames) {
      if (Hive.isBoxOpen(box)) {
        await Hive.box(box).close();
      }
    }
    _openingBoxes.clear();
  }

  static bool _isCacheValid(Box box, String key, Duration cachingDuration) {
    final date = box.get('${key}_date');
    if (date == null) {
      return false;
    }
    final age = DateTime.now().difference(date);
    return age < cachingDuration;
  }

  static Future<String> backupData(BuildContext context) async {
    await _initCompleter.future;
    final boxNames = [HiveBoxNames.user, HiveBoxNames.settings];
    final dlPath = await FilePicker.platform.getDirectoryPath();

    if (dlPath == null) {
      return '${context.l10n!.chooseBackupDir}!';
    }

    try {
      for (final boxName in boxNames) {
        final box = await _openBox(boxName);
        final backupFile = File(path.join(dlPath, '$boxName.hive'));

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
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return '${context.l10n!.backupError}: $e';
    }
  }

  static Future<String> restoreData(BuildContext context) async {
    await _initCompleter.future;
    final boxNames = [HiveBoxNames.user, HiveBoxNames.settings];
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
          final boxPath = box.path!; // Save path before closing
          await box.close(); // Close before restoring

          // Copy backup file over existing box file
          final backup = File(backupFile.path!);
          final boxFile = File(boxPath);

          if (await boxFile.exists()) {
            await boxFile.delete();
          }

          await backup.copy(boxFile.path);

          await _openBox(boxName);
        }
      }
      return '${context.l10n!.restoredSuccess}!';
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return '${context.l10n!.restoreError}: $e';
    }
  }
}
