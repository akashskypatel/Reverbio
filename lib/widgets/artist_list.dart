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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/widgets/spinner.dart';

class ArtistList extends StatefulWidget {
  const ArtistList({
    super.key,
    required this.page,
    required this.notifiableArtistList,
    required this.child,
  });
  final NotifiableList notifiableArtistList;
  final String page;
  final Widget child;

  @override
  State<ArtistList> createState() => _ArtistListState();
}

class _ArtistListState extends State<ArtistList> {
  late ThemeData _theme;
  bool isOpen = true;

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final maxWidth = MediaQuery.of(context).size.width * .15;
    final maxHeight = MediaQuery.of(context).size.height;
    final remWidth =
        MediaQuery.of(context).size.width -
        (maxWidth / 2) -
        listHeaderIconSize -
        (isOpen ? maxWidth : 0);
    return ListenableBuilder(
      listenable: widget.notifiableArtistList,
      builder: (context, child) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            //animated drawer
            _buildAnimatedContainer(),
            //adjacent widget
            Row(
              children: [
                //Drawer slide
                _buildDrawerSlide(),
                widget.child,
                LimitedBox(maxWidth: remWidth, maxHeight: maxHeight, child: widget.child,),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedContainer() {
    final maxWidth = MediaQuery.of(context).size.width * .15;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isOpen ? maxWidth : 0,
      alignment: Alignment.topLeft,
      child:
          widget.notifiableArtistList.isLoading
              ? const Padding(
                padding: commonListViewBottomPadding,
                child: Spinner(),
              )
              : _buildColumnArtistTiles(),
    );
  }

  Widget _buildDrawerSlide() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: listHeaderIconSize),
      child: GestureDetector(
        onTap: () {
          setState(() {
            isOpen = !isOpen;
          });
        },
        child: Container(
          alignment: Alignment.center,
          width: listHeaderIconSize,
          decoration: BoxDecoration(
            color: _theme.colorScheme.primary.withValues(alpha: 0.1),
            border: Border(
              left: BorderSide(
                color: _theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Icon(
            isOpen
                ? FluentIcons.chevron_left_24_filled
                : FluentIcons.chevron_right_24_filled,
            color: _theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildColumnArtistTiles() {
    return CustomScrollView(
      shrinkWrap: true,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...widget.notifiableArtistList.map(
                (e) => ListTile(
                  dense: true,
                  onTap: () {},
                  title: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      overflow: TextOverflow.ellipsis,
                      e['name'] ?? e['artist'] ?? context.l10n!.unknown,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListViewArtistTiles() {
    return ListView.builder(
      itemCount: widget.notifiableArtistList.length,
      itemBuilder: (context, index) {
        final e = widget.notifiableArtistList[index];
        return ListTile(
          dense: true,
          onTap: () {},
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              overflow: TextOverflow.ellipsis,
              e['name'] ?? e['artist'] ?? context.l10n!.unknown,
            ),
          ),
        );
      },
    );
  }
}
