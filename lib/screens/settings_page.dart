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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
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
import 'package:reverbio/widgets/section_header.dart';

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
          context.l10n!.accentColor,
          FluentIcons.color_24_filled,
          onTap: () => _showAccentColorPicker(context),
        ),
        CustomBar(
          context.l10n!.themeMode,
          FluentIcons.weather_sunny_28_filled,
          onTap:
              () => _showThemeModePicker(
                context,
                activatedColor,
                inactivatedColor,
              ),
        ),
        CustomBar(
          context.l10n!.client,
          FluentIcons.device_meeting_room_24_filled,
          onTap:
              () =>
                  _showClientPicker(context, activatedColor, inactivatedColor),
        ),
        CustomBar(
          context.l10n!.language,
          FluentIcons.translate_24_filled,
          onTap:
              () => _showLanguagePicker(
                context,
                activatedColor,
                inactivatedColor,
              ),
        ),
        CustomBar(
          context.l10n!.audioQuality,
          Icons.music_note,
          onTap:
              () => _showAudioQualityPicker(
                context,
                activatedColor,
                inactivatedColor,
              ),
        ),
        CustomBar(
          context.l10n!.dynamicColor,
          FluentIcons.toggle_left_24_filled,
          trailing: Switch(
            value: useSystemColor.value,
            onChanged: (value) => _toggleSystemColor(context, value),
          ),
        ),
        if (themeMode == ThemeMode.dark)
          CustomBar(
            context.l10n!.pureBlackTheme,
            FluentIcons.color_background_24_filled,
            trailing: Switch(
              value: usePureBlackColor.value,
              onChanged: (value) => _togglePureBlack(context, value),
            ),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: predictiveBack,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.predictiveBack,
              FluentIcons.position_backward_24_filled,
              trailing: Switch(
                value: value,
                onChanged: (value) => _togglePredictiveBack(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: offlineMode,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.offlineMode,
              FluentIcons.cellular_off_24_regular,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleOfflineMode(context, value),
              ),
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
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.sponsorBlock,
              FluentIcons.presence_blocked_24_regular,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSponsorBlock(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: skipNonMusic,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.nonMusicBlock,
              FluentIcons.skip_forward_tab_24_regular,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSkipNonMusic(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: playNextSongAutomatically,
          builder: (_, value, __) {
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
        ValueListenableBuilder<bool>(
          valueListenable: defaultRecommendations,
          builder: (_, value, __) {
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
        ValueListenableBuilder<bool>(
          valueListenable: pluginsSupport,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.plugins,
              value
                  ? FluentIcons.plug_connected_24_regular
                  : FluentIcons.plug_disconnected_24_regular,
              borderRadius: commonCustomBarRadiusLast,
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
        _buildToolsSection(context),
        _buildSponsorSection(context, primaryColor),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(title: context.l10n!.tools),
        CustomBar(
          context.l10n!.clearCache,
          FluentIcons.broom_24_filled,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () {
            clearCache();
            showToast(context, '${context.l10n!.cacheMsg}!');
          },
        ),
        CustomBar(
          context.l10n!.clearSearchHistory,
          FluentIcons.history_24_filled,
          onTap: () => _showClearSearchHistoryDialog(context),
        ),
        CustomBar(
          context.l10n!.clearRecentlyPlayed,
          FluentIcons.receipt_play_24_filled,
          onTap: () => _showClearRecentlyPlayedDialog(context),
        ),
        CustomBar(
          context.l10n!.backupUserData,
          FluentIcons.cloud_sync_24_filled,
          onTap: () => _backupUserData(context),
        ),
        CustomBar(
          context.l10n!.restoreUserData,
          FluentIcons.cloud_add_24_filled,
          onTap: () async {
            final response = await restoreData(context);
            showToast(context, response);
          },
        ),
        if (!isFdroidBuild)
          CustomBar(
            context.l10n!.downloadAppUpdate,
            FluentIcons.arrow_download_24_filled,
            borderRadius: commonCustomBarRadiusLast,
            onTap: () => checkAppUpdates,
          ),
      ],
    );
  }

  Widget _buildSponsorSection(BuildContext context, Color primaryColor) {
    return Column(
      children: [
        SectionHeader(title: context.l10n!.becomeSponsor),
        CustomBar(
          context.l10n!.sponsorProject,
          FluentIcons.heart_24_filled,
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
          context.l10n!.licenses,
          FluentIcons.document_24_filled,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () => NavigationManager.router.go('/settings/license'),
        ),
        CustomBar(
          '${context.l10n!.copyLogs} (${logger.getLogCount()})',
          FluentIcons.error_circle_24_filled,
          onTap: () async => showToast(context, await logger.copyLogs(context)),
        ),
        CustomBar(
          context.l10n!.about,
          FluentIcons.book_information_24_filled,
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
              //TODO: migrate this
              addOrUpdateData(
                'settings',
                'accentColor',
                // ignore: deprecated_member_use
                color.value,
              );
              Reverbio.updateAppState(
                context,
                newAccentColor: color,
                useSystemColor: false,
              );
              showToast(context, context.l10n!.accentChangeMsg);
              GoRouter.of(context).pop(context);
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
                  Icon(Icons.check, color: _theme.colorScheme.onPrimary),
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
        padding: commonListViewBottmomPadding,
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
              GoRouter.of(context).pop(context);
            },
            themeMode == mode ? activatedColor : inactivatedColor,
            borderRadius: borderRadius,
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
            padding: commonListViewBottmomPadding,
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
    showCustomBottomSheet(
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
                        onPressed: _showAddPluginDialog,
                        icon: const Icon(FluentIcons.add_24_regular),
                        iconSize: listHeaderIconSize,
                        color: _theme.colorScheme.primary,
                      ),
                    ],
                  ),
                  ValueListenableBuilder(
                    valueListenable: PM.pluginsDataNotifier,
                    builder: (_, value, ___) {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        padding: commonListViewBottmomPadding,
                        itemCount: PM.pluginsData.length,
                        itemBuilder: (savecontext, index) {
                          return BottomSheetBar(
                            '${PM.pluginsData[index]['name']} (${PM.pluginsData[index]['version']})',
                            onTap:
                                () => _showPluginSettings(
                                  PM.pluginsData[index]['name'],
                                ),
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
                                    context,
                                    '${PM.pluginsData[index]['name']} (${PM.pluginsData[index]['version']}) updated!',
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
                                  await showDialog(
                                    routeSettings: const RouteSettings(
                                      name: '/confirmation',
                                    ),
                                    context: savecontext,
                                    builder:
                                        (
                                          BuildContext confirmcontext,
                                        ) => ConfirmationDialog(
                                          title: context.l10n!.removePlugin,
                                          message:
                                              context.l10n!.confirmRemovePlugin,
                                          confirmText: context.l10n!.confirm,
                                          cancelText: context.l10n!.cancel,
                                          onCancel:
                                              () => GoRouter.of(
                                                savecontext,
                                              ).pop(confirmcontext),
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
                                              context,
                                              context.l10n!.pluginRemoved,
                                            );
                                            GoRouter.of(context).pop(context);
                                          },
                                        ),
                                  );
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

  void _showPluginSettings(String pluginName) => showDialog(
    routeSettings: RouteSettings(name: '/plugins/$pluginName'),
    context: context,
    builder: (pluginContext) {
      try {
        return StatefulBuilder(
          builder: (plugincontext, setState) {
            return AlertDialog(
              title: Text(pluginName),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                child: PM.getPluginSettingsWidgets(pluginName, pluginContext),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    PM.restSettings(pluginName);
                    setState(() {});
                  },
                  child: Text(context.l10n!.defaults.toUpperCase()),
                ),
                TextButton(
                  onPressed: () {
                    GoRouter.of(plugincontext).pop(plugincontext);
                  },
                  child: Text(context.l10n!.cancel.toUpperCase()),
                ),
                TextButton(
                  onPressed: () {
                    PM.saveSettings(pluginName);
                    GoRouter.of(plugincontext).pop(plugincontext);
                  },
                  child: Text(context.l10n!.save.toUpperCase()),
                ),
              ],
            );
          },
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
  );

  void _showAddPluginDialog() => showDialog(
    routeSettings: const RouteSettings(name: '/add-plugins'),
    context: context,
    builder: (savecontext) {
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
          final inactiveButtonBackground = theme.colorScheme.secondaryContainer;
          final dialogBackgroundColor = theme.dialogTheme.backgroundColor;

          return AlertDialog(
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
                          child: const Icon(FluentIcons.globe_add_24_filled),
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
                          child: const Icon(FluentIcons.folder_add_24_filled),
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
                            builder: (_, value, __) {
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: activeButtonBackground,
                                ),
                                onPressed:
                                    value.isNotEmpty
                                        ? () async {
                                          pluginData = await PM.getOnlinePlugin(
                                            value,
                                          );
                                          isValid = pluginData.isNotEmpty;
                                          isLoadedNotifier.value =
                                              pluginData.isNotEmpty;
                                          if (isLoadedNotifier.value)
                                            showToast(
                                              context,
                                              context.l10n!.pluginLoaded,
                                            );
                                          else
                                            showToast(
                                              context,
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
                              showToast(context, context.l10n!.pluginLoaded);
                            else
                              showToast(context, context.l10n!.pluginFailed);
                          } catch (e) {
                            showToast(context, 'Error: $e');
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
                                GoRouter.of(context).pop(context);
                                showToast(context, context.l10n!.pluginAdded);
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
  );

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
        padding: commonListViewBottmomPadding,
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
              showToast(context, context.l10n!.languageMsg);
              GoRouter.of(context).pop(context);
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
        padding: commonListViewBottmomPadding,
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
              showToast(context, context.l10n!.audioQualityMsg);
              GoRouter.of(context).pop(context);
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
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePureBlack(BuildContext context, bool value) {
    addOrUpdateData('settings', 'usePureBlackColor', value);
    usePureBlackColor.value = value;
    Reverbio.updateAppState(context);
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePredictiveBack(BuildContext context, bool value) {
    addOrUpdateData('settings', 'predictiveBack', value);
    predictiveBack.value = value;
    transitionsBuilder =
        value
            ? const PredictiveBackPageTransitionsBuilder()
            : const CupertinoPageTransitionsBuilder();
    Reverbio.updateAppState(context);
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleOfflineMode(BuildContext context, bool value) {
    addOrUpdateData('settings', 'offlineMode', value);
    offlineMode.value = value;
    showToast(context, context.l10n!.restartAppMsg);
  }

  void _toggleSponsorBlock(BuildContext context, bool value) {
    addOrUpdateData('settings', 'sponsorBlockSupport', value);
    sponsorBlockSupport.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleSkipNonMusic(BuildContext context, bool value) {
    addOrUpdateData('settings', 'skipNonMusic', value);
    skipNonMusic.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleDefaultRecommendations(BuildContext context, bool value) {
    addOrUpdateData('settings', 'defaultRecommendations', value);
    defaultRecommendations.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePluginsSupport(BuildContext context, bool value) {
    addOrUpdateData('settings', 'pluginsSupport', value);
    pluginsSupport.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
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
          onSubmit:
              () => {
                Navigator.of(context).pop(),
                searchHistory = [],
                deleteData('user', 'searchHistory'),
                showToast(context, '${context.l10n!.searchHistoryMsg}!'),
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
                showToast(context, '${context.l10n!.recentlyPlayedMsg}!'),
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
          content: Text(context.l10n!.folderRestrictions),
          actions: <Widget>[
            TextButton(
              child: Text(context.l10n!.understand.toUpperCase()),
              onPressed: () {
                GoRouter.of(context).pop(context);
              },
            ),
          ],
        );
      },
    );
    final response = await backupData(context);
    showToast(context, response);
  }
}
