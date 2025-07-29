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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/plugins_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/custom_bar.dart';

typedef PM = PluginsManager;

class WidgetFactory {
  WidgetFactory._();

  static final Map<String, IconData> _iconMap = {
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
  static String _buildSettingsMethodCall({
    required String methodName,
    required String value,
    required String id,
  }) {
    return '$methodName({"$id": "$value"})';
  }

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
    showToast('$pluginName - $label added to background queue.');
    if (context.mounted)
      if (setState != null)
        setState(() {
          notifier?.value = newValue;
        });
      else
        notifier?.value = newValue;
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
    PM.showPluginMethodResult(
      pluginName: pluginName,
      message: '${methodData?['methodName']}: $id',
      result: result,
    );
    showToast('$pluginName - $label added to background queue.');
    if (context.mounted)
      if (setState != null)
        setState(() {
          notifier?.value = newValue;
        });
      else
        notifier?.value = newValue;
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
      return _methodBackground(
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
      return _methodAsync(
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
    return _methodSync(
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
    final icon = _iconMap[iconName];
    final button = Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 40),
          IconButton(
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
          ),
        ],
      ),
    );
    if (menuContext?.toLowerCase() == 'settings')
      return CustomBar(
        tileName: label ?? '',
        tileIcon: icon ?? FluentIcons.shifts_availability_24_filled,
        borderRadius: borderRadius,
        trailing: button,
      );
    return button;
  }

  static Widget _buildSwitch({
    required String pluginName,
    required String id,
    required String label,
    required BuildContext context,
    Map? methodData,
  }) {
    final defaultValue =
        PM.getUserSettings(pluginName)[id] is String
            ? PM.getUserSettings(pluginName)[id] == 'true'
            : (PM.getUserSettings(pluginName)[id] ?? false);
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
    final switchNotifier = ValueNotifier(defaultValue);
    void Function(void Function())? _setState;
    void resetField() {
      if (switchNotifier.value != defaultValue) {
        _method(
          pluginName: pluginName,
          methodData: methodData,
          id: id,
          label: label,
          newValue: defaultValue,
          context: context,
          setState: _setState,
          notifier: switchNotifier,
        );
      }
    }

    return StatefulBuilder(
      builder: (context, setState) {
        _setState = setState;
        return ValueListenableBuilder(
          valueListenable: switchNotifier,
          builder:
              (context, value, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isLargeScreen())
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsGeometry.directional(end: 10),
                        child: Text(softWrap: true, label),
                      ),
                    ),
                  _resetFieldButton(resetField, value != defaultValue),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        thumbIcon: thumbIcon,
                        value: value,
                        onChanged:
                            (newValue) => _method(
                              pluginName: pluginName,
                              methodData: methodData,
                              id: id,
                              label: label,
                              newValue: newValue,
                              context: context,
                              setState: _setState,
                              notifier: switchNotifier,
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
    final defaultValue = PM.getUserSettings(pluginName)[id] ?? '';
    final controller = TextEditingController(text: defaultValue as String);
    final focusNode = FocusNode();
    void Function(void Function())? _setState;
    void resetField(methodData) {
      if (controller.value.text != defaultValue) {
        _method(
          pluginName: pluginName,
          methodData: methodData,
          id: id,
          label: label,
          newValue: defaultValue,
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
            _resetFieldButton(
              () => resetField(onSubmittedData),
              controller.text != defaultValue,
            ),
            Expanded(
              child: TextField(
                decoration:
                    !isLargeScreen()
                        ? InputDecoration(
                          label: Text(label),
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                        : const InputDecoration(),
                focusNode: focusNode,
                controller: controller,
                onEditingComplete: () {
                  _method(
                    pluginName: pluginName,
                    methodData: onEditingCompleteData,
                    id: id,
                    label: label,
                    newValue: controller.text,
                    context: context,
                    setState: _setState,
                    notifier: controller,
                  );
                  focusNode.unfocus();
                },
                onChanged:
                    (newValue) => _method(
                      pluginName: pluginName,
                      methodData: onChangedData,
                      id: id,
                      label: label,
                      newValue: controller.text,
                      context: context,
                      setState: _setState,
                      notifier: controller,
                    ),
                onTapOutside: (event) {
                  _method(
                    pluginName: pluginName,
                    methodData: onTapOutsideData,
                    id: id,
                    label: label,
                    newValue: controller.text,
                    context: context,
                    setState: _setState,
                    notifier: controller,
                  );
                  focusNode.unfocus();
                },
                onSubmitted: (newValue) {
                  _method(
                    pluginName: pluginName,
                    methodData: onSubmittedData,
                    id: id,
                    label: label,
                    newValue: controller.text,
                    context: context,
                    setState: _setState,
                    notifier: controller,
                  );
                  focusNode.unfocus();
                },
              ),
            ),
          ],
        );
      },
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
    final defaultValue = PM.getUserSettings(pluginName)[id];
    final controller = TextEditingController(text: defaultValue as String);
    void Function(void Function())? _setState;
    void resetField() {
      if (controller.value.text != defaultValue) {
        _method(
          pluginName: pluginName,
          methodData: methodData,
          id: id,
          label: label,
          newValue: defaultValue,
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
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
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
                if (icon != null) Icon(icon),
                const SizedBox(width: 7),
                Text(label),
              ],
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

  static Widget getAllSettingsWidgets(
    String pluginName,
    List<Map<String, dynamic>> widgets,
  ) {
    final radius = {
      0: commonCustomBarRadiusFirst,
      widgets.length - 1: commonCustomBarRadiusLast,
    };
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: commonListViewBottomPadding,
      itemCount: widgets.length,
      itemBuilder:
          (context, index) => getWidget(
            pluginName,
            widgets[index],
            context,
            null,
            borderRadius: radius[index] ?? BorderRadius.zero,
          ),
    );
  }
}
