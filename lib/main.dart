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

import 'package:android_media_store/android_media_store.dart';
import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:background_downloader/background_downloader.dart' as downloader;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/localization/app_localizations.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/services/logger_service.dart';
import 'package:reverbio/services/playlist_sharing.dart';
import 'package:reverbio/services/proxy_manager.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/service_locator.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/services/update_manager.dart';
import 'package:reverbio/style/app_themes.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:window_manager/window_manager.dart';

// Service Locator - DI seam (A1 fix)
// Backward-compatible getters that delegate to ServiceLocator
ReverbioAudioHandler get audioHandler => ServiceLocator.audioHandler;
HiveService get hiveService => ServiceLocator.hiveService;
Logger get logger => ServiceLocator.logger;

final appLinks = AppLinks();
StreamSubscription<Uri?>? _appLinksSubscription; // R6 fix: Store subscription for cancellation
// R3 fix: Remove theme global - use primaryColorSetting directly from widget tree

bool isFdroidBuild = false;
bool isUpdateChecked = false;
final nowPlayingOpen = ValueNotifier(false);
Map<String, dynamic> userGeolocation = {};
const audioChannel = MethodChannel('com.akashskypatel.reverbio/audio');
const permissionChannel = MethodChannel(
  'com.akashskypatel.reverbio/media_permissions',
);
late final ImageCache imageCache;

class Reverbio extends StatefulWidget {
  const Reverbio({super.key});

  static Future<void> updateAppState(
    BuildContext context, {
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? useSystemColor,
  }) async {
    // R10 fix: Add null check for findAncestorStateOfType
    final state = context.findAncestorStateOfType<_ReverbioState>();
    if (state != null) {
      state.changeSettings(
        newThemeMode: newThemeMode,
        newLocale: newLocale,
        newAccentColor: newAccentColor,
        systemColorStatus: useSystemColor,
      );
    }
  }

  @override
  _ReverbioState createState() => _ReverbioState();
}

class _ReverbioState extends State<Reverbio> with WindowListener {
  bool _isDisposed = false; // R9 fix: Guard against double disposal

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
          languageSetting.value = newLocale.toLanguageTag();
        }
        if (newAccentColor != null) {
          if (systemColorStatus != null &&
              useSystemColor.value != systemColorStatus) {
            useSystemColor.value = systemColorStatus;
          }
          primaryColorSetting.value = newAccentColor.toARGB32();
        }
        // R3 fix: Removed theme = Theme.of(context) - theme global removed
      });
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) windowManager.addListener(this);
    // R7 fix: Initialize app but don't block UI - errors handled internally
    unawaited(initialize());
  }

  // R7 fix: Wrap entire body in single try-catch to prevent swallowed exceptions
  Future<void> initialize() async {
    try {
      if (Platform.isWindows) {
        await windowManager.setPreventClose(true);
        if (mounted) setState(() {});
      }
      getUserGeolocation();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
          );
          await checkInternetConnection();
          await downloader.FileDownloader().start();
          await ProxyManager.ensureInitialized();
        } catch (e, stackTrace) {
          logger.log('Error in initialize (postFrameCallback):', e, stackTrace);
        }
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
          // R12 fix: Set flag before calling checkAppUpdates to prevent multiple calls
          isUpdateChecked = true;
          checkAppUpdates();
        });
      }
    } catch (e, stackTrace) {
      logger.log('Error in initialize():', e, stackTrace);
    }
  }

  @override
  void onWindowClose() async {
    try {
      final _isPreventClose = await windowManager.isPreventClose();
      if (_isPreventClose) {
        await showDialog(
          // R8 fix: Use dialog builder's context for Navigator operations
          context: NavigationManager().context!,
          builder: (dialogContext) {
            return ConfirmationDialog(
              title: L10n.current.quitApp,
              confirmText: L10n.current.confirm,
              cancelText: L10n.current.cancel,
              onCancel: () {
                Navigator.of(dialogContext).pop();
              },
              onSubmit: () async {
                try {
                  await clearTempFiles();
                  disposeData();
                  await HiveService.close();
                  downloader.FileDownloader().destroy();
                  Navigator.of(dialogContext).pop();
                  await windowManager.destroy();
                } catch (e, stackTrace) {
                  logger.log('Window Close Error', e, stackTrace);
                }
              },
            );
          },
        );
      }
    } catch (e, stackTrace) {
      logger.log('Window Close Error', e, stackTrace);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    _appLinksSubscription?.cancel(); // R6 fix: Cancel appLinks subscription
    // R9 fix: Guard against double disposal
    if (!_isDisposed) {
      _isDisposed = true;
      disposeData();
      // A1 fix: Use ServiceLocator for centralized disposal
      unawaited(ServiceLocator.dispose());
      unawaited(clearTempFiles());
      downloader.FileDownloader().destroy();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) {
        // R4 fix: Generate separate ColorScheme for light and dark themes
        final lightScheme = getAppColorSchemeForBrightness(
          lightColorScheme,
          Brightness.light,
        );
        final darkScheme = getAppColorSchemeForBrightness(
          darkColorScheme,
          Brightness.dark,
        );

        return MaterialApp.router(
          themeMode: themeMode,
          darkTheme: getAppTheme(darkScheme),
          theme: getAppTheme(lightScheme),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: appSupportedLocales,
          locale: parseLocale(languageSetting.value),
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
  imageCache = PaintingBinding.instance.imageCache;
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  await initialization();
  // Init router
  NavigationManager.instance;

  // R1 fix: Remove nested MaterialApp - run Reverbio directly (it contains MaterialApp.router)
  runApp(const Reverbio());
}

Future<void> initialization() async {
  try {
    // A1 fix: Use ServiceLocator for DI
    await ServiceLocator.initialize();
    if (Platform.isAndroid) await AndroidMediaStore.ensureInitialized();
    L10n.initialize();

    final handler = await AudioService.init(
      builder: ReverbioAudioHandler.new,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.akashskypatel.reverbio',
        androidNotificationChannelName: 'Reverbio',
        androidNotificationIcon: 'drawable/ic_notification',
        androidShowNotificationBadge: true,
        androidNotificationOngoing: true,
        // R3 fix: Use primaryColorSetting directly instead of null theme global
        notificationColor: Color(primaryColorSetting.value),
      ),
    );
    ServiceLocator.setAudioHandler(handler);
    audioDevice.value = await audioHandler.getCurrentAudioDevice();

    await PM.initialize();

    await initializeData();

    await initializeSettings();

    //postUpdate();

    await getExistingOfflineSongs();

    try {
      // Listen to incoming links while app is running
      // R6 fix: Store subscription for cancellation in dispose
      _appLinksSubscription = appLinks.uriLinkStream.listen(
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
  final context = NavigationManager().context!;
  if (uri != null && uri.scheme == 'reverbio' && uri.host == 'playlist') {
    try {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'custom') {
        // R5 fix: Add bounds checking for pathSegments
        if (uri.pathSegments.length < 2) {
          showToast(context.l10n!.invalidPlaylistData);
          return;
        }
        final encodedPlaylist = uri.pathSegments[1];

        final playlist = await PlaylistSharingService.decodeAndExpandPlaylist(
          encodedPlaylist,
        );

        if (playlist != null) {
          userCustomPlaylists.add(Map<String, dynamic>.from(playlist));
          // R5 fix: Persist the incoming deep link playlist
          await HiveService.addOrUpdateData<List<dynamic>>(
            'user',
            'customPlaylists',
            userCustomPlaylists,
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
