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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
import 'package:reverbio/widgets/playlist_bar.dart';
import 'package:reverbio/widgets/playlist_import.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  ValueNotifier<bool> isFilteredNotifier = ValueNotifier(false);
  final List<PlaylistBar> userPlaylistBars = [];
  late ThemeData _theme;

  @override
  void dispose() {
    currentLikedPlaylistsLength.removeListener(_listener);
    currentLikedSongsLength.removeListener(_listener);
    currentOfflineSongsLength.removeListener(_listener);
    currentRecentlyPlayedLength.removeListener(_listener);
    currentLikedAlbumsLength.removeListener(_listener);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    currentLikedPlaylistsLength.addListener(_listener);
    currentLikedSongsLength.addListener(_listener);
    currentOfflineSongsLength.addListener(_listener);
    currentRecentlyPlayedLength.addListener(_listener);
    currentLikedAlbumsLength.addListener(_listener);
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final primaryColor = _theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n!.library),
        actions: [
          if (!offlineMode.value)
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              onPressed: _showAddPlaylistDialog,
              icon: Icon(FluentIcons.add_24_filled, color: primaryColor),
              iconSize: pageHeaderIconSize,
            ),
          if (!offlineMode.value) _clearFiltersButton(),
          if (kDebugMode) const SizedBox(width: 24, height: 24),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: commonSingleChildScrollViewPadding,
              child: Column(
                children: <Widget>[
                  if (!offlineMode.value)
                    _buildUserPlaylistsSection(primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPlaylistsSection(Color primaryColor) {
    return ValueListenableBuilder(
      valueListenable: offlineMode,
      builder: (context, value, child) {
        return Column(
          children: [
            if (!offlineMode.value)
              PlaylistBar(
                context.l10n!.recentlyPlayed,
                onPressed:
                    () => NavigationManager.router.go(
                      '/library/userSongs/recents',
                    ),
                cardIcon: FluentIcons.history_24_filled,
                borderRadius: commonCustomBarRadiusFirst,
                showBuildActions: false,
              ),
            if (!offlineMode.value)
              PlaylistBar(
                context.l10n!.likedSongs,
                onPressed:
                    () =>
                        NavigationManager.router.go('/library/userSongs/liked'),
                cardIcon: FluentIcons.heart_24_filled,
                showBuildActions: false,
              ),
            if (!offlineMode.value)
              PlaylistBar(
                context.l10n!.likedArtists,
                onPressed:
                    () => NavigationManager.router.go(
                      '/library/userSongs/artists',
                    ),
                cardIcon: FluentIcons.mic_sparkle_24_filled,
                showBuildActions: false,
              ),
            if (!offlineMode.value)
              PlaylistBar(
                context.l10n!.likedAlbums,
                onPressed:
                    () => NavigationManager.router.go(
                      '/library/userSongs/albums',
                    ),
                cardIcon: FluentIcons.cd_16_filled,
                showBuildActions: false,
              ),
            PlaylistBar(
              context.l10n!.offlineSongs,
              onPressed:
                  () =>
                      NavigationManager.router.go('/library/userSongs/offline'),
              cardIcon: FluentIcons.cellular_off_24_filled,
              borderRadius: commonCustomBarRadiusLast,
              showBuildActions: false,
            ),
            if (!offlineMode.value) ...[
              _buildSearchBar(),
              SectionHeader(
                title: context.l10n!.customPlaylists,
                actions: [
                  IconButton(
                    padding: const EdgeInsets.only(right: 5),
                    onPressed: _showAddPlaylistDialog,
                    icon: Icon(FluentIcons.add_24_filled, color: primaryColor),
                    iconSize: pageHeaderIconSize,
                  ),
                ],
              ),
              ValueListenableBuilder<List>(
                valueListenable: userCustomPlaylists,
                builder: (context, playlists, _) {
                  if (playlists.isEmpty) {
                    return const SizedBox();
                  }
                  return _buildPlaylistListView(
                    context,
                    playlists,
                    'user-created',
                  );
                },
              ),
              ValueListenableBuilder<List>(
                valueListenable: userPlaylists,
                builder: (context, playlists, _) {
                  return Column(
                    children: [
                      SectionHeader(
                        title: context.l10n!.addedPlaylists,
                        actions: [
                          IconButton(
                            padding: const EdgeInsets.only(right: 5),
                            onPressed: _showAddPlaylistDialog,
                            icon: Icon(
                              FluentIcons.add_24_filled,
                              color: primaryColor,
                            ),
                            iconSize: pageHeaderIconSize,
                          ),
                        ],
                      ),
                      if (userPlaylists.value.isNotEmpty)
                        FutureBuilder(
                          future: getUserYTPlaylists(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(child: Spinner());
                            } else if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            } else if (snapshot.hasData &&
                                snapshot.data!.isNotEmpty) {
                              return _buildPlaylistListView(
                                context,
                                snapshot.data!,
                                'user-youtube',
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                    ],
                  );
                },
              ),
              ValueListenableBuilder(
                valueListenable: currentLikedPlaylistsLength,
                builder: (context, value, __) {
                  return Column(
                    children: [
                      SectionHeader(title: context.l10n!.likedPlaylists),
                      if (userLikedPlaylists.isNotEmpty)
                        _buildPlaylistListView(
                          context,
                          userLikedPlaylists,
                          'youtube',
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    );
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

  Widget _buildSearchBar() {
    return CustomSearchBar(
      //loadingProgressNotifier: _fetchingSongs,
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

  void _buildPlaylistBars(List playlists) {
    for (final playlist in playlists) {
      if (playlist['source'] == null) playlist['source'] = 'user-liked';
      userPlaylistBars.add(
        PlaylistBar(
          key: ValueKey(
            playlist['id'] ?? playlist['ytid'] ?? playlist['title'],
          ),
          playlist['title'],
          playlistId: playlist['ytid'],
          playlistArtwork: playlist['image'],
          isAlbum: playlist['isAlbum'],
          playlistData: playlist,
          onDelete:
              playlist['source'] == 'user-created' ||
                      playlist['source'] == 'user-youtube'
                  ? () => _showRemovePlaylistDialog(playlist)
                  : null,
        ),
      );
    }
  }

  Widget _buildPlaylistListView(
    BuildContext context,
    List playlists,
    String source,
  ) {
    userPlaylistBars.removeWhere((e) => e.playlistData?['source'] == source);
    _buildPlaylistBars(playlists);
    final bars =
        userPlaylistBars
            .where(
              (value) =>
                  value.playlistData!['source']?.toLowerCase() ==
                  source.toLowerCase(),
            )
            .toList();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bars.length,
      padding: commonListViewBottomPadding,
      itemBuilder: (BuildContext context, index) {
        return bars[index];
      },
    );
  }

  void _showAddPlaylistDialog() => showDialog(
    routeSettings: const RouteSettings(name: '/save-playlist'),
    context: context,
    builder: (BuildContext savecontext) {
      var id = '';
      var customPlaylistName = '';
      var isYouTubeMode = true;
      String? imageUrl;

      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final activeButtonBackground = theme.colorScheme.surfaceContainer;
          final inactiveButtonBackground = theme.colorScheme.secondaryContainer;
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Tooltip(
                          message: context.l10n!.youtubePlaylistLinkOrId,
                          child: ElevatedButton(
                            onPressed: () {
                              if (mounted)
                                setState(() {
                                  isYouTubeMode = true;
                                  id = '';
                                  customPlaylistName = '';
                                  imageUrl = null;
                                });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isYouTubeMode
                                      ? inactiveButtonBackground
                                      : activeButtonBackground,
                            ),
                            child: const Icon(FluentIcons.globe_add_24_filled),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: context.l10n!.customPlaylists,
                          child: ElevatedButton(
                            onPressed: () {
                              if (mounted)
                                setState(() {
                                  isYouTubeMode = false;
                                  id = '';
                                  customPlaylistName = '';
                                  imageUrl = null;
                                });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isYouTubeMode
                                      ? activeButtonBackground
                                      : inactiveButtonBackground,
                            ),
                            child: const Icon(FluentIcons.person_add_24_filled),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: context.l10n!.importPlaylists,
                          child: ElevatedButton(
                            onPressed: () {
                              if (mounted) showPlaylistImporter(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeButtonBackground,
                            ),
                            child: const Icon(FluentIcons.table_add_24_filled),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (isYouTubeMode)
                      TextField(
                        decoration: InputDecoration(
                          labelText: context.l10n!.youtubePlaylistLinkOrId,
                        ),
                        onChanged: (value) {
                          id = value;
                        },
                      )
                    else ...[
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
                              final path = await pickImageFile();
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
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(context.l10n!.add.toUpperCase()),
                onPressed: () async {
                  if (isYouTubeMode && id.isNotEmpty) {
                    showToast(await addYTUserPlaylist(id, context));
                    GoRouter.of(context).pop(context);
                  } else if (!isYouTubeMode && customPlaylistName.isNotEmpty) {
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
                                  ),
                                );
                                GoRouter.of(context).pop();
                              },
                            ),
                      );
                    else {
                      showToast(
                        createCustomPlaylist(
                          customPlaylistName,
                          image: imageUrl,
                          context,
                        ),
                      );
                      GoRouter.of(context).pop();
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

  void _showRemovePlaylistDialog(Map playlist) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        message: context.l10n!.removePlaylistQuestion,
        confirmText: context.l10n!.remove,
        cancelText: context.l10n!.cancel,
        onCancel: () {
          GoRouter.of(context).pop();
        },
        onSubmit: () {
          GoRouter.of(context).pop();

          if (playlist['ytid'] == null &&
              playlist['source'] == 'user-created') {
            removeUserCustomPlaylist(playlist);
          } else {
            removeUserPlaylist(playlist['ytid']);
          }
        },
      );
    },
  );
}
