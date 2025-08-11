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
import 'dart:convert';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/screens/search_page.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/services/update_manager.dart';
import 'package:reverbio/style/app_colors.dart';
import 'package:reverbio/style/app_themes.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_bottom_sheet.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/url_launcher.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/bottom_sheet_bar.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/custom_bar.dart';
import 'package:reverbio/widgets/playlist_import.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ThemeData _theme;
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final primaryColor = _theme.colorScheme.primary;
    final activatedColor = _theme.colorScheme.secondaryContainer;
    final inactivatedColor = _theme.colorScheme.surfaceContainerHigh;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.settings)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            _buildPreferencesSection(
              context,
              primaryColor,
              activatedColor,
              inactivatedColor,
            ),
            if (!offlineMode.value)
              _buildOnlineFeaturesSection(
                context,
                activatedColor,
                inactivatedColor,
                primaryColor,
              ),
            _buildOthersSection(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(
    BuildContext context,
    Color primaryColor,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    return Column(
      children: [
        SectionHeader(title: context.l10n!.preferences),
        CustomBar(
          tileName: context.l10n!.accentColor,
          tileIcon: FluentIcons.color_24_filled,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () => _showAccentColorPicker(context),
        ),
        CustomBar(
          tileName: context.l10n!.themeMode,
          tileIcon: FluentIcons.weather_sunny_28_filled,
          onTap:
              () => _showThemeModePicker(
                context,
                activatedColor,
                inactivatedColor,
              ),
        ),
        CustomBar(
          tileName: context.l10n!.streamRequestTimeout,
          tileIcon: FluentIcons.timer_10_24_filled,
          onTap:
              () => _showTimeoutThresholdPicker(
                context,
                activatedColor,
                inactivatedColor,
              ),
        ),
        if (isMobilePlatform())
          CustomBar(
            tileName: context.l10n!.audioDevice,
            tileIcon: FluentIcons.speaker_settings_24_filled,
            onTap:
                () => _showAudioDevicePicker(
                  context,
                  activatedColor,
                  inactivatedColor,
                ),
          ),
        /* //let yt-explode manage client for best experience
        CustomBar(
          tileName: context.l10n!.client,
          tileIcon: FluentIcons.device_meeting_room_24_filled,
          onTap:
              () =>
                  _showClientPicker(context, activatedColor, inactivatedColor),
        ),
        */
        CustomBar(
          tileName: context.l10n!.language,
          tileIcon: FluentIcons.translate_24_filled,
          onTap:
              () => _showLanguagePicker(
                context,
                activatedColor,
                inactivatedColor,
              ),
        ),
        CustomBar(
          tileName: context.l10n!.audioQuality,
          tileIcon: FluentIcons.headphones_sound_wave_24_filled,
          onTap:
              () => _showAudioQualityPicker(
                context,
                activatedColor,
                inactivatedColor,
              ),
        ),
        CustomBar(
          tileName: context.l10n!.dynamicColor,
          tileIcon: FluentIcons.toggle_left_24_filled,
          trailing: Switch(
            value: useSystemColor.value,
            onChanged: (value) => _toggleSystemColor(context, value),
          ),
        ),
        if (themeMode == ThemeMode.dark)
          CustomBar(
            tileName: context.l10n!.pureBlackTheme,
            tileIcon: FluentIcons.color_background_24_filled,
            trailing: Switch(
              value: usePureBlackColor.value,
              onChanged: (value) => _togglePureBlack(context, value),
            ),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: predictiveBack,
          builder: (context, value, __) {
            return CustomBar(
              tileName: context.l10n!.predictiveBack,
              tileIcon: FluentIcons.position_backward_24_filled,
              trailing: Switch(
                value: value,
                onChanged: (value) => _togglePredictiveBack(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: offlineMode,
          builder: (context, value, __) {
            return CustomBar(
              tileName: context.l10n!.offlineMode,
              tileIcon: FluentIcons.cellular_off_24_regular,
              trailing: Switch(
                value: value,
                onChanged: (value) async => _toggleOfflineMode(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: enablePlugins,
          builder: (context, value, __) {
            return CustomBar(
              tileName: context.l10n!.plugins,
              tileIcon:
                  value
                      ? FluentIcons.plug_connected_24_regular
                      : FluentIcons.plug_disconnected_24_regular,
              trailing: Switch(
                value: value,
                onChanged: (value) => _togglePluginsSupport(context, value),
              ),
              onTap:
                  value
                      ? () => _showPluginList(
                        context,
                        activatedColor,
                        inactivatedColor,
                      )
                      : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildOnlineFeaturesSection(
    BuildContext context,
    Color activatedColor,
    Color inactivatedColor,
    Color primaryColor,
  ) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: sponsorBlockSupport,
          builder: (context, value, __) {
            return CustomBar(
              tileName: context.l10n!.sponsorBlock,
              tileIcon: FluentIcons.presence_blocked_24_regular,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSponsorBlock(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: skipNonMusic,
          builder: (context, value, __) {
            return CustomBar(
              tileName: context.l10n!.nonMusicBlock,
              tileIcon: FluentIcons.skip_forward_tab_24_regular,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSkipNonMusic(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: prepareNextSong,
          builder: (context, value, __) {
            return CustomBar(
              tileName: context.l10n!.prepareNextSong,
              tileIcon: FluentIcons.music_note_2_24_filled,
              trailing: Switch(
                value: value,
                onChanged: (value) => _togglePrepareNextSong(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: useProxies,
          builder: (context, value, __) {
            return CustomBar(
              tileName: context.l10n!.useProxies,
              tileIcon: FluentIcons.server_link_24_filled,
              borderRadius: commonCustomBarRadiusLast,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleUseProxies(context, value),
              ),
            );
          },
        ),
        //TODO: Fix playNextSongAutomatically
        /*
        ValueListenableBuilder<bool>(
          valueListenable: playNextSongAutomatically,
          builder: (context, value, __) {
            return CustomBar(
              context.l10n!.automaticSongPicker,
              FluentIcons.music_note_2_play_20_filled,
              trailing: Switch(
                value: value,
                onChanged: (value) {
                  audioHandler.changeAutoPlayNextStatus();
                  showToast(context, context.l10n!.settingChangedMsg);
                },
              ),
            );
          },
        ),
        */
        //TODO: Fix defaultRecommendations
        /*
        ValueListenableBuilder<bool>(
          valueListenable: defaultRecommendations,
          builder: (context, value, __) {
            return CustomBar(
              context.l10n!.originalRecommendations,
              FluentIcons.channel_share_24_regular,
              trailing: Switch(
                value: value,
                onChanged:
                    (value) => _toggleDefaultRecommendations(context, value),
              ),
            );
          },
        ),
        */
        _buildToolsSection(context),
        _buildSponsorSection(context, primaryColor),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    final _appVersionFuture = getLatestAppVersion();
    return Column(
      children: [
        SectionHeader(title: context.l10n!.tools),
        CustomBar(
          tileName: context.l10n!.clearCache,
          tileIcon: FluentIcons.broom_24_filled,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () {
            clearCache();
            showToast('${context.l10n!.cacheMsg}!');
          },
        ),
        CustomBar(
          tileName: context.l10n!.clearSearchHistory,
          tileIcon: FluentIcons.history_24_filled,
          onTap: () => _showClearSearchHistoryDialog(context),
        ),
        CustomBar(
          tileName: context.l10n!.clearRecentlyPlayed,
          tileIcon: FluentIcons.text_grammar_dismiss_24_filled,
          onTap: () => _showClearRecentlyPlayedDialog(context),
        ),
        CustomBar(
          tileName: context.l10n!.backupUserData,
          tileIcon: FluentIcons.cloud_sync_24_filled,
          onTap: () => _backupUserData(context),
        ),
        CustomBar(
          tileName: context.l10n!.restoreUserData,
          tileIcon: FluentIcons.cloud_add_24_filled,
          onTap: () async {
            final response = await restoreData(context);
            showToast(response);
          },
        ),
        CustomBar(
          tileName: context.l10n!.importPlaylists,
          tileIcon: FluentIcons.table_add_24_filled,
          onTap: () => showPlaylistImporter(context),
        ),
        if (!isFdroidBuild)
          FutureBuilder(
            future: _appVersionFuture,
            builder: (context, snapshot) {
              Widget trailing = const Spinner();
              if (snapshot.connectionState == ConnectionState.waiting)
                trailing = const Spinner();
              else if (snapshot.hasError ||
                  snapshot.data == null ||
                  snapshot.data?['error'] != null)
                trailing = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(FluentIcons.error_circle_24_filled),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        snapshot.data?['error'] ?? '',
                        softWrap: true,
                      ),
                    ),
                  ],
                );
              else
                trailing = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.data?['message'] ?? '',
                        softWrap: true,
                      ),
                    ),
                  ],
                );
              return CustomBar(
                tileName: context.l10n!.downloadAppUpdate,
                tileIcon: FluentIcons.arrow_download_24_filled,
                borderRadius: commonCustomBarRadiusLast,
                onTap:
                    snapshot.data?['canUpdate'] ?? false
                        ? () async => checkAppUpdates()
                        : null,
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 125),
                  child: trailing,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSponsorSection(BuildContext context, Color primaryColor) {
    return Column(
      children: [
        SectionHeader(title: context.l10n!.becomeSponsor),
        CustomBar(
          tileName: context.l10n!.sponsorProject,
          tileIcon: FluentIcons.heart_24_filled,
          backgroundColor: primaryColor,
          iconColor: Colors.white,
          textColor: Colors.white,
          borderRadius: commonCustomBarRadius,
          onTap: () => launchURL(Uri.parse('https://ko-fi.com/akashskypatel')),
        ),
      ],
    );
  }

  Widget _buildOthersSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(title: context.l10n!.others),
        CustomBar(
          tileName: context.l10n!.licenses,
          tileIcon: FluentIcons.document_24_filled,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () => NavigationManager.router.go('/settings/license'),
        ),
        CustomBar(
          tileName: '${context.l10n!.copyLogs} (${logger.getLogCount()})',
          tileIcon: FluentIcons.error_circle_24_filled,
          onTap: () async => showToast(await logger.copyLogs(context)),
        ),
        CustomBar(
          tileName: context.l10n!.about,
          tileIcon: FluentIcons.book_information_24_filled,
          borderRadius: commonCustomBarRadiusLast,
          onTap: () => NavigationManager.router.go('/settings/about'),
        ),
      ],
    );
  }

  void _showAccentColorPicker(BuildContext context) {
    showCustomBottomSheet(
      context,
      GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
        ),
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: availableColors.length,
        itemBuilder: (context, index) {
          final color = availableColors[index];
          final isSelected = color == primaryColorSetting;

          return GestureDetector(
            onTap: () {
              addOrUpdateData('settings', 'accentColor', color.toARGB32());
              Reverbio.updateAppState(
                context,
                newAccentColor: color,
                useSystemColor: false,
              );
              showToast(context.l10n!.accentChangeMsg);
              GoRouter.of(context).pop();
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor:
                      themeMode == ThemeMode.light
                          ? color.withAlpha(150)
                          : color,
                ),
                if (isSelected)
                  Icon(
                    FluentIcons.checkmark_24_filled,
                    color: _theme.colorScheme.onPrimary,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showThemeModePicker(
    BuildContext context,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    final availableModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableModes.length,
        itemBuilder: (context, index) {
          final mode = availableModes[index];
          final borderRadius = getItemBorderRadius(
            index,
            availableModes.length,
          );

          return BottomSheetBar(
            mode.name,
            onTap: () {
              addOrUpdateData('settings', 'themeMode', mode.name);
              Reverbio.updateAppState(context, newThemeMode: mode);
              GoRouter.of(context).pop();
            },
            themeMode == mode ? activatedColor : inactivatedColor,
            borderRadius: borderRadius,
          );
        },
      ),
    );
  }

  void _showAudioDevicePicker(
    BuildContext context,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    showCustomBottomSheet(
      context,
      StatefulBuilder(
        builder: (context, setState) {
          return FutureBuilder(
            future: audioHandler.getConnectedAudioDevices(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Spinner();
              if (!snapshot.hasData ||
                  snapshot.hasError ||
                  snapshot.data == null)
                return const Icon(FluentIcons.error_circle_24_filled);
              else {
                final devices = snapshot.data!;
                final deviceData =
                    devices.map((e) {
                        final category = getAudioDeviceCategory(e['category']);
                        return {
                          ...(e as Map),
                          'icon': category['icon'],
                          'order': category['order'],
                          'localization': category['localization'],
                        };
                      }).toList()
                      ..sort((a, b) => a['order'].compareTo(b['order']));
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: commonListViewBottomPadding,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final isSelected =
                        audioDevice.value['id'] == devices[index]['id'];
                    final borderRadius = getItemBorderRadius(
                      index,
                      devices.length,
                    );

                    return CustomBar(
                      tileName:
                          deviceData[index]['name'] == 'auto'
                              ? context.l10n!.selectAutomatically
                              : '${deviceData[index]['name']} - ${deviceData[index]['localization']} (${androidDeviceTypes[deviceData[index]['type']]?['name']})',
                      tileIcon:
                          deviceData[index]['icon'] ??
                          FluentIcons.speaker_box_24_filled,
                      onTap: () {
                        if (context.mounted)
                          setState(() {
                            audioDevice.value = devices[index];
                            audioHandler.setAudioDevice(devices[index]);
                          });
                        addOrUpdateData(
                          'settings',
                          'audioDevice',
                          audioDevice.value,
                        );
                      },
                      backgroundColor:
                          isSelected ? activatedColor : inactivatedColor,
                      borderRadius: borderRadius,
                    );
                  },
                );
              }
            },
          );
        },
      ),
    );
  }

  void _showTimeoutThresholdPicker(
    BuildContext context,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    final availableValues = [5, 10, 15, 20, 25, 30];
    showCustomBottomSheet(
      context,
      StatefulBuilder(
        builder: (context, setState) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: commonListViewBottomPadding,
            itemCount: availableValues.length,
            itemBuilder: (context, index) {
              final threshold = availableValues[index];
              final isSelected = streamRequestTimeout.value == threshold;
              final borderRadius = getItemBorderRadius(
                index,
                availableValues.length,
              );

              return BottomSheetBar(
                threshold.toString(),
                onTap: () {
                  if (context.mounted)
                    setState(() {
                      streamRequestTimeout.value = threshold;
                    });
                  addOrUpdateData(
                    'settings',
                    'streamRequestTimeout',
                    streamRequestTimeout.value,
                  );
                },
                isSelected ? activatedColor : inactivatedColor,
                borderRadius: borderRadius,
              );
            },
          );
        },
      ),
    );
  }

  void _showClientPicker(
    BuildContext context,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    final availableClients = clients.keys.toList();
    showCustomBottomSheet(
      context,
      StatefulBuilder(
        builder: (context, setState) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: commonListViewBottomPadding,
            itemCount: availableClients.length,
            itemBuilder: (context, index) {
              final client = availableClients[index];
              final _clientInModel = clients[client];
              final isSelected = userChosenClients.contains(_clientInModel);
              final borderRadius = getItemBorderRadius(
                index,
                availableClients.length,
              );

              return BottomSheetBar(
                client,
                onTap: () {
                  if (mounted)
                    setState(() {
                      if (isSelected) {
                        clientsSetting.value.remove(client);
                        userChosenClients.remove(_clientInModel);
                      } else {
                        if (_clientInModel != null) {
                          clientsSetting.value.add(client);
                          userChosenClients.add(_clientInModel);
                        }
                      }
                    });
                  addOrUpdateData('settings', 'clients', clientsSetting.value);
                },
                isSelected ? activatedColor : inactivatedColor,
                borderRadius: borderRadius,
              );
            },
          );
        },
      ),
    );
  }

  void _showPluginList(
    BuildContext context,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    final canCloseOnTapOutside = ValueNotifier(true);
    showCustomBottomSheet(
      canCloseOnTapOutside: canCloseOnTapOutside,
      context,
      StatefulBuilder(
        builder: (context, setState) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            width: MediaQuery.of(context).size.width * 0.75,
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                children: [
                  SectionHeader(
                    title: context.l10n!.plugins,
                    actionsExpanded: true,
                    actions: [
                      IconButton(
                        onPressed: () async {
                          await _reloadPlugins(null);
                          setState(() {});
                        },
                        icon: const Icon(FluentIcons.arrow_sync_24_filled),
                        iconSize: listHeaderIconSize,
                        color: _theme.colorScheme.primary,
                      ),
                      IconButton(
                        onPressed: () async {
                          canCloseOnTapOutside
                            ..value = false
                            ..value = await _showAddPluginDialog(context);
                        },
                        icon: const Icon(FluentIcons.add_24_regular),
                        iconSize: listHeaderIconSize,
                        color: _theme.colorScheme.primary,
                      ),
                    ],
                  ),
                  ValueListenableBuilder(
                    valueListenable: PM.pluginsDataNotifier,
                    builder: (context, value, ___) {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        padding: commonListViewBottomPadding,
                        itemCount: PM.pluginsData.length,
                        itemBuilder: (context, index) {
                          return BottomSheetBar(
                            '${PM.pluginsData[index]['name']} (${PM.pluginsData[index]['version']})',
                            onTap: () async {
                              canCloseOnTapOutside
                                ..value = false
                                ..value = await _showPluginSettings(
                                  context,
                                  PM.pluginsData[index]['name'],
                                );
                            },
                            _theme.colorScheme.surfaceContainerHigh,
                            borderRadius: getItemBorderRadius(
                              index,
                              PM.pluginsData.length,
                            ),
                            actions: [
                              IconButton(
                                onPressed: () async {
                                  await _reloadPlugins(PM.pluginsData[index]);
                                  setState(() {});
                                  showToast(
                                    '${PM.pluginsData[index]['name']} (${PM.pluginsData[index]['version']}) ${context.l10n!.updated}!',
                                  );
                                },
                                icon: const Icon(
                                  FluentIcons.arrow_sync_24_filled,
                                ),
                                iconSize: listHeaderIconSize,
                                color: _theme.colorScheme.primary,
                              ),
                              IconButton(
                                onPressed: () async {
                                  canCloseOnTapOutside
                                    ..value = false
                                    ..value =
                                        await showDialog<bool>(
                                          routeSettings: const RouteSettings(
                                            name: '/confirmation',
                                          ),
                                          context: context,
                                          builder:
                                              (context) => ConfirmationDialog(
                                                title:
                                                    context.l10n!.removePlugin,
                                                message:
                                                    context
                                                        .l10n!
                                                        .confirmRemovePlugin,
                                                confirmText:
                                                    context.l10n!.confirm,
                                                cancelText:
                                                    context.l10n!.cancel,
                                                onCancel:
                                                    () =>
                                                        GoRouter.of(
                                                          context,
                                                        ).pop(),
                                                onSubmit: () {
                                                  setState(() {
                                                    PM.removePlugin(
                                                      PM.pluginsData[index]['name'],
                                                    );
                                                  });
                                                  addOrUpdateData(
                                                    'settings',
                                                    'pluginsData',
                                                    PM.pluginsData,
                                                  );
                                                  showToast(
                                                    context.l10n!.pluginRemoved,
                                                  );
                                                  GoRouter.of(context).pop();
                                                },
                                              ),
                                        ) ??
                                        true;
                                },
                                icon: const Icon(FluentIcons.delete_24_regular),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _reloadPlugins(Map? _plugin) async {
    if (_plugin != null)
      await PM.syncPlugin(_plugin);
    else
      await PM.syncPlugins();
  }

  Future<bool> _showPluginSettings(
    BuildContext context,
    String pluginName,
  ) async =>
      await showDialog<bool>(
        routeSettings: RouteSettings(name: '/plugins/$pluginName'),
        context: context,
        builder: (context) {
          try {
            final initSettings = jsonDecode(
              jsonEncode(PM.getUserSettings(pluginName)),
            );
            return ScaffoldMessenger(
              child: Builder(
                builder:
                    (context) => Scaffold(
                      backgroundColor: Colors.transparent,
                      body: StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            contentPadding: commonBarContentPadding,
                            title: Text(pluginName),
                            content: SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: PM.getPluginSettingsWidgets(
                                pluginName,
                                context,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  PM.restSettings(pluginName);
                                  if (context.mounted) setState(() {});
                                },
                                child: Text(
                                  context.l10n!.defaults.toUpperCase(),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  PM.setUserSettings(pluginName, initSettings);
                                  GoRouter.of(context).pop();
                                },
                                child: Text(context.l10n!.cancel.toUpperCase()),
                              ),
                              TextButton(
                                onPressed: () {
                                  GoRouter.of(context).pop();
                                },
                                child: Text(context.l10n!.save.toUpperCase()),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
              ),
            );
          } catch (e, stackTrace) {
            logger.log(
              'Error in ${stackTrace.getCurrentMethodName()}:',
              e,
              stackTrace,
            );
            throw ErrorDescription('Error in _showPluginSettings');
          }
        },
      ) ??
      true;

  Future<bool> _showAddPluginDialog(BuildContext context) async =>
      await showDialog<bool>(
        routeSettings: const RouteSettings(name: '/add-plugins'),
        requestFocus: true,
        context: context,
        builder: (context) {
          var isOnlineMode = true;
          final isLoadedNotifier = ValueNotifier(false);
          var isValid = false;
          var pluginData = {};
          final jsUrlNotifier = ValueNotifier('');
          final urlInputController = TextEditingController();
          return StatefulBuilder(
            builder: (context, setState) {
              final theme = Theme.of(context);
              final activeButtonBackground = theme.colorScheme.surfaceContainer;
              final inactiveButtonBackground =
                  theme.colorScheme.secondaryContainer;
              final dialogBackgroundColor = theme.dialogTheme.backgroundColor;

              return AlertDialog(
                contentPadding: commonBarContentPadding,
                backgroundColor: dialogBackgroundColor,
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                if (mounted)
                                  setState(() {
                                    isOnlineMode = true;
                                  });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isOnlineMode
                                        ? inactiveButtonBackground
                                        : activeButtonBackground,
                              ),
                              child: const Icon(
                                FluentIcons.globe_add_24_filled,
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                if (mounted)
                                  setState(() {
                                    isOnlineMode = false;
                                  });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isOnlineMode
                                        ? activeButtonBackground
                                        : inactiveButtonBackground,
                              ),
                              child: const Icon(
                                FluentIcons.folder_add_24_filled,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        if (isOnlineMode) ...[
                          Text(context.l10n!.onlinePlugin),
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: context.l10n!.pluginURL,
                                  ),
                                  controller: urlInputController,
                                  onChanged: (value) {
                                    jsUrlNotifier.value = value;
                                  },
                                ),
                              ),
                              const SizedBox(width: 7),
                              ValueListenableBuilder(
                                valueListenable: jsUrlNotifier,
                                builder: (context, value, __) {
                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: activeButtonBackground,
                                    ),
                                    onPressed:
                                        value.isNotEmpty
                                            ? () async {
                                              pluginData = await PM
                                                  .getOnlinePlugin(value);
                                              isValid = pluginData.isNotEmpty;
                                              isLoadedNotifier.value =
                                                  pluginData.isNotEmpty;
                                              if (isLoadedNotifier.value)
                                                showToast(
                                                  context.l10n!.pluginLoaded,
                                                );
                                              else
                                                showToast(
                                                  context.l10n!.pluginFailed,
                                                );
                                            }
                                            : null,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          FluentIcons.arrow_download_24_regular,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(context.l10n!.download),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(context.l10n!.localPlugin),
                          const SizedBox(height: 7),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeButtonBackground,
                            ),
                            onPressed: () async {
                              try {
                                pluginData = await PM.getLocalPlugin();
                                isValid = pluginData.isNotEmpty;
                                isLoadedNotifier.value = pluginData.isNotEmpty;
                                if (isLoadedNotifier.value)
                                  showToast(context.l10n!.pluginLoaded);
                                else
                                  showToast(context.l10n!.pluginFailed);
                              } catch (e) {
                                showToast('Error: $e');
                                isLoadedNotifier.value = false;
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(FluentIcons.folder_open_24_regular),
                                const SizedBox(width: 7),
                                Text(context.l10n!.browse),
                              ],
                            ),
                          ),
                        ],
                        ...[
                          const SizedBox(height: 7),
                          ValueListenableBuilder(
                            valueListenable: isLoadedNotifier,
                            builder: (context, value, child) {
                              return Visibility(
                                visible: isValid,
                                child: Text(
                                  '${pluginData['name']} (${pluginData['version']})',
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  ValueListenableBuilder(
                    valueListenable: isLoadedNotifier,
                    builder: (context, value, child) {
                      return TextButton(
                        onPressed:
                            value
                                ? () {
                                  if (isValid) {
                                    setState(() {
                                      PM.addPluginData(pluginData);
                                      addOrUpdateData(
                                        'settings',
                                        'pluginsData',
                                        PM.pluginsData,
                                      );
                                    });
                                    GoRouter.of(context).pop();
                                    showToast(context.l10n!.pluginAdded);
                                  }
                                }
                                : null,
                        child: Text(context.l10n!.add.toUpperCase()),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ) ??
      true;

  void _showLanguagePicker(
    BuildContext context,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    final availableLanguages = appLanguages.keys.toList();
    final activeLanguageCode = Localizations.localeOf(context).languageCode;
    final activeScriptCode = Localizations.localeOf(context).scriptCode;
    final activeLanguageFullCode =
        activeScriptCode != null
            ? '$activeLanguageCode-$activeScriptCode'
            : activeLanguageCode;

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableLanguages.length,
        itemBuilder: (context, index) {
          final language = availableLanguages[index];
          final newLocale = getLocaleFromLanguageCode(appLanguages[language]);
          final newLocaleFullCode =
              newLocale.scriptCode != null
                  ? '${newLocale.languageCode}-${newLocale.scriptCode}'
                  : newLocale.languageCode;

          final borderRadius = getItemBorderRadius(
            index,
            availableLanguages.length,
          );

          return BottomSheetBar(
            language,
            onTap: () {
              addOrUpdateData('settings', 'language', newLocaleFullCode);
              Reverbio.updateAppState(context, newLocale: newLocale);
              showToast(context.l10n!.languageMsg);
              GoRouter.of(context).pop();
            },
            activeLanguageFullCode == newLocaleFullCode
                ? activatedColor
                : inactivatedColor,
            borderRadius: borderRadius,
          );
        },
      ),
    );
  }

  void _showAudioQualityPicker(
    BuildContext context,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    final availableQualities = ['low', 'medium', 'high'];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableQualities.length,
        itemBuilder: (context, index) {
          final quality = availableQualities[index];
          final isCurrentQuality = audioQualitySetting.value == quality;
          final borderRadius = getItemBorderRadius(
            index,
            availableQualities.length,
          );

          return BottomSheetBar(
            quality,
            onTap: () {
              addOrUpdateData('settings', 'audioQuality', quality);
              audioQualitySetting.value = quality;
              showToast(context.l10n!.audioQualityMsg);
              GoRouter.of(context).pop();
            },
            isCurrentQuality ? activatedColor : inactivatedColor,
            borderRadius: borderRadius,
          );
        },
      ),
    );
  }

  void _toggleSystemColor(BuildContext context, bool value) {
    addOrUpdateData('settings', 'useSystemColor', value);
    useSystemColor.value = value;
    Reverbio.updateAppState(
      context,
      newAccentColor: primaryColorSetting,
      useSystemColor: value,
    );
    showToast(context.l10n!.settingChangedMsg);
  }

  void _togglePureBlack(BuildContext context, bool value) {
    addOrUpdateData('settings', 'usePureBlackColor', value);
    usePureBlackColor.value = value;
    Reverbio.updateAppState(context);
    showToast(context.l10n!.settingChangedMsg);
  }

  void _togglePredictiveBack(BuildContext context, bool value) {
    addOrUpdateData('settings', 'predictiveBack', value);
    predictiveBack.value = value;
    transitionsBuilder =
        value
            ? const PredictiveBackPageTransitionsBuilder()
            : const CupertinoPageTransitionsBuilder();
    Reverbio.updateAppState(context);
    showToast(context.l10n!.settingChangedMsg);
  }

  Future<void> _toggleOfflineMode(BuildContext context, bool value) async {
    final shouldSave =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                contentPadding: commonBarContentPadding,
                title: const Text('Offline Mode'),
                content: const Text(
                  'Offline Mode requires a restart. Are you sure you want to exit?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Exit'),
                  ),
                ],
              ),
        ) ??
        false;
    if (shouldSave) {
      showToast(context.l10n!.restartAppMsg);
      addOrUpdateData('settings', 'offlineMode', value);
      offlineMode.value = value;
      Timer(const Duration(milliseconds: 500), () async => exitApp());
    }
  }

  Future<void> exitApp() async {
    try {
      await audioHandler.close();
      if (isMobilePlatform()) {
        await SystemNavigator.pop();
      } else {
        exit(0);
      }
    } catch (e) {
      exit(0);
    }
  }

  void _toggleSponsorBlock(BuildContext context, bool value) {
    addOrUpdateData('settings', 'sponsorBlockSupport', value);
    sponsorBlockSupport.value = value;
    showToast(context.l10n!.settingChangedMsg);
  }

  void _toggleSkipNonMusic(BuildContext context, bool value) {
    addOrUpdateData('settings', 'skipNonMusic', value);
    skipNonMusic.value = value;
    showToast(context.l10n!.settingChangedMsg);
  }

  void _toggleDefaultRecommendations(BuildContext context, bool value) {
    addOrUpdateData('settings', 'defaultRecommendations', value);
    defaultRecommendations.value = value;
    showToast(context.l10n!.settingChangedMsg);
  }

  void _togglePluginsSupport(BuildContext context, bool value) {
    addOrUpdateData('settings', 'pluginsSupport', value);
    enablePlugins.value = value;
    showToast(context.l10n!.settingChangedMsg);
  }

  void _togglePrepareNextSong(BuildContext context, bool value) {
    addOrUpdateData('settings', 'prepareNextSong', value);
    prepareNextSong.value = value;
    showToast(context.l10n!.settingChangedMsg);
  }

  void _toggleUseProxies(BuildContext context, bool value) {
    addOrUpdateData('settings', 'useProxies', value);
    useProxies.value = value;
    showToast(context.l10n!.settingChangedMsg);
  }

  void _showClearSearchHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmText: context.l10n!.clear,
          cancelText: context.l10n!.cancel,
          message: context.l10n!.clearSearchHistoryQuestion,
          onCancel: () => {Navigator.of(context).pop()},
          onSubmit: () {
            searchHistory = [];
            deleteData('user', 'searchHistory');
            Navigator.of(context).pop();
            showToast('${context.l10n!.searchHistoryMsg}!');
          },
        );
      },
    );
  }

  void _showClearRecentlyPlayedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmText: context.l10n!.clear,
          cancelText: context.l10n!.cancel,
          message: context.l10n!.clearRecentlyPlayedQuestion,
          onCancel: () => {Navigator.of(context).pop()},
          onSubmit:
              () => {
                Navigator.of(context).pop(),
                userRecentlyPlayed = [],
                deleteData('user', 'recentlyPlayedSongs'),
                showToast('${context.l10n!.recentlyPlayedMsg}!'),
              },
        );
      },
    );
  }

  Future<void> _backupUserData(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: commonBarContentPadding,
          content: Text(context.l10n!.folderRestrictions),
          actions: <Widget>[
            TextButton(
              child: Text(context.l10n!.understand.toUpperCase()),
              onPressed: () {
                GoRouter.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    final response = await backupData(context);
    showToast(response);
  }
}
