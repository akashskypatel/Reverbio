import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_bottom_sheet.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/bottom_sheet_bar.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

Future<void> showNotificationLog(BuildContext context) async {
  final _theme = Theme.of(context);
  final inactivatedColor = _theme.colorScheme.surfaceContainerHigh;
  showCustomBottomSheet(
    context,
    StatefulBuilder(
      builder: (context, setState) {
        final _logList =
            notificationLog.entries.map((entry) {
                return {'index': entry.value['index'], 'id': entry.key};
              }).toList()
              ..sort((a, b) => a['index'].compareTo(b['index']));
        final _logKeys = _logList.map((e) => e['id']).toList();
        return Column(
          children: [
            SectionHeader(
              title: context.l10n!.notifications,
              expandedActions: [
                IconButton(
                  onPressed: () async {
                    notificationLog.removeWhere(
                      (key, value) => !(value['data'] is ValueNotifier<int>),
                    );
                    if (context.mounted) setState(() {});
                  },
                  icon: const Icon(Icons.clear_all),
                  iconSize: listHeaderIconSize,
                  color: _theme.colorScheme.primary,
                ),
              ],
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: commonListViewBottomPadding,
              itemCount: _logKeys.length,
              itemBuilder: (context, index) {
                final notification = notificationLog[_logKeys[index]];
                final borderRadius = getItemBorderRadius(
                  index,
                  _logKeys.length,
                );
                final progress = notificationLog[notification['id']]?['data'];
                final message = notification['message'];
                final dateTime = notification['dateTime'];
                if (progress is ValueNotifier<int>) {
                  return ValueListenableBuilder(
                    valueListenable: progress,
                    builder: (context, value, child) {
                      final action = Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.square(
                            dimension: 35,
                            child: Spinner(value: value / 100),
                          ),
                          Text('$value%'),
                        ],
                      );
                      return BottomSheetBar(
                        '$message · ${dateTime != null ? formatRelativeTime(dateTime) : ''}',
                        inactivatedColor,
                        borderRadius: borderRadius,
                        actions: [action],
                      );
                    },
                  );
                } else {
                  final action = IconButton(
                    icon: const Icon(FluentIcons.dismiss_24_filled),
                    onPressed: () {
                      notificationLog.remove(_logKeys[index]);
                      if (context.mounted)
                        setState(() {
                          notificationLogLength.value = notificationLog.length;
                        });
                    },
                  );
                  return BottomSheetBar(
                    '$message · ${dateTime != null ? formatRelativeTime(dateTime) : ''}',
                    inactivatedColor,
                    borderRadius: borderRadius,
                    actions: [action],
                  );
                }
              },
            ),
          ],
        );
      },
    ),
  );
}
