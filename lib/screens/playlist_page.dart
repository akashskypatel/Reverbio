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

//import 'dart:math';

import 'dart:async';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/playlist_sharing.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/notifiable_future.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/utilities/url_launcher.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/expanding_toolbar.dart';
import 'package:reverbio/widgets/playlist_header.dart';
import 'package:reverbio/widgets/song_list.dart';
import 'package:reverbio/widgets/spinner.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({
    super.key,
    required this.playlistData,
    this.cardIcon = FluentIcons.music_note_1_24_regular,
    this.isArtist = false,
    required this.page,
  });
  final String page;
  final Map<String, dynamic> playlistData;
  final IconData cardIcon;
  final bool isArtist;

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  List<dynamic> _songsList = [];
  late ThemeData _theme;
  late final NotifiableFuture<Map<String, dynamic>> _infoRequestFuture =
      NotifiableFuture(widget.playlistData);
  final _isEditEnabled = ValueNotifier(false);
  final likeStatus = ValueNotifier<bool>(false);
  NotifiableList? likeLength;
  final autoOffline = ValueNotifier<bool>(false);
  // R1 fix: Cache fetch future to prevent re-fetching on every rebuild
  late Future<NotifiableList<Map<String, dynamic>>> _fetchFuture;
  // R6 fix: Local copy of playlist data to avoid mutating widget.playlistData
  late Map<String, dynamic> _playlistData;

  @override
  void initState() {
    super.initState();
    // R6 fix: Initialize local copy
    _playlistData = Map<String, dynamic>.from(widget.playlistData);
    _infoRequestFuture.runFuture(_initializePlaylist());
    // R1 fix: Initialize cached future once in initState
    _fetchFuture = fetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      likeStatus.value = getLikeStatus();
      autoOffline.value = isPlaylistAlreadyOffline(widget.playlistData);
    });
  }

  @override
  void dispose() {
    _infoRequestFuture.dispose();
    // R12 fix: Dispose all ValueNotifiers
    _isEditEnabled.dispose();
    likeStatus.dispose();
    autoOffline.dispose();
    super.dispose();
  }

  bool getLikeStatus() {
    if ([
      'album',
      'single',
      'ep',
      'broadcast',
      'other',
    ].contains(widget.playlistData['primary-type']?.toLowerCase())) {
      return isAlbumAlreadyLiked(widget.playlistData);
    } else if (widget.playlistData['ytid'] != null)
      return isPlaylistAlreadyLiked(widget.playlistData);
    return false;
  }

  Future<Map<String, dynamic>> _initializePlaylist() async {
    final id = parseEntityId(_playlistData);
    final ids = id.toIds;
    final ytid = (ids['yt'] ?? id.ytid).ytid;
    final mbid = (ids['mb'] ?? id.mbid).mbid;
    if (mbid.isNotEmpty &&
        (_playlistData['list'] == null ||
            _playlistData['list'].isEmpty)) {
      await queueAlbumInfoRequest(_playlistData).completerFuture?.then((
        value,
      ) {
        if (value != null) _playlistData.addAll(value);
      });
      return _playlistData;
    } else if (ytid.isNotEmpty) {
      _playlistData['ytid'] = ytid;
      likeLength = userLikedPlaylists;
      await getPlaylistInfoForWidget(
        _playlistData,
        isArtist: widget.isArtist,
      ).then((value) {
        _playlistData.addAll(value);
      });
      return _playlistData;
    } else {
      return Future.value(_playlistData);
    }
  }

  Future<NotifiableList<Map<String, dynamic>>> fetch() async {
    // R5 fix: Add null guard for completer
    final completerFuture = _infoRequestFuture.completer?.future;
    if (completerFuture != null && !_infoRequestFuture.isComplete)
      await completerFuture;
    if (_infoRequestFuture.hasData) {}
    //TODO: restore pagination to large playlists
    final _list = NotifiableList.from(
      ((_playlistData['list'] as List?) ?? []).map((e) {
        return Map<String, dynamic>.from(e);
      }),
    );
    return _list;
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    for (final song in _songsList) {
      song['autoCacheOffline'] = widget.playlistData['autoCacheOffline'];
    }
    return Scaffold(appBar: _buildNavigationBar(), body: _buildList());
  }

  Widget _buildList() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildPlaylistHeader(),
          ),
        ),
        FutureBuilder(
          // R1 fix: Use cached future instead of calling fetch() on every rebuild
          future: _fetchFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const SliverToBoxAdapter(child: Spinner());
            if (!snapshot.hasData ||
                snapshot.data == null ||
                snapshot.data!.isEmpty)
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            return ValueListenableBuilder(
              valueListenable: _isEditEnabled,
              builder:
                  (context, value, child) => SongList(
                    page: 'playlist',
                    songMaps: snapshot.data!,
                    isEditable: value,
                  ),
            );
          },
        ),
      ],
    );
  }

  PreferredSizeWidget _buildNavigationBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(FluentIcons.arrow_left_24_filled),
        iconSize: pageHeaderIconSize,
        onPressed: () => GoRouter.of(context).pop(),
      ),
      actions: [
        ExpandingToolbar(
          actions: [
            _buildAutoCacheOfflineButton(),
            if (widget.playlistData['source'] != 'user-created')
              _buildLikeButton(),
            if (widget.playlistData.isNotEmpty) ...[
              _buildSyncButton(),
              if (widget.playlistData['source'] == 'user-created')
                IconButton(
                  icon: const Icon(FluentIcons.share_24_regular),
                  iconSize: pageHeaderIconSize,
                  onPressed: () async {
                    final encodedPlaylist =
                        PlaylistSharingService.encodePlaylist(
                          widget.playlistData,
                        );
                    // R16 fix: Validate deep link format
                    final url = 'reverbio://playlist/custom/$encodedPlaylist';
                    if (Uri.tryParse(url) != null) {
                      await Clipboard.setData(ClipboardData(text: url));
                      showToast('Share link copied to clipboard');
                    } else {
                      showToast('Failed to generate share link');
                    }
                  },
                ),
              ...PM.getWidgetsByType(
                _getPlaylistData,
                [
                      'album',
                      'single',
                      'ep',
                      'broadcast',
                      'other',
                    ].contains(widget.page)
                    ? 'AlbumPageHeader'
                    : 'PlaylistPageHeader',
                context,
              ),
              if ([
                    'album',
                    'single',
                    'ep',
                    'broadcast',
                    'other',
                  ].contains(widget.page) &&
                  widget.playlistData['mbid'] != null)
                IconButton(
                  iconSize: pageHeaderIconSize,
                  onPressed: () {
                    if (widget.playlistData['mbid'] != null) {
                      final uri = Uri.parse(
                        'https://musicbrainz.org/release-group/${widget.playlistData['mbid']}',
                      );
                      launchURL(uri);
                    }
                  },
                  icon: Icon(
                    FluentIcons.database_link_24_filled,
                    color: _theme.colorScheme.primary,
                  ),
                ),
              if (widget.page == 'playlist' &&
                  widget.playlistData['ytid'] != null)
                IconButton(
                  iconSize: pageHeaderIconSize,
                  onPressed: () {
                    if (widget.playlistData['ytid'] != null) {
                      final uri = Uri.parse(
                        'https://www.youtube.com/playlist?list=${widget.playlistData['ytid']}',
                      );
                      launchURL(uri);
                    }
                  },
                  icon: Icon(
                    FluentIcons.link_24_regular,
                    color: _theme.colorScheme.primary,
                  ),
                ),
              if (widget.playlistData.isNotEmpty &&
                  widget.playlistData['source'] == 'user-created')
                _buildEditButton(),
              // R11 fix: Use ValueListenableBuilder instead of StatefulBuilder
              ValueListenableBuilder<bool>(
                valueListenable: _isEditEnabled,
                builder: (context, value, child) {
                  return IconButton(
                    iconSize: pageHeaderIconSize,
                    onPressed: () {
                      _isEditEnabled.value = !_isEditEnabled.value;
                    },
                    icon: Icon(
                      value
                          ? FluentIcons.edit_off_24_filled
                          : FluentIcons.edit_line_horizontal_3_24_filled,
                      color: _theme.colorScheme.primary,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  // R13 fix: Return consistent type (Map) instead of dynamic
  Map<String, dynamic> _getPlaylistData() {
    if (['album', 'single', 'ep', 'broadcast', 'other'].contains(widget.page) ||
        (widget.playlistData['isAlbum'] ?? false)) {
      return {
        ...(widget.playlistData as Map),
        'album': widget.playlistData['title'],
        'title': null,
      };
    }
    // Return as Map with songs list
    return {'list': _songsList};
  }

  Widget _buildPlaylistImage() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    final image =
        widget.playlistData['image'] != null
            ? (widget.playlistData['image'] is List<int>
                ? Image.memory(Uint8List.fromList(widget.playlistData['image']))
                : widget.playlistData['image'] is String &&
                    isUrl(widget.playlistData['image'])
                ? Image.network(widget.playlistData['image'])
                : isFilePath(widget.playlistData['image'])
                ? Image.file(File(widget.playlistData['image']))
                : null)
            : null;
    return BaseCard(
      image: image,
      inputData: widget.playlistData,
      size: isLandscape ? 300 : screenWidth / 2.5,
      icon: widget.cardIcon,
      showLike: widget.playlistData['source'] != 'user-created',
    );
  }

  Widget _buildPlaylistHeader() {
    // R4/R5 fix: Add null guard for completer
    final completerFuture = _infoRequestFuture.completer?.future;
    if (completerFuture == null) return const SizedBox.shrink();
    return FutureBuilder(
      future: completerFuture,
      builder: (context, snapshot) {
        final _songsLength =
            widget.playlistData['list'] == null
                ? 0
                : widget.playlistData['list'].length;
        return PlaylistHeader(
          _buildPlaylistImage(),
          ['album', 'single', 'ep', 'broadcast', 'other'].contains(widget.page)
              ? widget.playlistData['artist'] != null
                  ? '${widget.playlistData['artist']} - ${widget.playlistData['title']}'
                  : widget.playlistData['title']
              : widget.playlistData['title'],
          _songsLength,
        );
      },
    );
  }

  Future<bool> _confirmAutoCacheOffline(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => ConfirmationDialog(
                confirmText: context.l10n!.confirm,
                cancelText: context.l10n!.cancel,
                title: context.l10n!.autoCacheOfflinePlaylist,
                message: context.l10n!.storageWarning,
                onCancel: () => Navigator.pop(context, false),
                onSubmit: () => Navigator.pop(context, true),
              ),
        ) ??
        false;
  }

  Widget _buildAutoCacheOfflineButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: autoOffline,
      builder: (context, value, __) {
        return IconButton(
          iconSize: pageHeaderIconSize,
          tooltip:
              value
                  ? context.l10n!.playlistAutoOfflineEnabled
                  : context.l10n!.playlistAutoOfflineDisabled,
          onPressed: () async {
            if (!mounted) return;

            final bool newValue =
                !value && await _confirmAutoCacheOffline(context);

            if (newValue != value) {
              // R6 fix: Don't mutate widget.playlistData directly
              final playlistCopy = Map<String, dynamic>.from(widget.playlistData);
              playlistCopy['autoCacheOffline'] = newValue;
              setState(() {
                autoOffline.value = newValue;
                updateOfflinePlaylist(playlistCopy, newValue);
              });
            }
          },
          // R7 fix: Correct icon mapping (enabled = download icon, disabled = off icon)
          icon:
              value
                  ? const Icon(FluentIcons.arrow_download_24_filled)
                  : const Icon(FluentIcons.arrow_download_off_24_filled),
        );
      },
    );
  }

  Widget _buildLikeButton() {
    if ([
      'album',
      'single',
      'ep',
      'broadcast',
      'other',
    ].contains(widget.playlistData['primary-type']?.toLowerCase())) {
      likeLength = userLikedAlbumsList;
    } else if (widget.playlistData['ytid'] != null)
      likeLength = userLikedPlaylists;

    return FutureBuilder(
      // R4/R5 fix: Add null guard for completer
      future: _infoRequestFuture.completer?.future ?? Future.value({}),
      builder: (context, snapshot) {
        if (likeLength == null) return const SizedBox.shrink();
        return StatefulBuilder(
          builder: (context, setState) {
            return ListenableBuilder(
              listenable: likeLength!,
              builder: (_, __) {
                final value = likeStatus.value = getLikeStatus();
                return IconButton(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  icon:
                      value
                          ? const Icon(FluentIcons.heart_24_filled)
                          : const Icon(FluentIcons.heart_24_regular),
                  iconSize: pageHeaderIconSize,
                  onPressed: () async {
                    if ([
                      'album',
                      'single',
                      'ep',
                      'broadcast',
                      'other',
                    ].contains(
                      widget.playlistData['primary-type']?.toLowerCase(),
                    ))
                      await updateAlbumLikeStatus(
                        widget.playlistData,
                        !likeStatus.value,
                      );
                    else if (widget.playlistData['ytid'] != null)
                      await updatePlaylistLikeStatus(
                        widget.playlistData,
                        !likeStatus.value,
                      );
                    if (mounted)
                      setState(() {
                        likeStatus.value = getLikeStatus();
                      });
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSyncButton() {
    return IconButton(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.arrow_sync_24_filled),
      iconSize: pageHeaderIconSize,
      onPressed: _handleSyncPlaylist,
    );
  }

  Widget _buildEditButton() {
    return IconButton(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.edit_24_filled),
      iconSize: pageHeaderIconSize,
      onPressed:
          () => showDialog(
            context: context,
            builder: (context) {
              var customPlaylistName = widget.playlistData['title'];
              var imageUrl = widget.playlistData['image'];

              return AlertDialog(
                content: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 7),
                      TextField(
                        controller: TextEditingController(
                          text: customPlaylistName,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n!.customPlaylistName,
                        ),
                        onChanged: (value) {
                          customPlaylistName = value;
                        },
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(
                            RegExp(r'[/\\:*?"<>|&=]'),
                          ),
                        ],
                        controller: TextEditingController(text: imageUrl),
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
                actions: <Widget>[
                  TextButton(
                    child: Text(context.l10n!.add.toUpperCase()),
                    onPressed: () async {
                      if (mounted) {
                        // R14 fix: Persist changes properly
                        await updateCustomPlaylist(
                          widget.playlistData,
                          customPlaylistName,
                          imageUrl: imageUrl,
                        );
                        showToast(context.l10n!.playlistUpdated);
                        if (mounted) GoRouter.of(context).pop();
                      }
                    },
                  ),
                ],
              );
            },
          ),
    );
  }

  void _handleSyncPlaylist() async {
    if (_playlistData['ytid'] != null) {
      final result = await updatePlaylistList(_playlistData['ytid']);
      // R9 fix: Add mounted check after await
      if (!mounted) return;
      if (result.isSuccess) {
        // R6 fix: Update local copy, not widget.playlistData
        _playlistData.addAll(result.data ?? {});
        _songsList.clear();
        // R8 fix: Reassign _fetchFuture to refresh the data
        if (mounted) setState(() {
          _fetchFuture = fetch();
        });
      } else {
        showToast(result.toLocalizedString());
      }
    } else if (_playlistData['source'] == 'user-created') {
      setState(() {
        // R10 fix: Add null-safe access
        _songsList = _playlistData['list'] ?? [];
      });
    } else {
      final updatedPlaylist = await getPlaylistInfoForWidget(
        _playlistData,
      );
      // R10 fix: Add null guard before accessing list
      if (updatedPlaylist.isNotEmpty && mounted)
        setState(() {
          _songsList = updatedPlaylist['list'] ?? [];
        });
    }
  }
}
