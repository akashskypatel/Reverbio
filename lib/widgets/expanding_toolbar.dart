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

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/utilities/common_variables.dart';

class ExpandingToolbar extends StatefulWidget {
  const ExpandingToolbar({
    super.key,
    required this.actions,
    this.autoCloseSeconds = 5,
  });
  final List<Widget> actions;
  final int autoCloseSeconds;
  @override
  State<ExpandingToolbar> createState() => _ExpandingToolbarState();
}

class _ExpandingToolbarState extends State<ExpandingToolbar>
    with TickerProviderStateMixin {
  late ThemeData _theme;
  bool _expanded = false;
  Timer? _closeTimer;
  final Duration _expandDuration = const Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
  }

  void _toggleToolExpanded() {
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
    _theme = Theme.of(context);
    final expandedConstraint = BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * .75,
    );
    return Row(
      children: [
        if (widget.actions.length > 1)
          Padding(
            padding: commonSingleChildScrollViewPadding,
            child: IconButton(
              icon: Icon(
                _expanded
                    ? FluentIcons.dismiss_24_regular
                    : FluentIcons.more_horizontal_28_filled,
                color: _theme.colorScheme.primary,
              ),
              onPressed: _toggleToolExpanded,
            ),
          ),
        if (widget.actions.isNotEmpty)
          AnimatedSize(
            duration: _expandDuration,
            curve: Curves.easeInOut,
            child:
                _expanded || widget.actions.length == 1
                    ? ConstrainedBox(
                      constraints: expandedConstraint,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding:
                              kDebugMode
                                  ? const EdgeInsetsGeometry.only(right: 24)
                                  : EdgeInsetsGeometry.zero,
                          child: Row(children: widget.actions),
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
