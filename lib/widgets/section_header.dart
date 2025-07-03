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
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/widgets/section_title.dart';

class SectionHeader extends StatefulWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actions,
    this.autoCloseSeconds = 5,
  });

  final String title;
  final List<Widget>? actions;
  final int autoCloseSeconds;
  @override
  State<SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<SectionHeader>
    with TickerProviderStateMixin {
  late final _theme = Theme.of(context);
  bool _expanded = false;
  Timer? _closeTimer;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });

    _closeTimer?.cancel();

    if (_expanded) {
      _closeTimer = Timer(Duration(seconds: widget.autoCloseSeconds), () {
        if (mounted) {
          setState(() {
            _expanded = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          fit: FlexFit.tight,
          child: ClipRect(
            child: SectionTitle(
              widget.title,
              _theme.colorScheme.primary,
            ),
          ),
        ),
        if (widget.actions != null && widget.actions!.isNotEmpty)
          Padding(
            padding: commonSingleChildScrollViewPadding,
            child: IconButton(
              icon: Icon(
                _expanded
                    ? FluentIcons.dismiss_24_regular
                    : FluentIcons.more_horizontal_28_filled,
                color: _theme.colorScheme.primary,
              ),
              onPressed: _toggleExpanded,
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child:
              _expanded && widget.actions != null
                  ? Row(children: widget.actions!)
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
