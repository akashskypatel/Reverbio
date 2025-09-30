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
    this.onChanged,
  });

  final String title;
  final List<Widget>? actions;
  final int autoCloseSeconds;
  final bool actionsExpanded;
  final List<Widget>? expandedActions;
  final bool showSearch;
  final void Function(String)? onChanged;

  @override
  State<SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<SectionHeader>
    with TickerProviderStateMixin {
  late ThemeData _theme;
  bool _toolsExpanded = false;
  Timer? _toolCloseTimer;
  bool _searchExpanded = false;
  Timer? searchCloseTimer;
  final Duration _expandDuration = const Duration(milliseconds: 300);
  SearchController? searchController;

  @override
  void initState() {
    super.initState();
    if (widget.showSearch) searchController = SearchController();
  }

  void _toggleToolExpanded() {
    setState(() {
      _toolsExpanded = !_toolsExpanded;
      _searchExpanded = false;
    });

    _toolCloseTimer?.cancel();

    if (_toolsExpanded) {
      _toolCloseTimer = Timer(Duration(seconds: widget.autoCloseSeconds), () {
        if (mounted) {
          setState(() {
            _toolsExpanded = false;
          });
        }
      });
    }
  }

  void _toggleSearchExpanded({bool? isOpen}) {
    setState(() {
      _toolsExpanded = false;
      _searchExpanded = isOpen ?? !_searchExpanded;
    });

    searchCloseTimer?.cancel();

    if (_searchExpanded) {
      searchCloseTimer = Timer(Duration(seconds: widget.autoCloseSeconds), () {
        if (mounted) {
          setState(() {
            _searchExpanded = false;
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

        if (widget.showSearch) _buildSearchActionButton(expandedConstraint),
        if (widget.actions != null &&
            widget.actions!.isNotEmpty &&
            !widget.actionsExpanded)
          Padding(
            padding: commonSingleChildScrollViewPadding,
            child: IconButton(
              icon: Icon(
                _toolsExpanded
                    ? FluentIcons.dismiss_24_regular
                    : FluentIcons.more_horizontal_28_filled,
                color: _theme.colorScheme.primary,
              ),
              onPressed: _toggleToolExpanded,
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
            duration: _expandDuration,
            curve: Curves.easeInOut,
            child:
                _toolsExpanded && widget.actions != null
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
      sizeCurve: Curves.easeInOut,
      duration: _expandDuration,
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
        onPressed: _toggleSearchExpanded,
      ),
      secondChild: AnimatedSize(
        curve: Curves.easeInOut,
        duration: _expandDuration,
        child:
            _searchExpanded
                ? SearchBar(
                  constraints: BoxConstraints(
                    maxHeight: listHeaderIconSize + 16,
                    maxWidth: expandedConstraint.maxWidth,
                  ),
                  controller: searchController,
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    _toggleSearchExpanded(isOpen: true);
                    if (widget.onChanged != null) widget.onChanged!(value);
                  },
                  leading: IconButton(
                    color: _theme.colorScheme.primary,
                    iconSize: listHeaderIconSize,
                    icon: const Icon(FluentIcons.search_24_filled),
                    onPressed: () {},
                  ),
                  trailing: [
                    IconButton(
                      iconSize: listHeaderIconSize,
                      color: _theme.colorScheme.primary,
                      icon: const Icon(FluentIcons.dismiss_24_filled),
                      onPressed: () {
                        _toggleSearchExpanded(isOpen: false);
                        searchController?.clear();
                        if (widget.onChanged != null) widget.onChanged!('');
                      },
                    ),
                  ],
                )
                : const SizedBox.shrink(),
      ),
    );
  }
}
