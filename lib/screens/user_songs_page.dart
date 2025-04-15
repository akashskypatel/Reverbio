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
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/mini_player.dart';
import 'package:reverbio/widgets/playlist_header.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:reverbio/widgets/song_list.dart';

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
        title: Text(title), //offlineMode.value ? Text(title) : null,
        actions: [
          if (title == context.l10n!.queue)
            Row(
              children: [
                //TODO: define actions
                _buildQueueActionsList(),
                const SizedBox(width: 24, height: 24),
              ],
            ),
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

  Widget _buildQueueActionsList() {
    return ValueListenableBuilder(
      valueListenable: activeQueueLength,
      builder: (_, value, __) {
        return Row(
          children: [
            IconButton(
              tooltip: context.l10n!.addToPlaylist,
              onPressed: value == 0 ? null : _showExistingPlaylists,
              disabledColor: Theme.of(context).colorScheme.inversePrimary,
              color: Theme.of(context).colorScheme.primary,
              icon: const Icon(Icons.playlist_add),
            ),
            IconButton(
              tooltip: context.l10n!.saveAsPlayList,
              onPressed: value == 0 ? null : _showSaveAsPlaylistDialog,
              disabledColor: Theme.of(context).colorScheme.inversePrimary,
              color: Theme.of(context).colorScheme.primary,
              icon: const Icon(FluentIcons.add_24_filled),
            ),
            IconButton(
              tooltip: context.l10n!.clearQueue,
              onPressed:
                  value == 0
                      ? null
                      : () {
                        clearSongQueue();
                        showToast(context, 'Queue cleared!');
                      },
              disabledColor: Theme.of(context).colorScheme.inversePrimary,
              color: Theme.of(context).colorScheme.primary,
              icon: const Icon(Icons.clear_all),
            ),
          ],
        );
      },
    );
  }

  void _showExistingPlaylists() => showDialog(
    context: context,
    builder: (BuildContext savecontext) {
      // Moved state management outside StatefulBuilder
      final allPlaylists = getPlaylistNames(); // Your original playlist

      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final dialogBackgroundColor = theme.dialogTheme.backgroundColor;
          List<String> filteredPlaylists = allPlaylists;
          final ValueNotifier<int> listLengthNotifier = ValueNotifier(
            filteredPlaylists.length,
          );
          void filterPlaylists(String query) {
            filteredPlaylists =
                allPlaylists.where((playlist) {
                  return playlist.toLowerCase().contains(query.toLowerCase());
                }).toList();
            listLengthNotifier.value = filteredPlaylists.length;
          }

          return AlertDialog(
            backgroundColor: dialogBackgroundColor,
            content: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: 200,
                height: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextField(
                        onChanged: filterPlaylists,
                        decoration: const InputDecoration(
                          hintText: 'Search playlists...',
                          prefixIcon: Icon(Icons.search),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          isDense: true,
                        ),
                      ),
                    ),

                    // Filtered list
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: listLengthNotifier,
                        builder: (_, value, __) {
                          return filteredPlaylists.isEmpty
                              ? const Center(child: Text('No playlists found'))
                              : ListView.builder(
                                itemCount: filteredPlaylists.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    child: FilledButton(
                                      onPressed: () {
                                        showToast(
                                          context,
                                          addSongsToPlaylist(
                                            context,
                                            filteredPlaylists[index],
                                            activeQueue['list'],
                                          ),
                                        );
                                        Navigator.pop(
                                          context,
                                          filteredPlaylists[index],
                                        );
                                      },
                                      child: MarqueeWidget(
                                        child: Text(
                                          filteredPlaylists[index],
                                          textAlign: TextAlign.left,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  void _showSaveAsPlaylistDialog() => showDialog(
    context: context,
    builder: (BuildContext savecontext) {
      var customPlaylistName = '';
      String? imageUrl;

      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final dialogBackgroundColor = theme.dialogTheme.backgroundColor;

          return AlertDialog(
            backgroundColor: dialogBackgroundColor,
            content: SingleChildScrollView(
              child: SizedBox(
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 15),
                    TextField(
                      decoration: InputDecoration(
                        labelText: context.l10n!.customPlaylistName,
                      ),
                      onChanged: (value) {
                        customPlaylistName = value;
                      },
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      decoration: InputDecoration(
                        labelText: context.l10n!.customPlaylistImgUrl,
                      ),
                      onChanged: (value) {
                        imageUrl = value;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(context.l10n!.add.toUpperCase()),
                onPressed: () async {
                  if (customPlaylistName.isNotEmpty) {
                    if (findPlaylistByName(customPlaylistName) != null)
                      await showDialog(
                        routeSettings: const RouteSettings(
                          name: '/confirmation',
                        ),
                        context: savecontext,
                        builder:
                            (BuildContext confirmcontext) => ConfirmationDialog(
                              message:
                                  '${context.l10n!.playlistAlreadyExists}. ${context.l10n!.overwriteExistingPlaylist}',
                              confirmText: context.l10n!.confirm,
                              cancelText: context.l10n!.cancel,
                              onCancel:
                                  () => GoRouter.of(
                                    savecontext,
                                  ).pop(confirmcontext),
                              onSubmit: () {
                                showToast(
                                  context,
                                  createCustomPlaylist(
                                    customPlaylistName,
                                    image: imageUrl,
                                    context,
                                    songList: activeQueue['list'],
                                  ),
                                );
                                GoRouter.of(context).pop(context);
                              },
                            ),
                      );
                    else {
                      showToast(
                        context,
                        createCustomPlaylist(
                          customPlaylistName,
                          image: imageUrl,
                          context,
                          songList: activeQueue['list'],
                        ),
                      );
                      GoRouter.of(context).pop(context);
                    }
                  } else {
                    showToast(
                      context,
                      '${context.l10n!.provideIdOrNameError}.',
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );

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
        SongList(
          title: getTitle(widget.page, context),
          isEditable: widget.page == 'queue',
        ),
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
          'queue': activeQueue['list'],
        }[page] ??
        activeQueue['list'];
  }

  ValueNotifier<int> getLength(String page) {
    return {
          'liked': currentLikedSongsLength,
          'offline': currentOfflineSongsLength,
          'recents': currentRecentlyPlayedLength,
          'queue': activeQueueLength,
        }[page] ??
        currentLikedSongsLength;
  }

  Widget buildPlaylistHeader(String title, IconData icon, int songsLength) {
    return PlaylistHeader(
      _buildPlaylistImage(title, icon, songsLength),
      title,
      songsLength,
      customWidget: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder(
            valueListenable: audioHandler.songValueNotifier,
            builder: (context, value, _) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (audioHandler.songValueNotifier.value['title'] != null)
                    Text(
                      audioHandler.songValueNotifier.value['title'],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (audioHandler.songValueNotifier.value['artist'] != null)
                    Text(
                      audioHandler.songValueNotifier.value['artist'] ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: audioHandler.positionDataNotifier,
            builder:
                (context, value, _) =>
                    value.duration != Duration.zero
                        ? PositionSlider(
                          positionDataNotifier:
                              audioHandler.positionDataNotifier,
                        )
                        : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistImage(String title, IconData icon, int songsLength) {
    final size = MediaQuery.of(context).size.width > 480 ? 200.0 : 100.0;
    return BaseCard(
      inputData: {'title': '$title\n$songsLength Songs'},
      size: size,
      icon: icon,
    );
  }

  Widget buildSongList(
    String title,
    List songsList,
    ValueNotifier currentSongsLength,
  ) {
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
                  borderRadius: borderRadius,
                  showMusicDuration: true,
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

              return SongBar(song, borderRadius: borderRadius);
              // ignore: require_trailing_commas
            }, childCount: songsList.length),
          );
        }
      },
    );
  }
}
