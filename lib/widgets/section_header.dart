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
import 'package:flutter/material.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/widgets/section_title.dart';

class SectionHeader extends StatefulWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actions,
    this.autoCloseSeconds = 5,
    this.actionsExpanded = false,
    this.expandedActions,
    this.showSearch = false,
    this.searchController,
  });

  final String title;
  final List<Widget>? actions;
  final int autoCloseSeconds;
  final bool actionsExpanded;
  final List<Widget>? expandedActions;
  final bool showSearch;
  final SearchController? searchController;
  @override
  State<SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<SectionHeader>
    with TickerProviderStateMixin {
  late ThemeData _theme;
  bool _expanded = false;
  Timer? _closeTimer;
  bool _searchExpanded = false;

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
    _theme = Theme.of(context);
    final expandedConstraint = BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * .55,
    );
    return Row(
      children: [
        Flexible(
          fit: FlexFit.tight,
          child: ClipRect(
            child: SectionTitle(widget.title, _theme.colorScheme.primary),
          ),
        ),

        if (widget.showSearch && widget.searchController != null)
          _buildSearchActionButton(expandedConstraint),
        if (widget.actions != null &&
            widget.actions!.isNotEmpty &&
            !widget.actionsExpanded)
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
        if (widget.actionsExpanded && widget.actions != null)
          ConstrainedBox(
            constraints: expandedConstraint,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: widget.actions!),
            ),
          ),
        if (!widget.actionsExpanded && widget.actions != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child:
                _expanded && widget.actions != null
                    ? ConstrainedBox(
                      constraints: expandedConstraint,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: widget.actions!),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        if (widget.expandedActions != null &&
            widget.expandedActions!.isNotEmpty)
          Row(children: widget.expandedActions!),
      ],
    );
  }

  Widget _buildSearchActionButton(BoxConstraints expandedConstraint) {
    return AnimatedCrossFade(
      crossFadeState:
          _searchExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
      firstChild: IconButton(
        tooltip: context.l10n!.shuffle,
        color: _theme.colorScheme.primary,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        icon: const Icon(FluentIcons.search_24_filled),
        iconSize: listHeaderIconSize,
        onPressed: () {},
      ),
      secondChild: SearchBar(
        constraints: BoxConstraints(
          maxHeight: listHeaderIconSize,
          maxWidth: expandedConstraint.maxWidth,
        ),
        controller: widget.searchController,
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 5),
        ),
        onTap: () {
          // Expands when tapped
          widget.searchController!.openView();
        },
        onChanged: (_) {
          widget.searchController!.openView();
        },
        leading: IconButton(
          iconSize: listHeaderIconSize,
          icon: const Icon(FluentIcons.search_24_filled),
          onPressed: () {
            widget.searchController!.openView();
          },
        ),
        trailing: [
          IconButton(
            iconSize: listHeaderIconSize,
            icon: const Icon(FluentIcons.dismiss_24_filled),
            onPressed: () {
              widget.searchController!.closeView(null);
            },
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}
