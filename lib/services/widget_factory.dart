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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/plugins_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/custom_bar.dart';

class WidgetFactory {
  WidgetFactory._();

  static const Map<String, IconData> _iconMap = {
    'access_time': FluentIcons.access_time_24_filled,
    'add': FluentIcons.add_24_filled,
    'alert': FluentIcons.alert_24_filled,
    'arrow_left': FluentIcons.arrow_left_24_filled,
    'arrow_right': FluentIcons.arrow_right_24_filled,
    'calendar': FluentIcons.calendar_24_filled,
    'checkmark': FluentIcons.checkmark_24_filled,
    'chevron_down': FluentIcons.chevron_down_24_filled,
    'close': FluentIcons.dismiss_24_filled,
    'cloud': FluentIcons.cloud_24_filled,
    'cloud_off': FluentIcons.cloud_off_24_filled,
    'cloud_down': FluentIcons.cloud_arrow_down_24_filled,
    'cloud_up': FluentIcons.cloud_arrow_up_24_filled,
    'cloud_check': FluentIcons.cloud_checkmark_24_filled,
    'cloud_dismiss': FluentIcons.cloud_dismiss_24_filled,
    'cloud_sync': FluentIcons.cloud_sync_24_filled,
    'cog': FluentIcons.settings_24_filled,
    'delete': FluentIcons.delete_24_filled,
    'download': FluentIcons.arrow_download_24_filled,
    'edit': FluentIcons.edit_24_filled,
    'email': FluentIcons.mail_24_filled,
    'error': FluentIcons.error_circle_24_filled,
    'eye': FluentIcons.eye_24_filled,
    'eye_off': FluentIcons.eye_off_24_filled,
    'filter': FluentIcons.filter_24_filled,
    'folder': FluentIcons.folder_24_filled,
    'folder_link': FluentIcons.folder_link_24_filled,
    'headphones_wave': FluentIcons.headphones_sound_wave_24_filled,
    'heart': FluentIcons.heart_24_filled,
    'home': FluentIcons.home_24_filled,
    'info': FluentIcons.info_24_filled,
    'key': FluentIcons.key_24_filled,
    'menu': FluentIcons.line_horizontal_3_24_filled,
    'more': FluentIcons.more_vertical_24_filled,
    'notification': FluentIcons.alert_24_filled,
    'person': FluentIcons.person_24_filled,
    'search': FluentIcons.search_24_filled,
    'send': FluentIcons.send_24_filled,
    'share': FluentIcons.share_24_filled,
    'star': FluentIcons.star_24_filled,
    'upload': FluentIcons.arrow_upload_24_filled,
    'warning': FluentIcons.warning_24_filled,
  };

  // R5 fix: Removed unused _buildSettingsMethodCall method

  static Widget _resetFieldButton(VoidCallback onPressed, bool isEnabled) {
    return isEnabled
        ? IconButton(
          onPressed: isEnabled ? onPressed : null,
          icon: const Icon(FluentIcons.arrow_undo_24_regular),
        )
        : isLargeScreen()
        ? const SizedBox.square(dimension: 40)
        : const SizedBox.shrink();
  }

  static final void Function({
    required String pluginName,
    required String id,
    required String label,
    required BuildContext context,
    dynamic methodData,
    dynamic newValue,
    void Function(void Function())? setState,
    dynamic notifier,
    Function? methodParamBuilder,
  })
  _methodBackground = ({
    required pluginName,
    required id,
    required label,
    required context,
    methodData,
    newValue,
    setState,
    notifier,
    methodParamBuilder,
  }) {
    // R8 fix: Check triggerSave before queueing background job
    final triggerSave = methodData?['triggerSave'] ?? false;
    PM.queueBackground(
      pluginName: pluginName,
      priority:
          methodData['priority'] != null
              ? (methodData['priority'] is String
                  ? (int.tryParse(methodData['priority']) ?? 0)
                  : (methodData['priority'] is int
                      ? methodData['priority']
                      : 0))
              : 0,
      methodName:
          methodParamBuilder != null
              ? methodParamBuilder()
              : newValue != null
              ? PM.buildMethodCall(methodData?['methodName'], [
                '{"$id": "$newValue"}',
              ])
              : methodData?['methodName'],
    );
    // R8 fix: Call triggerSave after queueing
    if (triggerSave) PM.updateUserSetting(pluginName, id, newValue.toString());
    showToast(
      '$pluginName - $label ${context.l10n!.addedBackgroundJob}',
      context: context,
    );
    if (context.mounted)
      if (setState != null)
        setState(() {
          notifier?.value = newValue;
        });
      else
        notifier?.value = newValue;
  };

  // R1 fix: Changed typedef from void Function to Future<void> Function for async
  static final Future<void> Function({
    required String pluginName,
    required String id,
    required String label,
    required BuildContext context,
    dynamic methodData,
    dynamic newValue,
    void Function(void Function())? setState,
    dynamic notifier,
    Function? methodParamBuilder,
  })
  _methodAsync = ({
    required pluginName,
    required id,
    required label,
    required context,
    methodData,
    newValue,
    setState,
    notifier,
    methodParamBuilder,
  }) async {
    final triggerSave = methodData?['triggerSave'] ?? false;
    final result = await PM.executeMethodAsync(
      pluginName: pluginName,
      methodName:
          methodParamBuilder != null
              ? methodParamBuilder()
              : newValue != null
              ? PM.buildMethodCall(methodData?['methodName'], [
                '{"$id": "$newValue"}',
              ])
              : methodData?['methodName'],
    );
    if (triggerSave) PM.updateUserSetting(pluginName, id, newValue.toString());
    // R2 fix: Check context.mounted before using context
    if (context.mounted) {
      PM.showPluginMethodResult(
        context,
        pluginName: pluginName,
        message: '${methodData?['methodName']}: $id',
        result: result,
      );
      if (setState != null)
        setState(() {
          notifier?.value = newValue;
        });
      else
        notifier?.value = newValue;
    }
  };

  static final void Function({
    required String pluginName,
    required String id,
    required String label,
    required BuildContext context,
    dynamic methodData,
    dynamic newValue,
    void Function(void Function())? setState,
    dynamic notifier,
    Function? methodParamBuilder,
  })
  _methodSync = ({
    required pluginName,
    required id,
    required label,
    required context,
    methodData,
    newValue,
    setState,
    notifier,
    methodParamBuilder,
  }) {
    final triggerSave = methodData?['triggerSave'] ?? false;
    final result = PM.executeMethod(
      pluginName: pluginName,
      methodName:
          methodParamBuilder != null
              ? methodParamBuilder()
              : newValue != null
              ? PM.buildMethodCall(methodData?['methodName'], [
                '{"$id": "$newValue"}',
              ])
              : methodData?['methodName'],
    );
    if (triggerSave) PM.updateUserSetting(pluginName, id, newValue.toString());
    PM.showPluginMethodResult(
      context,
      pluginName: pluginName,
      message: '${methodData?['methodName']}: $id',
      result: result,
    );
    if (context.mounted)
      if (setState != null)
        setState(() {
          if (notifier is TextEditingController) {
            notifier.text = newValue;
          } else if (notifier is ValueNotifier)
            notifier.value = newValue;
        });
      else {
        if (notifier is TextEditingController) {
          notifier.text = newValue;
        } else if (notifier is ValueNotifier)
          notifier.value = newValue;
      }
  };

  static final void Function({
    required String pluginName,
    required String id,
    required String label,
    required BuildContext context,
    dynamic methodData,
    dynamic newValue,
    void Function(void Function())? setState,
    dynamic notifier,
    Function? methodParamBuilder,
  })
  _method = ({
    required pluginName,
    required id,
    required label,
    required context,
    methodData,
    newValue,
    setState,
    notifier,
    methodParamBuilder,
  }) {
    if (methodData == null) return;
    if (methodData['isBackground'] ?? false)
      _methodBackground(
        pluginName: pluginName,
        id: id,
        label: label,
        context: context,
        methodData: methodData,
        newValue: newValue,
        setState: setState,
        notifier: notifier,
        methodParamBuilder: methodParamBuilder,
      );
    if (methodData['isAsync'] ?? false)
      unawaited(_methodAsync(
        pluginName: pluginName,
        id: id,
        label: label,
        context: context,
        methodData: methodData,
        newValue: newValue,
        setState: setState,
        notifier: notifier,
        methodParamBuilder: methodParamBuilder,
      ));
    _methodSync(
      pluginName: pluginName,
      id: id,
      label: label,
      context: context,
      methodData: methodData,
      newValue: newValue,
      setState: setState,
      notifier: notifier,
      methodParamBuilder: methodParamBuilder,
    );
  };

  static Widget _getSongBarMenuItem({
    required String pluginName,
    required String id,
    required String label,
    required String iconName,
    required BuildContext context,
    Map? methodData,
    Function? getDataFn,
  }) {
    final icon = _iconMap[iconName];
    return PopupMenuItem<String>(
      onTap:
          () => _method(
            pluginName: pluginName,
            methodData: methodData,
            id: id,
            label: label,
            context: context,
            methodParamBuilder:
                () => PM.buildMethodCall(
                  methodData?['methodName'],
                  getDataFn != null ? [getDataFn()] : null,
                ),
          ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, softWrap: true)),
        ],
      ),
    );
  }

  static Widget _getIconButton({
    required String pluginName,
    required String id,
    required String iconName,
    required BuildContext context,
    required double size,
    BorderRadius borderRadius = commonCustomBarRadius,
    String? menuContext,
    Map? methodData,
    Function? getDataFn,
    String? label,
  }) {
    final isSettings = menuContext?.toLowerCase() == 'settings';
    final icon = _iconMap[iconName];
    final button = IconButton(
      tooltip: label,
      onPressed:
          () => _method(
            pluginName: pluginName,
            methodData: methodData,
            id: id,
            label: label ?? '',
            context: context,
            methodParamBuilder:
                () => PM.buildMethodCall(
                  methodData?['methodName'],
                  getDataFn != null ? [getDataFn()] : null,
                ),
          ),
      icon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      iconSize: size,
    );

    if (menuContext?.toLowerCase() == 'settings')
      return CustomBar(
        tileName: isLargeScreen() ? label ?? '' : null,
        tileIcon:
            isLargeScreen()
                ? icon ?? FluentIcons.shifts_availability_24_filled
                : null,
        borderRadius: borderRadius,
        leading:
            !isLargeScreen()
                ? Align(
                  alignment: Alignment.centerRight,  // R4 fix: Removed contradictory isLargeScreen() check
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (label != null && isSettings)
                        Expanded(child: Text(softWrap: true, label)),
                      button,
                    ],
                  ),
                )
                : null,
        trailing:
            isLargeScreen()
                ? Align(
                  alignment: Alignment.centerLeft,  // R4 fix: Removed redundant isLargeScreen() check
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (label != null && isSettings)
                        Expanded(child: Text(softWrap: true, label)),
                      button,
                    ],
                  ),
                )
                : null,
      );
    return button;
  }

  // R11 fix: StatefulWidget to properly dispose ValueNotifier
  static Widget _buildSwitch({
    required String pluginName,
    required String id,
    required String label,
    required BuildContext context,
    Map? methodData,
  }) {
    return _SettingsSwitch(
      pluginName: pluginName,
      id: id,
      label: label,
      methodData: methodData,
    );
  }

  static Widget _getSwitchWidget({
    required String pluginName,
    required String id,
    required String label,
    required BuildContext context,
    BorderRadius borderRadius = commonCustomBarRadius,
    String? iconName,
    Map? methodData,
  }) {
    final icon = _iconMap[iconName];
    return CustomBar(
      tileName: isLargeScreen() ? label : null,
      tileIcon:
          isLargeScreen()
              ? icon ?? FluentIcons.shifts_availability_24_filled
              : null,
      borderRadius: borderRadius,
      trailing:
          isLargeScreen()
              ? _buildSwitch(
                pluginName: pluginName,
                id: id,
                label: label,
                context: context,
                methodData: methodData,
              )
              : null,
      leading:
          !isLargeScreen()
              ? _buildSwitch(
                pluginName: pluginName,
                id: id,
                label: label,
                context: context,
                methodData: methodData,
              )
              : null,
    );
  }

  // R10/R11 fix: StatefulWidget to properly dispose TextEditingController and FocusNode
  static Widget _getTextField({
    required String pluginName,
    required String id,
    required String label,
    required BuildContext context,
    Map? onChangedData,
    Map? onSubmittedData,
    Map? onTapOutsideData,
    Map? onEditingCompleteData,
  }) {
    return _SettingsTextField(
      pluginName: pluginName,
      id: id,
      label: label,
      onChangedData: onChangedData,
      onSubmittedData: onSubmittedData,
      onTapOutsideData: onTapOutsideData,
      onEditingCompleteData: onEditingCompleteData,
    );
  }

  static Widget _getTextInputWidget({
    required String pluginName,
    required String id,
    required String label,
    required BuildContext context,
    BorderRadius borderRadius = commonCustomBarRadius,
    String? iconName,
    Map? onChangedData,
    Map? onSubmittedData,
    Map? onTapOutsideData,
    Map? onEditingCompleteData,
  }) {
    final icon = _iconMap[iconName];
    return CustomBar(
      tileName: isLargeScreen() ? label : null,
      tileIcon: isLargeScreen() ? icon ?? FluentIcons.list_24_filled : null,
      borderRadius: borderRadius,
      leading:
          !isLargeScreen()
              ? _getTextField(
                pluginName: pluginName,
                id: id,
                label: label,
                context: context,
                onChangedData: onChangedData,
                onSubmittedData: onSubmittedData,
                onTapOutsideData: onTapOutsideData,
                onEditingCompleteData: onEditingCompleteData,
              )
              : null,
      trailing:
          isLargeScreen()
              ? _getTextField(
                pluginName: pluginName,
                id: id,
                label: label,
                context: context,
                onChangedData: onChangedData,
                onSubmittedData: onSubmittedData,
                onTapOutsideData: onTapOutsideData,
                onEditingCompleteData: onEditingCompleteData,
              )
              : null,
    );
  }

  static Widget _buildDropdownMenu({
    required String pluginName,
    required String id,
    required String label,
    required List<dynamic> options,
    required BuildContext context,
    Map? methodData,
  }) {
    final settings =
        PM.getUserSettings(pluginName).isEmpty
            ? PM.getDefaultSettings(pluginName)
            : PM.getUserSettings(pluginName);
    // R6 fix: Safe cast with fallback instead of unsafe `as String`
    final defaultValue = settings[id]?.toString() ?? '';
    final controller = TextEditingController(text: defaultValue);
    void Function(void Function())? _setState;
    // R15 fix: Read current default value at reset time instead of capturing stale value
    void resetField() {
      final currentDefault = PM.getDefaultSettings(pluginName)[id]?.toString() ?? '';
      if (controller.value.text != currentDefault) {
        _method(
          pluginName: pluginName,
          methodData: methodData,
          id: id,
          label: label,
          newValue: currentDefault,
          context: context,
          setState: _setState,
          notifier: controller,
        );
      }
    }

    return StatefulBuilder(
      builder: (context, setState) {
        _setState = setState;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resetFieldButton(resetField, controller.text != defaultValue),
            Expanded(
              child: DropdownMenu<String>(
                controller: controller,
                label: isLargeScreen() ? null : Text(label),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                menuStyle: MenuStyle(
                  alignment: Alignment.bottomCenter,
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                initialSelection: defaultValue,
                onSelected:
                    (newValue) => _method(
                      pluginName: pluginName,
                      methodData: methodData,
                      id: id,
                      label: label,
                      newValue: newValue,
                      context: context,
                      setState: _setState,
                      notifier: controller,
                    ),
                dropdownMenuEntries: _getDropdownMenuItems(
                  id: id,
                  pluginName: pluginName,
                  options: options,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _getDropdownMenu({
    required String pluginName,
    required String id,
    required String label,
    required List<dynamic> options,
    required BuildContext context,
    BorderRadius borderRadius = commonCustomBarRadius,
    String? iconName,
    Map? methodData,
  }) {
    final icon = _iconMap[iconName];
    return CustomBar(
      tileName: isLargeScreen() ? label : null,
      tileIcon: isLargeScreen() ? icon ?? FluentIcons.list_24_filled : null,
      borderRadius: borderRadius,
      leading:
          !isLargeScreen()
              ? _buildDropdownMenu(
                pluginName: pluginName,
                id: id,
                label: label,
                context: context,
                options: options,
                methodData: methodData,
              )
              : null,
      trailing:
          isLargeScreen()
              ? _buildDropdownMenu(
                pluginName: pluginName,
                id: id,
                label: label,
                context: context,
                options: options,
                methodData: methodData,
              )
              : null,
    );
  }

  static List<DropdownMenuEntry<String>> _getDropdownMenuItems({
    required String pluginName,
    required String id,
    required List<dynamic> options,
  }) {
    final items = <DropdownMenuEntry<String>>[];
    for (final option in options) {
      items.add(DropdownMenuEntry(value: option, label: option.toString()));
    }
    return items;
  }

  static Widget _buildTextButton({
    required Map methodData,
    required String pluginName,
    required String label,
    required BuildContext context,
    IconData? icon,
  }) {
    return Align(
      alignment: isLargeScreen() ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLargeScreen()) const SizedBox.square(dimension: 40),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
              ),
              onPressed:
                  () => _method(
                    pluginName: pluginName,
                    methodData: methodData,
                    id: label,
                    label: label,
                    context: context,
                  ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    Padding(
                      padding: const EdgeInsetsGeometry.directional(end: 7),
                      child: Icon(icon),
                    ),
                  Expanded(child: Text(softWrap: true, label)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _getTextButtonWidget({
    required Map methodData,
    required String pluginName,
    required String label,
    required BuildContext context,
    BorderRadius borderRadius = commonCustomBarRadiusFirst,
    String? backgroundColor,
    String? iconName,
  }) {
    final icon = _iconMap[iconName];
    return CustomBar(
      tileName: isLargeScreen() ? label : null,
      tileIcon:
          isLargeScreen() ? icon ?? FluentIcons.cursor_hover_24_filled : null,
      borderRadius: borderRadius,
      leading:
          !isLargeScreen()
              ? _buildTextButton(
                methodData: methodData,
                pluginName: pluginName,
                label: label,
                context: context,
                icon: icon,
              )
              : null,
      trailing:
          isLargeScreen()
              ? _buildTextButton(
                methodData: methodData,
                pluginName: pluginName,
                label: label,
                context: context,
                icon: icon,
              )
              : null,
    );
  }

  static Widget getWidget(
    String pluginName,
    Map<String, dynamic> widget,
    BuildContext context,
    Function? getDataFn, {
    BorderRadius borderRadius = commonCustomBarRadiusLast,
  }) {
    switch (widget['type']) {
      case 'TextInput':
        return _getTextInputWidget(
          id: widget['id'],
          label: widget['label'],
          context: context,
          onTapOutsideData: widget['onTapOutside'],
          onSubmittedData: widget['onSubmitted'],
          pluginName: pluginName,
          iconName: widget['icon'],
          borderRadius: borderRadius,
        );
      case 'TextButton':
        return _getTextButtonWidget(
          context: context,
          backgroundColor: widget['backgroundColor'],
          iconName: widget['icon'],
          label: widget['label'],
          methodData: widget['onPressed'],
          pluginName: pluginName,
          borderRadius: borderRadius,
        );
      case 'DropDownMenu':
        return _getDropdownMenu(
          pluginName: pluginName,
          id: widget['id'],
          label: widget['label'],
          context: context,
          options: widget['options'],
          methodData: widget['onSelected'],
          iconName: widget['icon'],
          borderRadius: borderRadius,
        );
      case 'Switch':
        return _getSwitchWidget(
          context: context,
          pluginName: pluginName,
          id: widget['id'],
          label: widget['label'],
          methodData: widget['onChanged'],
          iconName: widget['icon'],
          borderRadius: borderRadius,
        );
      case 'SongBarDropDown':
        return _getSongBarMenuItem(
          context: context,
          pluginName: pluginName,
          id: widget['id'],
          label: widget['label'],
          iconName: widget['icon'],
          methodData: widget['onTap'],
          getDataFn: getDataFn,
        );
      case 'IconButton':
        return _getIconButton(
          size: listHeaderIconSize,
          context: context,
          menuContext: widget['context'],
          pluginName: pluginName,
          id: widget['id'],
          label: widget['label'],
          iconName: widget['icon'],
          methodData: widget['onPressed'],
          borderRadius: borderRadius,
        );
      case 'SongListHeader':
      case 'AlbumPageHeader':
      case 'ArtistPageHeader':
      case 'AlbumsPageHeader':
      case 'ArtistsPageHeader':
      case 'PlaylistPageHeader':
        return _getIconButton(
          size: listHeaderIconSize,
          context: context,
          pluginName: pluginName,
          id: widget['id'],
          label: widget['label'],
          iconName: widget['icon'],
          methodData: widget['onPressed'],
          getDataFn: getDataFn,
          borderRadius: borderRadius,
        );
      default:
        return IconButton(
          onPressed: null,
          icon: const Icon(FluentIcons.error_circle_24_filled),
          tooltip: context.l10n!.invalidPluginWidget,
          disabledColor: Theme.of(context).colorScheme.onError,
        );
    }
  }

  static const pluginWidgets = {
    'TextInput': {'context': 'settings'},
    'TextButton': {'context': 'settings'},
    'Switch': {'context': 'settings'},
    'DropDownMenu': {'context': 'settings'},
    'IconButton': {'context': 'any'},
    'SongBarDropDown': {'context': 'song_bar'},
    'SongListHeader': {'context': 'song_list'},
    'AlbumPageHeader': {'context': 'album_header'},
    'ArtistPageHeader': {'context': 'artist_header'},
    'AlbumsPageHeader': {'context': 'albums_header'},
    'ArtistsPageHeader': {'context': 'artists_header'},
    'PlaylistPageHeader': {'context': 'playlist_header'},
  };

  static Widget getAllSettingsWidgets(
    String pluginName,
    List<Map<String, dynamic>> widgets,
    BuildContext context,
  ) {
    // R3 fix: Filter widgets FIRST, then compute border radius
    widgets =
        widgets
            .where(
              (e) => [
                'settings',
                'any',
              ].contains(pluginWidgets[e['type']]?['context']),
            )
            .toList();

    final radius = {
      0: commonCustomBarRadiusFirst,
      if (widgets.isNotEmpty) widgets.length - 1: commonCustomBarRadiusLast,
    };

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: commonListViewBottomPadding,
      itemCount: widgets.length,
      itemBuilder:
          (_, index) => getWidget(
            pluginName,
            widgets[index],
            context,
            null,
            borderRadius: radius[index] ?? BorderRadius.zero,
          ),
    );
  }
}

// R10/R11 fix: StatefulWidget to properly dispose TextEditingController and FocusNode
class _SettingsTextField extends StatefulWidget {
  const _SettingsTextField({
    required this.pluginName,
    required this.id,
    required this.label,
    this.onChangedData,
    this.onSubmittedData,
    this.onTapOutsideData,
    this.onEditingCompleteData,
  });
  final String pluginName;
  final String id;
  final String label;
  final Map? onChangedData;
  final Map? onSubmittedData;
  final Map? onTapOutsideData;
  final Map? onEditingCompleteData;

  @override
  State<_SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<_SettingsTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  void Function(void Function())? _setState;

  @override
  void initState() {
    super.initState();
    final settings =
        PM.getUserSettings(widget.pluginName).isEmpty
            ? PM.getDefaultSettings(widget.pluginName)
            : PM.getUserSettings(widget.pluginName);
    final defaultValue = settings[widget.id]?.toString() ?? '';
    _controller = TextEditingController(text: defaultValue);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    // R10 fix: Dispose TextEditingController and FocusNode
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetField(methodData) {
    final settings =
        PM.getUserSettings(widget.pluginName).isEmpty
            ? PM.getDefaultSettings(widget.pluginName)
            : PM.getUserSettings(widget.pluginName);
    final defaultValue = settings[widget.id]?.toString() ?? '';
    if (_controller.value.text != defaultValue) {
      WidgetFactory._method(
        pluginName: widget.pluginName,
        methodData: methodData,
        id: widget.id,
        label: widget.label,
        newValue: defaultValue,
        context: context,
        setState: _setState,
        notifier: _controller,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        _setState = setState;
        final settings =
            PM.getUserSettings(widget.pluginName).isEmpty
                ? PM.getDefaultSettings(widget.pluginName)
                : PM.getUserSettings(widget.pluginName);
        final defaultValue = settings[widget.id]?.toString() ?? '';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WidgetFactory._resetFieldButton(
              () => _resetField(widget.onSubmittedData),
              _controller.text != defaultValue,
            ),
            Expanded(
              child: Align(
                alignment:
                    isLargeScreen()
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                child: TextField(
                  decoration:
                      !isLargeScreen()
                          ? InputDecoration(
                            label: Text(widget.label),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                          : const InputDecoration(),
                  focusNode: _focusNode,
                  controller: _controller,
                  onEditingComplete: () {
                    WidgetFactory._method(
                      pluginName: widget.pluginName,
                      methodData: widget.onEditingCompleteData,
                      id: widget.id,
                      label: widget.label,
                      newValue: _controller.text,
                      context: context,
                      setState: _setState,
                      notifier: _controller,
                    );
                    _focusNode.unfocus();
                  },
                  onChanged:
                      (newValue) => WidgetFactory._method(
                        pluginName: widget.pluginName,
                        methodData: widget.onChangedData,
                        id: widget.id,
                        label: widget.label,
                        newValue: _controller.text,
                        context: context,
                        setState: _setState,
                        notifier: _controller,
                      ),
                  onTapOutside: (event) {
                    WidgetFactory._method(
                      pluginName: widget.pluginName,
                      methodData: widget.onTapOutsideData,
                      id: widget.id,
                      label: widget.label,
                      newValue: _controller.text,
                      context: context,
                      setState: _setState,
                      notifier: _controller,
                    );
                    _focusNode.unfocus();
                  },
                  onSubmitted: (newValue) {
                    WidgetFactory._method(
                      pluginName: widget.pluginName,
                      methodData: widget.onSubmittedData,
                      id: widget.id,
                      label: widget.label,
                      newValue: _controller.text,
                      context: context,
                      setState: _setState,
                      notifier: _controller,
                    );
                    _focusNode.unfocus();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// R11 fix: StatefulWidget to properly dispose ValueNotifier
class _SettingsSwitch extends StatefulWidget {
  const _SettingsSwitch({
    required this.pluginName,
    required this.id,
    required this.label,
    this.methodData,
  });
  final String pluginName;
  final String id;
  final String label;
  final Map? methodData;

  @override
  State<_SettingsSwitch> createState() => _SettingsSwitchState();
}

class _SettingsSwitchState extends State<_SettingsSwitch> {
  late ValueNotifier<bool> _switchNotifier;
  void Function(void Function())? _setState;

  @override
  void initState() {
    super.initState();
    final settings =
        PM.getUserSettings(widget.pluginName).isEmpty
            ? PM.getDefaultSettings(widget.pluginName)
            : PM.getUserSettings(widget.pluginName);
    final defaultValue =
        settings[widget.id] is String
            ? settings[widget.id] == 'true'
            : (settings[widget.id] ?? false);
    _switchNotifier = ValueNotifier(defaultValue);
  }

  @override
  void dispose() {
    // R11 fix: Dispose ValueNotifier
    _switchNotifier.dispose();
    super.dispose();
  }

  void _resetField() {
    final currentDefault =
        PM.getDefaultSettings(widget.pluginName)[widget.id] is String
            ? PM.getDefaultSettings(widget.pluginName)[widget.id] == 'true'
            : (PM.getDefaultSettings(widget.pluginName)[widget.id] ?? false);
    if (_switchNotifier.value != currentDefault) {
      WidgetFactory._method(
        pluginName: widget.pluginName,
        methodData: widget.methodData,
        id: widget.id,
        label: widget.label,
        newValue: currentDefault,
        context: context,
        setState: _setState,
        notifier: _switchNotifier,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbIcon =
        WidgetStateProperty<Icon>.fromMap(<WidgetStatesConstraint, Icon>{
          WidgetState.selected: Icon(
            FluentIcons.checkmark_24_filled,
            color: Theme.of(context).colorScheme.primary,
          ),
          WidgetState.any: Icon(
            FluentIcons.dismiss_24_filled,
            color: Theme.of(context).colorScheme.primary,
          ),
        });
    return StatefulBuilder(
      builder: (context, setState) {
        _setState = setState;
        return ValueListenableBuilder(
          valueListenable: _switchNotifier,
          builder: (context, value, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isLargeScreen())
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsGeometry.directional(end: 10),
                    child: Text(softWrap: true, widget.label),
                  ),
                ),
              WidgetFactory._resetFieldButton(_resetField, value != _switchNotifier.value),
              Expanded(
                child: Align(
                  alignment:
                      isLargeScreen()
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                  child: Switch(
                    thumbIcon: thumbIcon,
                    value: value,
                    onChanged:
                        (newValue) => WidgetFactory._method(
                          pluginName: widget.pluginName,
                          methodData: widget.methodData,
                          id: widget.id,
                          label: widget.label,
                          newValue: newValue,
                          context: context,
                          setState: _setState,
                          notifier: _switchNotifier,
                        ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
