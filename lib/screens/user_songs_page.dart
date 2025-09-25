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
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/mini_player.dart';
import 'package:reverbio/widgets/playlist_header.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:reverbio/widgets/song_list.dart';
import 'package:reverbio/widgets/spinner.dart';

class UserSongsPage extends StatefulWidget {
  const UserSongsPage({super.key, required this.page});

  final String page;

  @override
  State<UserSongsPage> createState() => _UserSongsPageState();
}

class _UserSongsPageState extends State<UserSongsPage> {
    //with TickerProviderStateMixin {
  late ThemeData _theme;
  final _isEditEnabled = ValueNotifier(false);
  late final String _title;
  late NotifiableList<SongBar> notifiableSongsList = getSongsList(widget.page);

  @override
  void initState() {
    super.initState();
    _title = getTitle(widget.page);
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
        title: Text(_title),
        actions: [
          _buildSyncButton(),
          if (_title == context.l10n!.queue)
            Row(children: [_buildQueueActionsList()]),
          StatefulBuilder(
            builder: (context, setState) {
              return IconButton(
                iconSize: pageHeaderIconSize,
                onPressed: () {
                  if (mounted)
                    setState(() {
                      _isEditEnabled.value = !_isEditEnabled.value;
                    });
                },
                icon: Icon(
                  _isEditEnabled.value
                      ? FluentIcons.edit_off_24_filled
                      : FluentIcons.edit_line_horizontal_3_24_filled,
                  color: _theme.colorScheme.primary,
                ),
              );
            },
          ),
          if (kDebugMode) const SizedBox(width: 24, height: 24),
        ],
      ),
      body: SliverMainAxisGroup(
        slivers: [
          ValueListenableBuilder(
            valueListenable: _isEditEnabled,
            builder: (context, value, child) {
              return SongList(
                page: widget.page,
                title: getTitle(widget.page),
                isEditable: value,
                songBars: notifiableSongsList,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQueueActionsList() {
    return ListenableBuilder(
      listenable: audioHandler.queueSongBars,
      builder: (context, __) {
        final value = audioHandler.queueSongBars.length;
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
    builder: (savecontext) {
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
                        decoration: InputDecoration(
                          hintText: context.l10n!.searchPlaylists,
                          prefixIcon: const Icon(FluentIcons.search_24_filled),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
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
                              ? Center(child: Text(context.l10n!.noPlaylists))
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
    builder: (savecontext) {
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

  Widget _loadingSongListWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n!.checkBackLater),
        const SizedBox(height: 10),
        const Spinner(),
      ],
    );
  }

  Widget _errorSongListWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n!.checkBackLater),
        const SizedBox(height: 10),
        const Spinner(),
      ],
    );
  }

  String getTitle(String page) {
    return {
          'liked': L10n.current.likedSongs,
          'offline': L10n.current.offlineSongs,
          'recents': L10n.current.recentlyPlayed,
          'queue': L10n.current.queue,
        }[page] ??
        L10n.current.playlist;
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

  Future<Iterable<Map<String, dynamic>>> _getArtists() async {
    return notifiableSongsList.completer.future.then((value) async {
      final songs = value.map((e) => e.song).toList();
      return getArtistsFromSongs(songs);
    });
  }

  Future<Iterable<SongBar>> _getOfflineSongs() async {
    return Future.microtask(() async {
      final offline = userOfflineSongs.map((e) {
        final cached = getCachedSong(e);
        final song =
            isSongValid(cached)
                ? cached!
                : <String, dynamic>{'id': e, 'title': null, 'artist': null};
        return initializeSongBar(song, context);
      });
      final device = userDeviceSongs.map((e) => initializeSongBar(e, context));
      return [...offline, ...device];
    });
  }

  Future<Iterable<SongBar>> _getUserLikedSongs() async {
    return Future.microtask(() async {
      return userLikedSongsList.map((e) => initializeSongBar(e, context));
    });
  }

  Future<Iterable<SongBar>> _getUserRecentSongs() async {
    return Future.microtask(() async {
      return userLikedSongsList.map((e) => initializeSongBar(e, context));
    });
  }

  NotifiableList<SongBar> getSongsList(String page) {
    switch (page) {
      case 'liked':
        return NotifiableList.fromAsync(_getUserLikedSongs());
      case 'offline':
        return NotifiableList.fromAsync(_getOfflineSongs());
      case 'recents':
        return NotifiableList.fromAsync(_getUserRecentSongs());
      case 'queue':
      default:
        return audioHandler.queueSongBars;
    }
  }

  Widget buildPlaylistHeader(String title, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListenableBuilder(
          listenable: notifiableSongsList,
          builder: (context, child) {
            return PlaylistHeader(
              _buildPlaylistImage(title, icon, notifiableSongsList.length),
              title,
              notifiableSongsList.length,
              customWidget: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder(
                    valueListenable: audioHandler.songValueNotifier,
                    builder: (context, value, _) {
                      final song = value?.song;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (value != null)
                            Text(
                              song?['mbTitle'] ??
                                  song?['title'] ??
                                  song?['ytTitle'] ??
                                  context.l10n!.unknown,
                              style: TextStyle(
                                color: _theme.colorScheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (value != null)
                            Text(
                              song?['mbArtist'] ??
                                  song?['artist'] ??
                                  song?['ytArtist'] ??
                                  context.l10n!.unknown,
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
          },
        ),
      ),
    );
  }

  Widget _buildSyncButton() {
    return IconButton(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.arrow_sync_24_filled),
      iconSize: pageHeaderIconSize,
      onPressed: () async {
        if (widget.page == 'offline') {
          final futures =
              <Future>[]
                ..add(getExistingOfflineSongs())
                ..add(getUserDeviceSongs());
          await Future.wait(futures);
        }
        final songBars = getSongsList(widget.page);
        for (final songBar in songBars) {
          notifiableSongsList.addOrUpdate(
            songBar,
            (a, b) => checkSong(a.song, b.song),
          );
        }
      },
    );
  }

  Widget _buildPlaylistImage(String title, IconData icon, int length) {
    final size = MediaQuery.of(context).size.width > 480 ? 200.0 : 100.0;
    return BaseCard(
      inputData: {'title': '$title\n$length ${context.l10n!.songs}'},
      size: size,
      icon: icon,
    );
  }
}
