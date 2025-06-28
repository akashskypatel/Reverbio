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

class BottomSheetBar extends StatelessWidget {
  const BottomSheetBar(
    this.title,
    this.backgroundColor, {
      this.onTap,
    this.borderRadius = BorderRadius.zero,
    this.actions,
    super.key,
  });
  final String title;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      margin: const EdgeInsets.only(bottom: 3),
      child: Padding(
        padding: commonBarContentPadding,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: onTap == null ? Colors.transparent : null,
          onTap: onTap,
          child: ListTile(
            minTileHeight: 45,
            title: Text(title),
            trailing:
                actions != null
                    ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
                    : null,
          ),
        ),
      ),
    );
  }
}
