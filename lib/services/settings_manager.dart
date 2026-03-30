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

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/utilities/notifiable_value.dart';
import 'package:reverbio/utilities/utils.dart';

export 'package:reverbio/services/plugins_manager.dart' show PM;

Future<void> initializeSettings() async {
  // R10 fix: Use Future.wait for parallel initialization of independent settings
  await Future.wait([
    playNextSongAutomatically.ensureInitialized(false),
    useSystemColor.ensureInitialized(true),
    usePureBlackColor.ensureInitialized(false),
    offlineMode.ensureInitialized(false),
    predictiveBack.ensureInitialized(false),
    sponsorBlockSupport.ensureInitialized(true),
    skipNonMusic.ensureInitialized(true),
    audioQualitySetting.ensureInitialized('high'),
    enablePlugins.ensureInitialized(false),
    languageSetting.ensureInitialized(
      getLocaleFromLanguageCode('English').toLanguageTag(),
    ),
    themeModeSetting.ensureInitialized('dark'),
    primaryColorSetting.ensureInitialized(0xff91cef4),
    volume.ensureInitialized(100),
    prepareNextSong.ensureInitialized(false),
    useProxies.ensureInitialized(true),
    autoCacheOffline.ensureInitialized(false),
    postUpdateRun.ensureInitialized({}),
    streamRequestTimeout.ensureInitialized(30),
    audioDevice.ensureInitialized(null),
    additionalDirectories.ensureInitialized(),
  ]);
  // offlineDirectory depends on getApplicationSupportDirectory(), initialize separately
  await offlineDirectory.ensureInitialized(
    (await getApplicationSupportDirectory()).path,
  );
}

// Preferences

final playNextSongAutomatically = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'playNextSongAutomatically',
  defaultValue: false,
);

final useSystemColor = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'useSystemColor',
  defaultValue: Platform.isAndroid,
);

final usePureBlackColor = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'usePureBlackColor',
  defaultValue: false,
);

final offlineMode = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'offlineMode',
  defaultValue: false,
);

final predictiveBack = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'predictiveBack',
  defaultValue: false,
);

final sponsorBlockSupport = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'sponsorBlockSupport',
  defaultValue: true,
);

final skipNonMusic = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'skipNonMusic',
  defaultValue: true,
);

final audioQualitySetting = NotifiableValue<String>.fromHive(
  HiveBoxNames.settings,
  'audioQuality',
  defaultValue: 'high',
);

final enablePlugins = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'pluginsSupport',
  defaultValue: false,
);

final languageSetting = NotifiableValue<String>.fromHive(
  HiveBoxNames.settings,
  'language',
  defaultValue: getLocaleFromLanguageCode('English').toLanguageTag(),
);

final themeModeSetting = NotifiableValue<String>.fromHive(
  HiveBoxNames.settings,
  'themeMode',
  defaultValue: 'dark',
);

final primaryColorSetting = NotifiableValue<int>.fromHive(
  HiveBoxNames.settings,
  'accentColor',
  defaultValue: 0xff91cef4,
);

final volume = NotifiableValue<int>.fromHive(
  HiveBoxNames.settings,
  'volume',
  defaultValue: 100,
);

// Non-Storage Notifiers

final shuffleNotifier = ValueNotifier<bool>(false);

final repeatNotifier = ValueNotifier<AudioServiceRepeatMode>(
  AudioServiceRepeatMode.none,
);

final sleepTimerNotifier = ValueNotifier<Duration?>(null);

// Server-Notifiers

final announcementURL = ValueNotifier<String?>(null);

final prepareNextSong = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'prepareNextSong',
  defaultValue: false,
);

final useProxies = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'useProxies',
  defaultValue: true,
);

final autoCacheOffline = NotifiableValue<bool>.fromHive(
  HiveBoxNames.settings,
  'autoCacheOffline',
  defaultValue: false,
);

final postUpdateRun = NotifiableValue<Map<String, dynamic>>.fromHive(
  HiveBoxNames.settings,
  'postUpdateRun',
  defaultValue: {},
);

final streamRequestTimeout = NotifiableValue<int>.fromHive(
  HiveBoxNames.settings,
  'streamRequestTimeout',
  defaultValue: 30,
);

final audioDevice = NotifiableValue<Map<String, dynamic>?>.fromHive(
  HiveBoxNames.settings,
  'audioDevice',
  defaultValue: null,
);

final offlineDirectory = NotifiableValue<String?>.fromHive(
  HiveBoxNames.settings,
  'offlineDirectory',
  defaultValue: null,
);

final additionalDirectories = NotifiableList<String>.fromHive(
  HiveBoxNames.settings,
  'additionalDirectories_${Platform.operatingSystem}',
);
