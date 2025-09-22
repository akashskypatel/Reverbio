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
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/utils.dart';

class HiveService {
  factory HiveService() => _instance;
  HiveService._internal();
  // Singleton instance
  static final HiveService _instance = HiveService._internal();

  // Box caching
  static final Map<String, Completer<Box>> _openingBoxes = {};

  static bool isInitialized = false;

  static Duration cachingDuration = const Duration(days: 30);

  // Box names and categories
  static const _boxNames = ['settings', 'user', 'userNoBackup', 'cache'];

  static Future<void> ensureInitialize() async {
    await Hive.initFlutter('reverbio');
    for (final box in _boxNames) {
      await _openBox(box);
    }
    isInitialized = true;
  }

  static Future<dynamic> getData<T>(
    String boxName,
    String category, {
    dynamic defaultValue,
  }) async {
    try {
      final _box = await _openBox(boxName);
      final value = _box.get(category, defaultValue: defaultValue);
      final returnValue = getDataByType<T>(value, defaultValue: defaultValue);
      if (boxName == 'cache') {
        final cacheIsValid = _isCacheValid(_box, category, cachingDuration);
        if (!cacheIsValid) {
          // Schedule deletion but don't wait for it
          unawaited(deleteData(boxName, category));
          unawaited(deleteData(boxName, '${category}_date'));
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
    if (T == List<String>) {
      value = getList<String>(
        value,
        defaultValue: (defaultValue ?? <String>[]) as List<String>,
      );
    } else if (T == Map<String, dynamic>) {
      value = getMap(value, defaultValue: defaultValue as Map<String, dynamic>);
    } else if (T == List<Map<String, dynamic>>) {
      value = getList<Map<String, dynamic>>(
        value,
        defaultValue: (defaultValue ?? List<Map<String, dynamic>>.empty(growable: true)) as List<Map<String, dynamic>>,
      );
    } else if (T == List<Map>) {
      value = getList<Map>(
        value,
        defaultValue: (defaultValue ?? List<Map>.empty(growable: true)) as List<Map>,
      );
    }
    return value as T;
  }

  static List<T> getList<T>(dynamic value, {List<T> defaultValue = const []}) {
    try {
      if (value == null) return defaultValue;
      if (value is List) {
        if ((T == Map<String, dynamic>) && value.every((e) => e is Map)) {
          return value.whereType<Map>().map(getMap).toList() as List<T>;
        } else if (value.every((e) => e is T)) {
          return value.cast<T>();
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
    dynamic defaultValue = const {},
  }) {
    try {
      if (value == null) return defaultValue;
      if (value is Map) {
        if (value.keys.every((k) => k is String)) {
          return value.cast<String, dynamic>();
        } else {
          return copyMap(value);
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

  void close() async {
    await compactAllBoxes();
    await closeAllBoxes();
    await Hive.close();
  }

  static Future<void> addOrUpdateData(
    String boxName,
    String category,
    dynamic value,
  ) async {
    try {
      final box = await _openBox(boxName);
      await box.put(category, getDataByType(value));
      if (category == 'cache') {
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
    final box = await _openBox(boxName);
    await box.delete(key);
  }

  static Future<void> clearBox(String boxName) async {
    final box = await _openBox(boxName);
    await box.clear();
  }

  static Future<void> compactBox(String boxName) async {
    final box = await _openBox(boxName);
    await box.compact();
  }

  static Future<void> compactAllBoxes() async {
    for (final box in _boxNames) {
      if (Hive.isBoxOpen(box)) {
        await Hive.box(box).compact();
      }
    }
  }

  static Future<void> closeAllBoxes() async {
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
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
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
