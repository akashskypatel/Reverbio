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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void showCustomBottomSheet(
  BuildContext context,
  Widget content, {
  ValueNotifier<bool>? canCloseOnTapOutside,
}) {
  final size = MediaQuery.sizeOf(context);

  Scaffold.of(context).showBottomSheet(
    enableDrag: true,
    (ctx) => TapRegion(
      onTapOutside: (event) {
        if ((canCloseOnTapOutside == null || canCloseOnTapOutside.value) && GoRouter.of(ctx).canPop())
          GoRouter.of(ctx).pop();
      },
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(vertical: size.height * 0.015),
                child: GestureDetector(
                  onTap: () => GoRouter.of(ctx).pop(ctx),
                  child: Container(
                    width: 60,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.onSecondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: size.height * 0.65),
                child: SingleChildScrollView(child: content),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
