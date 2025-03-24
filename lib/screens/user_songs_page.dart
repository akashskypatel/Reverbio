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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/playlist_header.dart';
import 'package:reverbio/widgets/song_bar.dart';

class UserSongsPage extends StatefulWidget {
  const UserSongsPage({
    super.key,
    required this.page,
    required this.navigatorObserver,
  });

  final String page;
  final RouteObserver<PageRoute> navigatorObserver;

  @override
  State<UserSongsPage> createState() => _UserSongsPageState();
}

class _UserSongsPageState extends State<UserSongsPage> with RouteAware {
  bool _isEditEnabled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    widget.navigatorObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the RouteObserver
    final route = ModalRoute.of(context);
    if (route != null) {
      widget.navigatorObserver.subscribe(this, route as PageRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = getTitle(widget.page, context);
    final icon = getIcon(widget.page);
    final songsList = getSongsList(widget.page);
    final length = getLength(widget.page);

    return Scaffold(
      appBar: AppBar(
        title: offlineMode.value ? Text(title) : null,
        actions: [
          if (title == context.l10n!.likedSongs)
            IconButton(
              onPressed: () {
                if (mounted)
                  setState(() {
                    _isEditEnabled = !_isEditEnabled;
                  });
              },
              icon: Icon(
                FluentIcons.re_order_24_filled,
                color:
                    _isEditEnabled
                        ? Theme.of(context).colorScheme.inversePrimary
                        : Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
      body: _buildCustomScrollView(title, icon, songsList, length),
    );
  }

  Widget _buildCustomScrollView(
    String title,
    IconData icon,
    List songsList,
    ValueNotifier length,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: buildPlaylistHeader(title, icon, songsList.length),
          ),
        ),
        buildSongList(title, songsList, length),
      ],
    );
  }

  String getTitle(String page, BuildContext context) {
    return {
          'liked': context.l10n!.likedSongs,
          'offline': context.l10n!.offlineSongs,
          'recents': context.l10n!.recentlyPlayed,
          'queue': context.l10n!.queue,
        }[page] ??
        context.l10n!.playlist;
  }

  IconData getIcon(String page) {
    return {
          'liked': FluentIcons.heart_24_regular,
          'offline': FluentIcons.cellular_off_24_regular,
          'recents': FluentIcons.history_24_regular,
          'queue': Icons.queue_music,
        }[page] ??
        FluentIcons.heart_24_regular;
  }

  List getSongsList(String page) {
    return {
          'liked': userLikedSongsList,
          'offline': userOfflineSongs,
          'recents': userRecentlyPlayed,
          'queue': null,
        }[page] ??
        userLikedSongsList;
  }

  ValueNotifier<int> getLength(String page) {
    return {
          'liked': currentLikedSongsLength,
          'offline': currentOfflineSongsLength,
          'recents': currentRecentlyPlayedLength,
          'queue': null,
        }[page] ??
        currentLikedSongsLength;
  }

  Widget buildPlaylistHeader(String title, IconData icon, int songsLength) {
    return PlaylistHeader(_buildPlaylistImage(title, icon), title, songsLength);
  }

  Widget _buildPlaylistImage(String title, IconData icon) {
    return BaseCard(
      inputData: {'title': title},
      size: MediaQuery.sizeOf(context).width / 2.5,
      icon: icon,
    );
  }

  Widget buildSongList(
    String title,
    List songsList,
    ValueNotifier currentSongsLength,
  ) {
    final _playlist = {
      'ytid': '',
      'title': title,
      'source': 'user-created',
      'list': songsList,
    };
    return ValueListenableBuilder(
      valueListenable: currentSongsLength,
      builder: (_, value, __) {
        if (title == context.l10n!.likedSongs) {
          return SliverReorderableList(
            itemCount: songsList.length,
            itemBuilder: (context, index) {
              final song = songsList[index];

              final borderRadius = getItemBorderRadius(index, songsList.length);

              return ReorderableDragStartListener(
                enabled: _isEditEnabled,
                key: Key(song['ytid'].toString()),
                index: index,
                child: SongBar(
                  song,
                  true,
                  onPlay:
                      () => {
                        audioHandler.playPlaylistSong(
                          playlist:
                              activePlaylist != _playlist ? _playlist : null,
                          songIndex: index,
                        ),
                      },
                  borderRadius: borderRadius,
                ),
              );
            },
            onReorder: (oldIndex, newIndex) {
              if (mounted)
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  moveLikedSong(oldIndex, newIndex);
                });
            },
          );
        } else {
          return SliverList(
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              final song = songsList[index];
              song['isOffline'] = title == context.l10n!.offlineSongs;

              final borderRadius = getItemBorderRadius(index, songsList.length);

              return SongBar(
                song,
                true,
                onPlay:
                    () => {
                      audioHandler.playPlaylistSong(
                        playlist:
                            activePlaylist != _playlist ? _playlist : null,
                        songIndex: index,
                      ),
                    },
                borderRadius: borderRadius,
              );
              // ignore: require_trailing_commas
            }, childCount: songsList.length),
          );
        }
      },
    );
  }
}
