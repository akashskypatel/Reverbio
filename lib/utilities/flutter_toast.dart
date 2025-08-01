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
import 'package:reverbio/services/router_service.dart';

const _toastDuration = Duration(seconds: 3);

void showToast(String text, {BuildContext? context}) {
  context = context ?? NavigationManager().context;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      behavior: SnackBarBehavior.floating,
      content: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.inverseSurface),
      ),
      duration: _toastDuration,
    ),
  );
}

void showToastWithButton(
  String text,
  String buttonName,
  VoidCallback onPressedToast, {
  BuildContext? context,
}) {
  context = context ?? NavigationManager().context;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      content: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.inverseSurface),
      ),
      action: SnackBarAction(
        label: buttonName,
        textColor: Theme.of(context).colorScheme.secondary,
        onPressed: () => onPressedToast(),
      ),
      duration: _toastDuration,
    ),
  );
}
