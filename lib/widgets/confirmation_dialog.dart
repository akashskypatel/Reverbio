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
import 'package:reverbio/extensions/l10n.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    this.title,
    this.message,
    required this.confirmText,
    required this.cancelText,
    required this.onCancel,
    required this.onSubmit,
  });
  final String? message;
  final String? title;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title ?? context.l10n!.confirmation),
      content: message != null ? Text(message!) : null,
      actions: <Widget>[
        TextButton(onPressed: onCancel, child: Text(cancelText)),
        TextButton(onPressed: onSubmit, child: Text(confirmText)),
      ],
    );
  }
}
