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

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:background_downloader/background_downloader.dart';
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
import 'package:reverbio/utilities/utils.dart';
//import 'package:youtube_explode_dart/youtube_explode_dart.dart';

ReverbioAudioHandler audioHandler = ReverbioAudioHandler();

final logger = Logger();
final appLinks = AppLinks();
ThemeData? theme;

bool isFdroidBuild = false;
bool isUpdateChecked = false;
final nowPlayingOpen = ValueNotifier(false);
Map<String, dynamic> userGeolocation = {};

const appLanguages = <String, String>{
  'English': 'en',
  'العربية': 'ar',
  'বাংলা': 'bn',
  '简体中文': 'zh',
  '繁體中文': 'zh-Hant',
  '繁體中文 (臺灣)': 'zh-TW',
  '廣東話': 'yue',
  'Français': 'fr',
  'Deutsch': 'de',
  'Ελληνικά': 'el',
  'हिन्दी': 'hi',
  'Bahasa Indonesia': 'id',
  'Italiano': 'it',
  '日本語': 'ja',
  '한국어': 'ko',
  'Polski': 'pl',
  'Português': 'pt',
  'Português (Brasil)': 'pt-br',
  'Русский': 'ru',
  'Español': 'es',
  'فارسی': 'fa',
  'ગુજરાતી': 'gu',
  'मराठी': 'mr',
  'Kiswahili': 'sw',
  'தமிழ்': 'ta',
  'తెలుగు': 'te',
  'ไทย': 'th',
  'Türkçe': 'tr',
  'Українська': 'uk',
  'Tiếng Việt': 'vi',
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
          languageSetting.value = newLocale;
        }
        if (newAccentColor != null) {
          if (systemColorStatus != null &&
              useSystemColor.value != systemColorStatus) {
            useSystemColor.value = systemColorStatus;
            unawaited(
              addOrUpdateData('settings', 'useSystemColor', systemColorStatus),
            );
          }
          primaryColorSetting = newAccentColor;
        }
        theme = Theme.of(context);
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
      checkInternetConnection();      
      FileDownloader().start();
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
    unawaited(audioHandler.dispose());
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
          locale: languageSetting.value,
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
  await initialization();

  runApp(const Reverbio());
}

Future<void> initialization() async {
  try {
    await Hive.initFlutter('reverbio');

    final boxNames = ['settings', 'user', 'userNoBackup', 'cache'];

    for (final boxName in boxNames) {
      await Hive.openBox(boxName);
    }

    // Init router
    NavigationManager.instance;
    
    L10n.initialize();

    audioHandler = await AudioService.init(
      builder: ReverbioAudioHandler.new,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.akashskypatel.reverbio',
        androidNotificationChannelName: 'Reverbio',
        androidNotificationIcon: 'drawable/ic_notification',
        androidShowNotificationBadge: true,
        androidNotificationOngoing: true,
        notificationColor: theme?.colorScheme.primary ?? Colors.blue.shade900,
      ),
    );
    audioDevice.value = await audioHandler.getCurrentAudioDevice();

    currentLikedPlaylistsLength.value = userLikedPlaylists.length;
    currentLikedSongsLength.value = userLikedSongsList.length;
    currentOfflineSongsLength.value = userOfflineSongs.length;
    currentRecentlyPlayedLength.value = userRecentlyPlayed.length;
    currentLikedAlbumsLength.value = userLikedAlbumsList.length;
    currentLikedArtistsLength.value = userLikedArtistsList.length;
    activeQueueLength.value = audioHandler.queueSongBars.length;

    await PM.initialize();

    await px.ensureInitialized();

    postUpdate();

    await getExistingOfflineSongs();

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
  final context = NavigationManager().context;
  if (uri != null && uri.scheme == 'reverbio' && uri.host == 'playlist') {
    try {
      if (uri.pathSegments[0] == 'custom') {
        final encodedPlaylist = uri.pathSegments[1];

        final playlist = await PlaylistSharingService.decodeAndExpandPlaylist(
          encodedPlaylist,
        );

        if (playlist != null) {
          userCustomPlaylists.value = [...userCustomPlaylists.value, playlist];
          await addOrUpdateData(
            'user',
            'customPlaylists',
            userCustomPlaylists.value,
          );
          showToast(context.l10n!.addedSuccess);
        } else {
          showToast(context.l10n!.invalidPlaylistData);
        }
      }
    } catch (e) {
      showToast(context.l10n!.failedToLoadPlaylist);
    }
  }
}
