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
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
import 'package:reverbio/widgets/playlist_bar.dart';

class OfflinePlaylistsPage extends StatefulWidget {
  const OfflinePlaylistsPage({super.key});

  @override
  _OfflinePlaylistsPageState createState() => _OfflinePlaylistsPageState();
}

class _OfflinePlaylistsPageState extends State<OfflinePlaylistsPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final List<PlaylistBar> userPlaylistBars = [];
  ValueNotifier<bool> isFilteredNotifier = ValueNotifier(false);
  late ThemeData _theme;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n!.offlinePlaylists),
        actions: [_clearFiltersButton()],
      ),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Align(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[_buildSearchBar(), _buildPlaylistListView()],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistListView() {
    _buildPlaylistBars();
    return ValueListenableBuilder(
      valueListenable: currentOfflinePlaylistsLength,
      builder:
          (context, value, child) => ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: userPlaylistBars.length,
            padding: commonListViewBottomPadding,
            itemBuilder: (context, index) {
              return _getPlaylistBar(index);
            },
          ),
    );
  }

  Widget _getPlaylistBar(index) {
    final playlist = userOfflinePlaylists[index];
    final bar = PlaylistBar(
      key: ValueKey(playlist['id']),
      playlist['title'],
      playlistId: playlist['id'],
      playlistArtwork: playlist['image'],
      playlistData: playlist,
      borderRadius: getItemBorderRadius(index, userOfflinePlaylists.length),
      onDelete: () {
        removeOfflinePlaylist(playlist);
        if (mounted) setState(() {});
      },
    );
    userPlaylistBars.add(bar);
    return bar;
  }

  void _buildPlaylistBars() {
    for (final playlist in userOfflinePlaylists) {
      userPlaylistBars.add(
        PlaylistBar(
          key: ValueKey(playlist['id']),
          playlist['title'],
          playlistId: playlist['id'],
          playlistArtwork: playlist['image'],
          playlistData: playlist,
          onDelete: () {
            removeOfflinePlaylist(playlist);
            if (mounted) setState(() {});
          },
        ),
      );
    }
  }

  Widget _buildSearchBar() {
    return CustomSearchBar(
      searchDelayMs: 0,
      controller: _searchBar,
      focusNode: _inputNode,
      labelText: '${context.l10n!.search}...',
      onSubmitted: (String value) {
        _inputNode.unfocus();
      },
      onChanged: (String value) {
        _filterPlaylistBars(value);
      },
    );
  }

  void _filterPlaylistBars(String query) {
    if (query.isEmpty) {
      for (final widget in userPlaylistBars) {
        widget.setVisibility(true);
        isFilteredNotifier.value = false;
      }
    } else {
      for (final widget in userPlaylistBars) {
        final searchStr = widget.playlistTitle;
        if (searchStr.isNotEmpty && !searchStr.toLowerCase().contains(query)) {
          widget.setVisibility(false);
          isFilteredNotifier.value = true;
        }
      }
    }
  }

  Widget _clearFiltersButton() {
    return ValueListenableBuilder(
      valueListenable: isFilteredNotifier,
      builder: (context, value, __) {
        return IconButton(
          onPressed:
              isFilteredNotifier.value
                  ? () {
                    _searchBar.clear();
                    _filterPlaylistBars('');
                    isFilteredNotifier.value = false;
                  }
                  : null,
          icon: const Icon(FluentIcons.filter_dismiss_24_filled, size: 30),
          iconSize: pageHeaderIconSize,
          color: _theme.colorScheme.primary,
          disabledColor: _theme.colorScheme.primaryContainer,
        );
      },
    );
  }
}
