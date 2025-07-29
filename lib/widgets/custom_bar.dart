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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:reverbio/utilities/common_variables.dart';

class CustomBar extends StatelessWidget {
  CustomBar({
    this.tileName,
    this.tileIcon,
    super.key,
    this.onTap,
    this.onLongPress,
    this.leading,
    this.trailing,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
    this.borderRadius = BorderRadius.zero,
  });
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final String? tileName;
  final IconData? tileIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final BorderRadius borderRadius;

  bool isLoading(bool isLoading) {
    _isLoadingNotifier.value = isLoading;
    return isLoading;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: commonBarPadding,
      child: Card(
        margin: const EdgeInsets.only(bottom: 3),
        color: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
          child: InkWell(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: onTap,
            onLongPress: onLongPress,
            child: ListTile(
              minTileHeight: 45,
              leading: LayoutBuilder(
                builder:
                    (context, constraints) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tileIcon != null) Icon(tileIcon, color: iconColor),
                        if (leading != null)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: max(constraints.maxWidth - 1, 0),
                            ),
                            child: leading,
                          ),
                      ],
                    ),
              ),
              title: LayoutBuilder(
                builder:
                    (context, constraints) => ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: max((constraints.maxWidth * 0.25) - 1, 0),
                      ),
                      child:
                          tileName != null
                              ? Text(
                                tileName!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
              ),
              trailing: LayoutBuilder(
                builder:
                    (context, constraints) => ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: max((constraints.maxWidth * 0.75) - 1, 0),
                      ),
                      child: trailing,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
