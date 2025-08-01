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

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/mini_player.dart';
import 'package:reverbio/widgets/playlist_header.dart';
import 'package:reverbio/widgets/song_list.dart';

class UserSongsPage extends StatefulWidget {
  const UserSongsPage({super.key, required this.page});

  final String page;

  @override
  State<UserSongsPage> createState() => _UserSongsPageState();
}

class _UserSongsPageState extends State<UserSongsPage> {
  late ThemeData _theme;
  bool _isEditEnabled = false;
  late final ValueNotifier<int> _lengthNotifier;
  late final String _title;
  late final IconData _icon;
  @override
  void initState() {
    super.initState();
    _title = getTitle(widget.page);
    _icon = getIcon(widget.page);
    _lengthNotifier = getLength(widget.page);
    _lengthNotifier.addListener(_listener);
  }

  @override
  void dispose() {
    super.dispose();
    _lengthNotifier.removeListener(_listener);
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title), //offlineMode.value ? Text(title) : null,
        actions: [
          if (_title == context.l10n!.queue)
            Row(children: [_buildQueueActionsList()]),
          IconButton(
            iconSize: pageHeaderIconSize,
            onPressed: () {
              if (mounted)
                setState(() {
                  _isEditEnabled = !_isEditEnabled;
                });
            },
            icon: Icon(
              _isEditEnabled
                  ? FluentIcons.edit_off_24_filled
                  : FluentIcons.edit_line_horizontal_3_24_filled,
              color: _theme.colorScheme.primary,
            ),
          ),
          if (kDebugMode) const SizedBox(width: 24, height: 24),
        ],
      ),
      body: _buildCustomScrollView(_title, _icon, getSongsList(widget.page)),
    );
  }

  Widget _buildQueueActionsList() {
    return ValueListenableBuilder(
      valueListenable: activeQueueLength,
      builder: (context, value, __) {
        return Row(
          children: [
            ValueListenableBuilder<AudioServiceRepeatMode>(
              valueListenable: repeatNotifier,
              builder: (context, repeatMode, __) {
                return repeatMode != AudioServiceRepeatMode.none
                    ? IconButton(
                      icon: Icon(
                        repeatMode == AudioServiceRepeatMode.all
                            ? FluentIcons.arrow_repeat_all_24_filled
                            : FluentIcons.arrow_repeat_1_24_filled,
                        color: _theme.colorScheme.primary,
                      ),
                      iconSize: pageHeaderIconSize,
                      onPressed: () {
                        repeatNotifier.value =
                            repeatMode == AudioServiceRepeatMode.all
                                ? AudioServiceRepeatMode.one
                                : AudioServiceRepeatMode.none;

                        audioHandler.setRepeatMode(repeatMode);
                      },
                    )
                    : IconButton(
                      icon: Icon(
                        FluentIcons.arrow_repeat_all_off_24_filled,
                        color: _theme.colorScheme.primary,
                      ),
                      iconSize: pageHeaderIconSize,
                      onPressed: () {
                        final _isSingleSongPlaying =
                            audioHandler.queueSongBars.length == 1;
                        repeatNotifier.value =
                            _isSingleSongPlaying
                                ? AudioServiceRepeatMode.one
                                : AudioServiceRepeatMode.all;

                        if (repeatNotifier.value == AudioServiceRepeatMode.one)
                          audioHandler.setRepeatMode(repeatNotifier.value);
                      },
                    );
              },
            ),
            IconButton(
              iconSize: pageHeaderIconSize,
              tooltip: context.l10n!.addToPlaylist,
              onPressed: value == 0 ? null : _showExistingPlaylists,
              disabledColor: _theme.colorScheme.inversePrimary,
              color: _theme.colorScheme.primary,
              icon: const Icon(Icons.playlist_add),
            ),
            IconButton(
              iconSize: pageHeaderIconSize,
              tooltip: context.l10n!.saveAsPlayList,
              onPressed: value == 0 ? null : _showSaveAsPlaylistDialog,
              disabledColor: _theme.colorScheme.inversePrimary,
              color: _theme.colorScheme.primary,
              icon: const Icon(FluentIcons.add_24_filled),
            ),
            IconButton(
              iconSize: pageHeaderIconSize,
              tooltip: context.l10n!.clearQueue,
              onPressed:
                  value == 0
                      ? null
                      : () {
                        clearSongQueue();
                        showToast(context.l10n!.queueCleared);
                      },
              disabledColor: _theme.colorScheme.inversePrimary,
              color: _theme.colorScheme.primary,
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
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        onChanged: filterPlaylists,
                        decoration: const InputDecoration(
                          hintText: 'Search playlists...',
                          prefixIcon: Icon(FluentIcons.search_24_filled),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          isDense: true,
                        ),
                      ),
                    ),

                    // Filtered list
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: listLengthNotifier,
                        builder: (context, value, __) {
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
          final imagePathController = TextEditingController();
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
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                          RegExp(r'[/\\:*?"<>|&=]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: context.l10n!.customPlaylistName,
                      ),
                      onChanged: (value) {
                        customPlaylistName = value;
                      },
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imagePathController,
                            decoration: InputDecoration(
                              labelText: context.l10n!.customPlaylistImgUrl,
                            ),
                            onChanged: (value) {
                              imageUrl = value;
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final path =
                                (await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: [
                                    'jpeg',
                                    'jpg',
                                    'png',
                                    'gif',
                                    'webp',
                                    'bmp',
                                  ],
                                ))?.paths.first;
                            imageUrl = path;
                            if (imageUrl != null)
                              imagePathController.text = imageUrl!;
                          },
                          icon: const Icon(FluentIcons.folder_open_24_filled),
                          color: theme.colorScheme.primary,
                        ),
                      ],
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
                    showToast('${context.l10n!.provideIdOrNameError}.');
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
    Future songsListFuture,
  ) {
    return FutureBuilder(
      future: songsListFuture,
      builder: (context, snapshot) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: buildPlaylistHeader(title, icon, _lengthNotifier),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: currentOfflineSongsLength,
              builder: (context, _context, ___) {
                return SongList(
                  page: widget.page,
                  title: getTitle(widget.page),
                  isEditable: _isEditEnabled,
                  future: songsListFuture,
                );
              },
            ),
          ],
        );
      },
    );
  }

  String getTitle(String page) {
    final context = NavigationManager().context;
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

  Future<List> getSongsList(String page) {
    return {
          'liked': Future.value(userLikedSongsList),
          'offline': getUserOfflineSongs(),
          'recents': Future.value(userRecentlyPlayed),
          'queue': Future.value(activeQueue['list'] as List),
        }[page] ??
        Future.value(activeQueue['list'] as List);
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

  Widget buildPlaylistHeader(
    String title,
    IconData icon,
    ValueNotifier<int> length,
  ) {
    return PlaylistHeader(
      _buildPlaylistImage(title, icon, length),
      title,
      length.value,
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
                  if (audioHandler
                          .audioPlayer
                          .songValueNotifier
                          .value
                          ?.song['title'] !=
                      null)
                    Text(
                      audioHandler
                          .audioPlayer
                          .songValueNotifier
                          .value
                          ?.song['title'],
                      style: TextStyle(
                        color: _theme.colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (audioHandler
                          .audioPlayer
                          .songValueNotifier
                          .value
                          ?.song['artist'] !=
                      null)
                    Text(
                      audioHandler
                              .audioPlayer
                              .songValueNotifier
                              .value
                              ?.song['artist'] ??
                          '',
                      style: TextStyle(
                        color: _theme.colorScheme.secondary,
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

  void _listener() {
    if (mounted) setState(() {});
  }

  Widget _buildPlaylistImage(
    String title,
    IconData icon,
    ValueNotifier<int> length,
  ) {
    final size = MediaQuery.of(context).size.width > 480 ? 200.0 : 100.0;
    length.addListener(_listener);
    return ValueListenableBuilder(
      valueListenable: length,
      builder: (context, value, child) {
        return BaseCard(
          inputData: {'title': '$title\n${length.value} Songs'},
          size: size,
          icon: icon,
        );
      },
    );
  }
}
