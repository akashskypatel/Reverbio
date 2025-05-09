/*
 *     Copyright (C) 2025 Akashy Patel
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

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/localization/app_localizations.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/logger_service.dart';
import 'package:reverbio/services/playlist_sharing.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/services/update_manager.dart';
import 'package:reverbio/style/app_themes.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

late ReverbioAudioHandler audioHandler;

final logger = Logger();
final appLinks = AppLinks();

bool isFdroidBuild = false;
bool isUpdateChecked = false;
Map<String, dynamic> userGeolocation = {};

const appLanguages = <String, String>{
  'English': 'en',
  'Arabic': 'ar',
  'Chinese (Simplified)': 'zh',
  'Chinese (Traditional)': 'zh-Hant',
  'French': 'fr',
  'German': 'de',
  'Greek': 'el',
  'Indonesian': 'id',
  'Italian': 'it',
  'Japanese': 'ja',
  'Korean': 'ko',
  'Russian': 'ru',
  'Polish': 'pl',
  'Portuguese': 'pt',
  'Spanish': 'es',
  'Ukrainian': 'uk',
};

final List<Locale> appSupportedLocales =
    appLanguages.values.map((languageCode) {
      final parts = languageCode.split('-');
      if (parts.length > 1) {
        return Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]);
      }
      return Locale(languageCode);
    }).toList();

class Reverbio extends StatefulWidget {
  const Reverbio({super.key});

  static Future<void> updateAppState(
    BuildContext context, {
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? useSystemColor,
  }) async {
    context.findAncestorStateOfType<_ReverbioState>()!.changeSettings(
      newThemeMode: newThemeMode,
      newLocale: newLocale,
      newAccentColor: newAccentColor,
      systemColorStatus: useSystemColor,
    );
  }

  @override
  _ReverbioState createState() => _ReverbioState();
}

class _ReverbioState extends State<Reverbio> {
  void changeSettings({
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? systemColorStatus,
  }) {
    if (mounted)
      setState(() {
        if (newThemeMode != null) {
          themeMode = newThemeMode;
          brightness = getBrightnessFromThemeMode(newThemeMode);
        }
        if (newLocale != null) {
          languageSetting = newLocale;
        }
        if (newAccentColor != null) {
          if (systemColorStatus != null &&
              useSystemColor.value != systemColorStatus) {
            useSystemColor.value = systemColorStatus;
            addOrUpdateData('settings', 'useSystemColor', systemColorStatus);
          }
          primaryColorSetting = newAccentColor;
        }
      });
  }

  @override
  void initState() {
    super.initState();
    getUserGeolocation();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      );
    });

    try {
      LicenseRegistry.addLicense(() async* {
        final license = await rootBundle.loadString(
          'assets/licenses/paytone.txt',
        );
        yield LicenseEntryWithLineBreaks(['paytoneOne'], license);
      });
    } catch (e, stackTrace) {
      logger.log('License Registration Error', e, stackTrace);
    }

    if (!isFdroidBuild &&
        !isUpdateChecked &&
        !offlineMode.value &&
        kReleaseMode) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        checkAppUpdates();
        isUpdateChecked = true;
      });
    }
  }

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) {
        final colorScheme = getAppColorScheme(
          lightColorScheme,
          darkColorScheme,
        );

        return MaterialApp.router(
          themeMode: themeMode,
          darkTheme: getAppTheme(colorScheme),
          theme: getAppTheme(colorScheme),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: appSupportedLocales,
          locale: languageSetting,
          routerConfig: NavigationManager.router,
        );
      },
    );
  }

  void getUserGeolocation() {
    getIPGeolocation().then((data) {
      if (mounted) {
        setState(() {
          userGeolocation = data;
        });
      }
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialisation();

  runApp(const Reverbio());
}

Future<void> initialisation() async {
  try {
    await Hive.initFlutter('reverbio');

    final boxNames = ['settings', 'user', 'userNoBackup', 'cache'];

    for (final boxName in boxNames) {
      await Hive.openBox(boxName);
    }

    audioHandler = await AudioService.init(
      builder: ReverbioAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.akashskypatel.reverbio',
        androidNotificationChannelName: 'Reverbio',
        androidNotificationIcon: 'drawable/ic_launcher_foreground',
        androidShowNotificationBadge: true,
      ),
    );

    // Init router
    NavigationManager.instance;

    // Init clients
    if (clientsSetting.value.isNotEmpty) {
      final chosenClients = <YoutubeApiClient>[];
      for (final client in clientsSetting.value) {
        final _client = clients[client];
        if (_client != null) {
          chosenClients.add(_client);
        }
      }
      userChosenClients = chosenClients;
    }

    currentLikedPlaylistsLength = ValueNotifier<int>(userLikedPlaylists.length);
    currentLikedSongsLength = ValueNotifier<int>(userLikedSongsList.length);
    currentOfflineSongsLength = ValueNotifier<int>(userOfflineSongs.length);
    currentRecentlyPlayedLength = ValueNotifier<int>(userRecentlyPlayed.length);
    currentLikedAlbumsLength = ValueNotifier<int>(userLikedAlbumsList.length);
    currentLikedArtistsLength = ValueNotifier<int>(userLikedArtistsList.length);
    activeQueueLength = ValueNotifier<int>(audioHandler.queueSongBars.length);

    try {
      // Listen to incoming links while app is running
      appLinks.uriLinkStream.listen(
        handleIncomingLink,
        onError: (err) {
          logger.log('URI link error:', err, null);
        },
      );
    } on PlatformException {
      logger.log('Failed to get initial uri', null, null);
    }
  } catch (e, stackTrace) {
    logger.log('Initialization Error', e, stackTrace);
  }
}

void handleIncomingLink(Uri? uri) async {
  if (uri != null && uri.scheme == 'reverbio' && uri.host == 'playlist') {
    try {
      if (uri.pathSegments[0] == 'custom') {
        final encodedPlaylist = uri.pathSegments[1];

        final playlist = await PlaylistSharingService.decodeAndExpandPlaylist(
          encodedPlaylist,
        );

        if (playlist != null) {
          userCustomPlaylists.value = [...userCustomPlaylists.value, playlist];
          addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
          showToast(
            NavigationManager().context,
            '${NavigationManager().context.l10n!.addedSuccess}!',
          );
        } else {
          showToast(NavigationManager().context, 'Invalid playlist data');
        }
      }
    } catch (e) {
      showToast(NavigationManager().context, 'Failed to load playlist');
    }
  }
}
