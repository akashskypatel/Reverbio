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

import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
import 'package:reverbio/widgets/expanding_toolbar.dart';
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
  // R1 fix: Cache future to prevent re-fetching on every rebuild
  Future<List<dynamic>>? _getUserYTPlaylistsFuture;

  @override
  void dispose() {
    // R5 fix: Dispose all controllers and notifiers
    _searchBar.dispose();
    _inputNode.dispose();
    isFilteredNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // R1 fix: Initialize cached future once in initState
    _getUserYTPlaylistsFuture = getUserYTPlaylists();
  }

  // R6 fix: Remove unused _listener method

  @override
  Widget build(BuildContext context) {
    // R10 fix: Use Theme.of(context) directly instead of storing in instance field
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n!.library),
        actions: [
          ExpandingToolbar(
            actions: [
              if (!offlineMode.value)
                IconButton(
                  onPressed: _showAddPlaylistDialog,
                  icon: Icon(FluentIcons.add_24_filled, color: primaryColor),
                  iconSize: pageHeaderIconSize,
                ),
              if (!offlineMode.value) _clearFiltersButton(),
            ],
          ),
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
                // R4 fix: Use GoRouter.of(context).push() consistently
                onPressed:
                    () => GoRouter.of(context).push('/library/userSongs/recents'),
                cardIcon: FluentIcons.history_24_filled,
                borderRadius: commonCustomBarRadiusFirst,
                showBuildActions: false,
              ),
            if (!offlineMode.value)
              PlaylistBar(
                context.l10n!.likedSongs,
                onPressed:
                    () => GoRouter.of(context).push('/library/userSongs/liked'),
                cardIcon: FluentIcons.heart_24_filled,
                showBuildActions: false,
              ),
            if (!offlineMode.value)
              PlaylistBar(
                context.l10n!.likedArtists,
                onPressed:
                    () =>
                        GoRouter.of(context).push('/library/userSongs/artists'),
                cardIcon: FluentIcons.mic_sparkle_24_filled,
                showBuildActions: false,
              ),
            if (!offlineMode.value)
              PlaylistBar(
                context.l10n!.likedAlbums,
                onPressed:
                    () =>
                        GoRouter.of(context).push('/library/userSongs/albums'),
                cardIcon: FluentIcons.cd_16_filled,
                showBuildActions: false,
              ),
            PlaylistBar(
              context.l10n!.offlineSongs,
              onPressed:
                  () => GoRouter.of(context).push('/library/userSongs/offline'),
              cardIcon: FluentIcons.cellular_off_24_filled,
              showBuildActions: false,
            ),
            PlaylistBar(
              context.l10n!.offlinePlaylists,
              onPressed:
                  () => GoRouter.of(
                    context,
                  ).push('/library/userSongs/offlinePlaylists'),
              cardIcon: FluentIcons.arrow_download_24_filled,
              borderRadius: commonCustomBarRadiusLast,
              showBuildActions: false,
            ),
            if (!offlineMode.value) ...[
              _buildSearchBar(),
              SectionHeader(
                title: context.l10n!.customPlaylists,
                actions: [
                  IconButton(
                    onPressed: _showAddPlaylistDialog,
                    icon: Icon(FluentIcons.add_24_filled, color: primaryColor),
                    iconSize: pageHeaderIconSize,
                  ),
                ],
              ),
              ListenableBuilder(
                listenable: userCustomPlaylists,
                builder: (context, _) {
                  if (userCustomPlaylists.isEmpty) {
                    return const SizedBox();
                  }
                  return _buildPlaylistListView(
                    context,
                    userCustomPlaylists,
                    'user-created',
                  );
                },
              ),
              ListenableBuilder(
                listenable: userPlaylists,
                builder: (context, _) {
                  return Column(
                    children: [
                      SectionHeader(
                        title: context.l10n!.addedPlaylists,
                        actions: [
                          IconButton(
                            onPressed: _showAddPlaylistDialog,
                            icon: Icon(
                              FluentIcons.add_24_filled,
                              color: primaryColor,
                            ),
                            iconSize: pageHeaderIconSize,
                          ),
                        ],
                      ),
                      if (userPlaylists.isNotEmpty)
                        // R1 fix: Use cached future instead of calling getUserYTPlaylists() on every rebuild
                        FutureBuilder(
                          future: _getUserYTPlaylistsFuture,
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
              ListenableBuilder(
                listenable: userLikedPlaylists,
                builder: (context, __) {
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
        // R10 fix: Use Theme.of(context) instead of _theme
        final theme = Theme.of(context);
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
          color: theme.colorScheme.primary,
          disabledColor: theme.colorScheme.primaryContainer,
        );
      },
    );
  }

  // R3 fix: Restore visibility for items matching query
  void _filterPlaylistBars(String query) {
    if (query.isEmpty) {
      for (final widget in userPlaylistBars) {
        widget.setVisibility(true);
      }
      isFilteredNotifier.value = false;
    } else {
      var anyFiltered = false;
      for (final widget in userPlaylistBars) {
        final searchStr = widget.playlistTitle;
        if (searchStr.isNotEmpty && !searchStr.toLowerCase().contains(query)) {
          widget.setVisibility(false);
          anyFiltered = true;
        } else {
          // R3 fix: Restore visibility for matching items
          widget.setVisibility(true);
        }
      }
      isFilteredNotifier.value = anyFiltered;
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

  // R2 fix: _buildPlaylistBars removed - logic now inlined in _buildPlaylistListView
  // to avoid mutating shared userPlaylistBars list

  // R2 fix: Don't mutate shared userPlaylistBars - create new list instead
  Widget _buildPlaylistListView(
    BuildContext context,
    List playlists,
    String source,
  ) {
    // R2 fix: Create new PlaylistBars for this source instead of mutating shared list
    final bars = <PlaylistBar>[];
    for (final playlistOrig in playlists) {
      // R11 fix: Create a copy to avoid mutating the original
      final playlist = Map<String, dynamic>.from(playlistOrig);
      if (playlist['source'] == null) playlist['source'] = source;
      bars.add(
        PlaylistBar(
          key: ValueKey(
            playlist['id'] ??
                playlist['ytid'] ??
                playlist['title'] ??
                'unknown',
          ),
          playlist['title'] ?? 'unknown',
          playlistId: playlist['ytid'],
          playlistArtwork: playlist['image'],
          isAlbum: playlist['isAlbum'],
          playlistData: playlist,
          onDelete:
              // R12 fix: Use null-safe access instead of force-unwrap
              playlist['source'] == 'user-created' ||
                      playlist['source'] == 'user-youtube'
                  ? () => _showRemovePlaylistDialog(playlist)
                  : null,
        ),
      );
    }
    // R341 fix: Populate userPlaylistBars for search/filter functionality
    if (source == 'user-created' || source == 'user-youtube') {
      userPlaylistBars
        ..clear()
        ..addAll(bars);
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bars.length,
      padding: commonListViewBottomPadding,
      itemBuilder: (context, index) {
        return bars[index];
      },
    );
  }

  void _showAddPlaylistDialog() => showDialog(
    routeSettings: const RouteSettings(name: '/save-playlist'),
    context: context,
    builder: (savecontext) {
      var id = '';
      var customPlaylistName = '';
      var isYouTubeMode = true;
      String? imageUrl;
      File? imageFile;
      // R8 fix: Create TextEditingController outside StatefulBuilder
      final imagePathController = TextEditingController();
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          final dialogTheme = Theme.of(dialogContext);
          final activeButtonBackground = dialogTheme.colorScheme.surfaceContainer;
          final inactiveButtonBackground = dialogTheme.colorScheme.secondaryContainer;
          final dialogBackgroundColor = dialogTheme.dialogTheme.backgroundColor;
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
                          waitDuration: const Duration(milliseconds: 1500),
                          message: dialogContext.l10n!.youtubePlaylistLinkOrId,
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
                          waitDuration: const Duration(milliseconds: 1500),
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
                          waitDuration: const Duration(milliseconds: 1500),
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
                              imageUrl =
                                  await pickImageFile();
                              if (imageUrl != null && isFilePath(imageUrl!))
                                imageFile = await getImageFile(path: imageUrl);
                              if (imageUrl != null)
                                imagePathController.text = imageUrl!;
                            },
                            icon: const Icon(FluentIcons.folder_open_24_filled),
                            color: dialogTheme.colorScheme.primary,
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
                child: Text(dialogContext.l10n!.add.toUpperCase()),
                onPressed: () async {
                  if (isYouTubeMode && id.isNotEmpty) {
                    final result = await addYTUserPlaylist(id);
                    showToast(result.toLocalizedString());
                    // R7 fix: Use dialogContext instead of context
                    GoRouter.of(dialogContext).pop();
                    imagePathController.dispose();
                  } else if (!isYouTubeMode && customPlaylistName.isNotEmpty) {
                    if (findPlaylistByName(customPlaylistName) != null)
                      await showDialog(
                        routeSettings: const RouteSettings(
                          name: '/confirmation',
                        ),
                        context: savecontext,
                        builder:
                            (confirmcontext) => ConfirmationDialog(
                              message:
                                  '${dialogContext.l10n!.playlistAlreadyExists}. ${dialogContext.l10n!.overwriteExistingPlaylist}',
                              confirmText: dialogContext.l10n!.confirm,
                              cancelText: dialogContext.l10n!.cancel,
                              // R9 fix: Clear state on cancel so stale values
                              // don't persist if user re-opens the dialog
                              onCancel: () {
                                setState(() {
                                  customPlaylistName = '';
                                  imageUrl = null;
                                  imageFile = null;
                                  imagePathController.clear();
                                });
                                GoRouter.of(savecontext).pop();
                              },
                              onSubmit: () async {
                                final result = createCustomPlaylist(
                                  customPlaylistName,
                                  image:
                                      imageFile != null
                                          ? imageFile!
                                              .readAsBytesSync()
                                              .toList()
                                          : imageUrl,
                                );
                                showToast(result.toLocalizedString());
                                // R7 fix: Use dialogContext instead of context
                                GoRouter.of(dialogContext).pop();
                                imagePathController.dispose();
                              },
                            ),
                      );
                    else {
                      final result = createCustomPlaylist(
                        customPlaylistName,
                        image:
                            imageFile != null
                                ? imageFile!.readAsBytesSync().toList()
                                : imageUrl,
                      );
                      showToast(result.toLocalizedString());
                      // R7 fix: Use dialogContext instead of context
                      GoRouter.of(dialogContext).pop();
                      imagePathController.dispose();
                    }
                  } else {
                    showToast('${dialogContext.l10n!.provideIdOrNameError}.');
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
    builder: (dialogContext) {
      return ConfirmationDialog(
        message: dialogContext.l10n!.removePlaylistQuestion,
        confirmText: dialogContext.l10n!.remove,
        cancelText: dialogContext.l10n!.cancel,
        onCancel: () {
          GoRouter.of(dialogContext).pop();
        },
        onSubmit: () {
          GoRouter.of(dialogContext).pop();

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
