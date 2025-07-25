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

import 'package:flutter/material.dart';
import 'package:reverbio/utilities/common_variables.dart';

class CustomBar extends StatelessWidget {
  CustomBar(
    this.tileName,
    this.tileIcon, {
    super.key,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
    this.borderRadius = BorderRadius.zero,
  });
  final ValueNotifier<bool> _isLoadingNotifieir = ValueNotifier(false);
  final String tileName;
  final IconData tileIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final BorderRadius borderRadius;

  bool isLoading(bool isLoading) {
    _isLoadingNotifieir.value = isLoading;
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
              leading: Icon(tileIcon, color: iconColor),
              title: Text(
                tileName,
                style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
              ),
              trailing: trailing,
            ),
          ),
        ),
      ),
    );
  }
}
