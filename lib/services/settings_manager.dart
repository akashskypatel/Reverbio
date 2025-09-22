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
import 'package:reverbio/services/plugins_manager.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/utilities/notifiable_value.dart';
import 'package:reverbio/utilities/utils.dart';

typedef PM = PluginsManager;

Future<void> initializeSettings() async {
  await playNextSongAutomatically.ensureInitialized(false);
  await useSystemColor.ensureInitialized(true);
  await usePureBlackColor.ensureInitialized(false);
  await offlineMode.ensureInitialized(false);
  await predictiveBack.ensureInitialized(false);
  await sponsorBlockSupport.ensureInitialized(true);
  await skipNonMusic.ensureInitialized(true);
  await audioQualitySetting.ensureInitialized('high');
  await enablePlugins.ensureInitialized(false);
  await languageSetting.ensureInitialized(
    getLocaleFromLanguageCode('English').toLanguageTag(),
  );
  await themeModeSetting.ensureInitialized('dark');
  await primaryColorSetting.ensureInitialized(0xff91cef4);
  await volume.ensureInitialized(100);
  await prepareNextSong.ensureInitialized(false);
  await useProxies.ensureInitialized(true);
  await autoCacheOffline.ensureInitialized(false);
  await postUpdateRun.ensureInitialized({});
  await streamRequestTimeout.ensureInitialized(30);
  await audioDevice.ensureInitialized(null);
  await offlineDirectory.ensureInitialized(
    (await getApplicationSupportDirectory()).path,
  );
  await additionalDirectories.ensureInitialized();
}

// Preferences

final playNextSongAutomatically = NotifiableValue<bool>.fromHive(
  'settings',
  'playNextSongAutomatically',
  defaultValue: false,
);

final useSystemColor = NotifiableValue<bool>.fromHive(
  'settings',
  'useSystemColor',
  defaultValue: Platform.isAndroid,
);

final usePureBlackColor = NotifiableValue<bool>.fromHive(
  'settings',
  'usePureBlackColor',
  defaultValue: false,
);

final offlineMode = NotifiableValue<bool>.fromHive(
  'settings',
  'offlineMode',
  defaultValue: false,
);

final predictiveBack = NotifiableValue<bool>.fromHive(
  'settings',
  'predictiveBack',
  defaultValue: false,
);

final sponsorBlockSupport = NotifiableValue<bool>.fromHive(
  'settings',
  'sponsorBlockSupport',
  defaultValue: true,
);

final skipNonMusic = NotifiableValue<bool>.fromHive(
  'settings',
  'skipNonMusic',
  defaultValue: true,
);

final audioQualitySetting = NotifiableValue<String>.fromHive(
  'settings',
  'audioQuality',
  defaultValue: 'high',
);

final enablePlugins = NotifiableValue<bool>.fromHive(
  'settings',
  'pluginsSupport',
  defaultValue: false,
);

final languageSetting = NotifiableValue<String>.fromHive(
  'settings',
  'language',
  defaultValue: getLocaleFromLanguageCode('English').toLanguageTag(),
);

final themeModeSetting = NotifiableValue<String>.fromHive(
  'settings',
  'themeMode',
  defaultValue: 'dark',
);

final primaryColorSetting = NotifiableValue<int>.fromHive(
  'settings',
  'accentColor',
  defaultValue: 0xff91cef4,
);

final volume = NotifiableValue<int>.fromHive(
  'settings',
  'volume',
  defaultValue: 100,
);

// Non-Storage Notifiers

final shuffleNotifier = ValueNotifier<bool>(false);

final repeatNotifier = ValueNotifier<AudioServiceRepeatMode>(
  AudioServiceRepeatMode.none,
);

var sleepTimerNotifier = ValueNotifier<Duration?>(null);

// Server-Notifiers

final announcementURL = ValueNotifier<String?>(null);

final prepareNextSong = NotifiableValue<bool>.fromHive(
  'settings',
  'prepareNextSong',
  defaultValue: false,
);

final useProxies = NotifiableValue<bool>.fromHive(
  'settings',
  'useProxies',
  defaultValue: true,
);

final autoCacheOffline = NotifiableValue<bool>.fromHive(
  'settings',
  'autoCacheOffline',
  defaultValue: false,
);

final postUpdateRun = NotifiableValue<Map>.fromHive(
  'settings',
  'postUpdateRun',
  defaultValue: {},
);

final streamRequestTimeout = NotifiableValue<int>.fromHive(
  'settings',
  'streamRequestTimeout',
  defaultValue: 30,
);

final audioDevice = NotifiableValue<dynamic>.fromHive(
  'settings',
  'audioDevice',
  defaultValue: null,
);

final offlineDirectory = NotifiableValue<String?>.fromHive(
  'settings',
  'offlineDirectory',
  defaultValue: null,
);

final additionalDirectories = NotifiableList<String>.fromHive(
  'settings',
  'additionalDirectories_${Platform.operatingSystem}',
);
