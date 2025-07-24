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
    final isBackground =
        methodData == null ? false : methodData['isBackground'];
    return PopupMenuItem<String>(
      onTap:
          methodData == null
              ? null
              : isBackground
              ? () {
                final data = getDataFn != null ? [getDataFn()] : null;
                PM.queueBackground(
                  pluginName: pluginName,
                  methodName: PM.buildMethodCall(
                    methodData['methodName'],
                    data,
                  ),
                  message: '$pluginName - $label',
                );
                showToast('$pluginName - $label added to background queue.');
              }
              : methodData['isAsync']
              ? () async {
                final data = getDataFn != null ? [getDataFn()] : null;
                final result = await PM.executeMethodAsync(
                  pluginName: pluginName,
                  methodName: PM.buildMethodCall(
                    methodData['methodName'],
                    data,
                  ),
                );
                PM.showPluginMethodResult(
                  pluginName: pluginName,
                  message: methodData['methodName'],
                  result: result,
                );
              }
              : () {
                final data = getDataFn != null ? [getDataFn()] : null;
                final (result, _) = PM.executeMethod(
                  pluginName: pluginName,
                  methodName: PM.buildMethodCall(
                    methodData['methodName'],
                    data,
                  ),
                );
                PM.showPluginMethodResult(
                  pluginName: pluginName,
                  message: methodData['methodName'],
                  result: result,
                );
              },
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(label),
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
    final button = IconButton(
      tooltip: label,
      onPressed:
          methodData == null
              ? null
              : methodData['isBackground'] ?? false
              ? () {
                final data = getDataFn != null ? [getDataFn()] : null;
                PM.queueBackground(
                  pluginName: pluginName,
                  methodName: PM.buildMethodCall(
                    methodData['methodName'],
                    data,
                  ),
                );
                showToast('$pluginName - $label added to background queue.');
              }
              : methodData['isAsync'] ?? false
              ? () async {
                final data = getDataFn != null ? [getDataFn()] : null;
                final (result, _) = await PM.executeMethodAsync(
                  pluginName: pluginName,
                  methodName: PM.buildMethodCall(
                    methodData['methodName'],
                    data,
                  ),
                );
                PM.showPluginMethodResult(
                  pluginName: pluginName,
                  message: methodData['methodName'],
                  result: result,
                );
              }
              : () {
                final data = getDataFn != null ? [getDataFn()] : null;
                final (result, _) = PM.executeMethod(
                  pluginName: pluginName,
                  methodName: PM.buildMethodCall(
                    methodData['methodName'],
                    data,
                  ),
                );
                PM.showPluginMethodResult(
                  pluginName: pluginName,
                  message: methodData['methodName'],
                  result: result,
                );
              },
      icon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      iconSize: size,
    );
    if (menuContext?.toLowerCase() == 'settings')
      return CustomBar(
        label ?? '',
        icon ?? FluentIcons.shifts_availability_24_filled,
        borderRadius: borderRadius,
        trailing: button,
      );
    return button;
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
    final defaultValue = PM.getUserSettings(pluginName)[id] == 'true';
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
    final icon = _iconMap[iconName];
    return CustomBar(
      label,
      icon ?? FluentIcons.shifts_availability_24_filled,
      borderRadius: borderRadius,
      trailing: ValueListenableBuilder(
        valueListenable: switchNotifier,
        builder:
            (context, value, __) => Switch(
              thumbIcon: thumbIcon,
              value: value,
              onChanged:
                  methodData == null
                      ? null
                      : methodData['isBackground'] ?? false
                      ? (newValue) {
                        PM.queueBackground(
                          pluginName: pluginName,
                          methodName: _buildSettingsMethodCall(
                            methodName: methodData['methodName'],
                            value: newValue.toString(),
                            id: id,
                          ),
                        );
                        showToast(
                          '$pluginName - $label added to background queue.',
                        );
                      }
                      : methodData['isAsync'] ?? false
                      ? (newValue) async {
                        final (result, _) = await PM.executeMethodAsync(
                          pluginName: pluginName,
                          methodName: _buildSettingsMethodCall(
                            methodName: methodData['methodName'],
                            value: newValue.toString(),
                            id: id,
                          ),
                        );
                        PM.showPluginMethodResult(
                          pluginName: pluginName,
                          message: methodData['methodName'],
                          result: result,
                        );
                        switchNotifier.value = newValue;
                      }
                      : (newValue) {
                        final (result, _) = PM.executeMethod(
                          pluginName: pluginName,
                          methodName: _buildSettingsMethodCall(
                            methodName: methodData['methodName'],
                            value: newValue.toString(),
                            id: id,
                          ),
                        );
                        PM.showPluginMethodResult(
                          pluginName: pluginName,
                          message: methodData['methodName'],
                          result: result,
                        );
                        switchNotifier.value = newValue;
                      },
            ),
      ),
    );
  }

  static Widget _getTextInputWidget({
    required String pluginName,
    required String id,
    required String label,
    BorderRadius borderRadius = commonCustomBarRadius,
    String? iconName,
    Map? onChangedData,
    Map? onSubmittedData,
    Map? onTapOutsideData,
    Map? onEditingCompleteData,
  }) {
    final defaultValue = PM.getUserSettings(pluginName)[id];
    final controller = TextEditingController(text: defaultValue as String);
    final focusNode = FocusNode();
    final icon = _iconMap[iconName];
    return CustomBar(
      label,
      icon ?? FluentIcons.text_add_20_filled,
      borderRadius: borderRadius,
      trailing: LayoutBuilder(
        builder:
            (context, constraints) => ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.65,
                minWidth: constraints.maxWidth * 0.65,
              ),
              child: TextField(
                focusNode: focusNode,
                controller: controller,
                onEditingComplete:
                    onEditingCompleteData == null
                        ? null
                        : onEditingCompleteData['isBackground'] ?? false
                        ? () {
                          PM.queueBackground(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onEditingCompleteData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          showToast(
                            '$pluginName - $label added to background queue.',
                          );
                        }
                        : onEditingCompleteData['isAsync'] ?? false
                        ? () async {
                          final (result, _) = await PM.executeMethodAsync(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onEditingCompleteData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          PM.showPluginMethodResult(
                            pluginName: pluginName,
                            message: onEditingCompleteData['methodName'],
                            result: result,
                          );
                        }
                        : () {
                          final (result, _) = PM.executeMethod(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onEditingCompleteData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          PM.showPluginMethodResult(
                            pluginName: pluginName,
                            message: onEditingCompleteData['methodName'],
                            result: result,
                          );
                        },
                onChanged:
                    onChangedData == null
                        ? null
                        : onChangedData['isBackground'] ?? false
                        ? (event) {
                          PM.queueBackground(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onChangedData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          showToast(
                            '$pluginName - $label added to background queue.',
                          );
                        }
                        : onChangedData['isAsync'] ?? false
                        ? (event) async {
                          final (result, _) = await PM.executeMethodAsync(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onChangedData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          PM.showPluginMethodResult(
                            pluginName: pluginName,
                            message: onChangedData['methodName'],
                            result: result,
                          );
                        }
                        : (value) {
                          final (result, _) = PM.executeMethod(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onChangedData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          PM.showPluginMethodResult(
                            pluginName: pluginName,
                            message: onChangedData['methodName'],
                            result: result,
                          );
                        },
                onTapOutside:
                    onTapOutsideData == null
                        ? null
                        : onTapOutsideData['isBackground'] ?? false
                        ? (event) {
                          PM.queueBackground(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onTapOutsideData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          showToast(
                            '$pluginName - $label added to background queue.',
                          );
                        }
                        : onTapOutsideData['isAsync'] ?? false
                        ? (event) async {
                          final (result, _) = await PM.executeMethodAsync(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onTapOutsideData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          PM.showPluginMethodResult(
                            pluginName: pluginName,
                            message: onTapOutsideData['methodName'],
                            result: result,
                          );
                          focusNode.unfocus();
                        }
                        : (event) {
                          final (result, _) = PM.executeMethod(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onTapOutsideData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          PM.showPluginMethodResult(
                            pluginName: pluginName,
                            message: onTapOutsideData['methodName'],
                            result: result,
                          );
                          focusNode.unfocus();
                        },
                onSubmitted:
                    onSubmittedData == null
                        ? null
                        : onSubmittedData['isBackground'] ?? false
                        ? (value) {
                          PM.queueBackground(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onSubmittedData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          showToast(
                            '$pluginName - $label added to background queue.',
                          );
                        }
                        : onSubmittedData['isAsync'] ?? false
                        ? (value) async {
                          final (result, _) = await PM.executeMethodAsync(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onSubmittedData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          PM.showPluginMethodResult(
                            pluginName: pluginName,
                            message: onSubmittedData['methodName'],
                            result: result,
                          );
                        }
                        : (value) {
                          final (result, _) = PM.executeMethod(
                            pluginName: pluginName,
                            methodName: _buildSettingsMethodCall(
                              methodName: onSubmittedData['methodName'],
                              value: controller.text,
                              id: id,
                            ),
                          );
                          PM.showPluginMethodResult(
                            pluginName: pluginName,
                            message: onSubmittedData['methodName'],
                            result: result,
                          );
                        },
              ),
            ),
      ),
    );
  }

  static Widget _getDropdownMenu({
    required String pluginName,
    required String id,
    required String label,
    required List<dynamic> options,
    BorderRadius borderRadius = commonCustomBarRadius,
    String? iconName,
    Map? methodData,
  }) {
    final defaultValue = PM.getUserSettings(pluginName)[id];
    final icon = _iconMap[iconName];
    return CustomBar(
      label,
      icon ?? FluentIcons.list_24_filled,
      borderRadius: borderRadius,
      trailing: DropdownMenu<String>(
        initialSelection: defaultValue,
        onSelected:
            methodData == null
                ? null
                : methodData['isBackground'] ?? false
                ? (value) {
                  PM.queueBackground(
                    pluginName: pluginName,
                    methodName: _buildSettingsMethodCall(
                      methodName: methodData['methodName'],
                      value: value.toString(),
                      id: id,
                    ),
                  );
                  showToast('$pluginName - $label added to background queue.');
                }
                : methodData['isAsync'] ?? false
                ? (value) async {
                  final (result, _) = await PM.executeMethodAsync(
                    pluginName: pluginName,
                    methodName: _buildSettingsMethodCall(
                      methodName: methodData['methodName'],
                      value: value.toString(),
                      id: id,
                    ),
                  );
                  PM.showPluginMethodResult(
                    pluginName: pluginName,
                    message: methodData['methodName'],
                    result: result,
                  );
                }
                : (value) {
                  final (result, _) = PM.executeMethod(
                    pluginName: pluginName,
                    methodName: _buildSettingsMethodCall(
                      methodName: methodData['methodName'],
                      value: value.toString(),
                      id: id,
                    ),
                  );
                  PM.showPluginMethodResult(
                    pluginName: pluginName,
                    message: methodData['methodName'],
                    result: result,
                  );
                },
        dropdownMenuEntries: _getDropdownMenuItems(
          id: id,
          pluginName: pluginName,
          options: options,
        ),
      ),
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

  static Widget _getTextButtonWidget({
    required Map methodData,
    required String pluginName,
    required String label,
    BorderRadius borderRadius = commonCustomBarRadiusFirst,
    String? backgroundColor,
    String? iconName,
  }) {
    final icon = _iconMap[iconName];
    return CustomBar(
      label,
      icon ?? FluentIcons.cursor_hover_24_filled,
      borderRadius: borderRadius,
      trailing: ElevatedButton(
        onPressed:
            methodData['isBackground'] ?? false
                ? () {
                  PM.queueBackground(
                    pluginName: pluginName,
                    methodName: methodData['methodName'],
                  );
                  showToast('$pluginName - $label added to background queue.');
                }
                : methodData['isAsync'] ?? false
                ? () async {
                  final (result, _) = await PM.executeMethodAsync(
                    pluginName: pluginName,
                    methodName: methodData['methodName'],
                  );
                  PM.showPluginMethodResult(
                    pluginName: pluginName,
                    message: methodData['methodName'],
                    result: result,
                  );
                }
                : () {
                  final (result, _) = PM.executeMethod(
                    pluginName: pluginName,
                    methodName: methodData['methodName'],
                  );
                  PM.showPluginMethodResult(
                    pluginName: pluginName,
                    message: methodData['methodName'],
                    result: result,
                  );
                },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon),
            const SizedBox(width: 7),
            Text(label),
          ],
        ),
      ),
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
          onTapOutsideData: widget['onTapOutside'],
          onSubmittedData: widget['onSubmitted'],
          pluginName: pluginName,
          iconName: widget['icon'],
          borderRadius: borderRadius,
        );
      case 'TextButton':
        return _getTextButtonWidget(
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
      padding: commonListViewBottmomPadding,
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
