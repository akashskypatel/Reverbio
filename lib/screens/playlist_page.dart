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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/playlist_sharing.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/url_launcher.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/playlist_header.dart';
import 'package:reverbio/widgets/song_list.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({
    super.key,
    this.playlistData,
    this.cardIcon = FluentIcons.music_note_1_24_regular,
    this.isArtist = false,
    required this.page,
  });
  final String page;
  final dynamic playlistData;
  final IconData cardIcon;
  final bool isArtist;

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  List<dynamic> _songsList = [];
  late ThemeData _theme;
  final FutureTracker _infoRequestFuture = FutureTracker(null);
  final _isEditEnabled = ValueNotifier(false);
  late final likeStatus = ValueNotifier<bool>(getLikeStatus());
  late final autoOffline = ValueNotifier<bool>(
    isPlaylistAlreadyOffline(widget.playlistData),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_initializePlaylist());
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool getLikeStatus() {
    if ([
      'album',
      'single',
      'ep',
      'broadcast',
      'other',
    ].contains(widget.playlistData['primary-type']?.toLowerCase()))
      return isAlbumAlreadyLiked(widget.playlistData);
    else if (widget.playlistData['ytid'] != null)
      return isPlaylistAlreadyLiked(widget.playlistData);
    return false;
  }

  Future<void> _initializePlaylist() async {
    final id = parseEntityId(widget.playlistData);
    final ids = id.toIds;
    final ytid = (ids['yt'] ?? id.ytid).ytid;
    final mbid = (ids['mb'] ?? id.mbid).mbid;
    if (mbid.isNotEmpty &&
        (widget.playlistData?['list'] == null ||
            widget.playlistData?['list'].isEmpty)) {
      await _infoRequestFuture.runFuture(
        queueAlbumInfoRequest(widget.playlistData),
      );
    } else if (ytid.isNotEmpty) {
      widget.playlistData['ytid'] = ytid;
      await _infoRequestFuture.runFuture(
        getPlaylistInfoForWidget(
          widget.playlistData,
          isArtist: widget.isArtist,
        ),
      );
    } else {
      await _infoRequestFuture.runFuture(Future.value(widget.playlistData));
    }
  }

  Future<List<dynamic>> fetch() async {
    if (!_infoRequestFuture.isComplete)
      await _infoRequestFuture.completer!.future;
    if (_infoRequestFuture.result != null) return _infoRequestFuture.result['list'] ?? [];
    //TODO: restore pagination to large playlists
    return widget.playlistData['list'] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    for (final song in _songsList) {
      song['autoCacheOffline'] = widget.playlistData['autoCacheOffline'];
    }
    return Scaffold(
      appBar: _buildNavigationBar(),
      body: _buildList() /*
          _playlist != null
              ? _buildList()
              : SizedBox(
                height: MediaQuery.sizeOf(context).height - 100,
                child: const Spinner(),
              ),*/,
    );
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
        ValueListenableBuilder(
          valueListenable: _isEditEnabled,
          builder:
              (context, value, child) => SongList(
                page: 'playlist',
                //inputData: _songsList,
                future: fetch(),
                isEditable: value,
              ),
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
        _buildAutoCacheOfflineButton(),
        if (widget.playlistData?['source'] != 'user-created')
          _buildLikeButton(),
        if (widget.playlistData != null) ...[
          _buildSyncButton(),
          if (widget.playlistData['source'] == 'user-created')
            IconButton(
              icon: const Icon(FluentIcons.share_24_regular),
              iconSize: pageHeaderIconSize,
              onPressed: () async {
                final encodedPlaylist = PlaylistSharingService.encodePlaylist(
                  widget.playlistData,
                );
                final url = 'Reverbio://playlist/custom/$encodedPlaylist';
                await Clipboard.setData(ClipboardData(text: url));
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
          if (widget.page == 'playlist' && widget.playlistData['ytid'] != null)
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
          if (widget.playlistData != null &&
              widget.playlistData['source'] == 'user-created')
            _buildEditButton(),
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
      ],
    );
  }

  dynamic _getPlaylistData() {
    final data =
        ['album', 'single', 'ep', 'broadcast', 'other'].contains(widget.page) ||
                (widget.playlistData['isAlbum'] ?? false)
            ? {
              ...(widget.playlistData as Map),
              'album': widget.playlistData['title'],
              'title': null,
            }
            : _songsList;
    return data;
  }

  Widget _buildPlaylistImage() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    return BaseCard(
      inputData: widget.playlistData,
      size: isLandscape ? 300 : screenWidth / 2.5,
      icon: widget.cardIcon,
      showLike: widget.playlistData?['source'] != 'user-created',
    );
  }

  Widget _buildPlaylistHeader() {
    return FutureBuilder(
      future: _infoRequestFuture.completer!.future,
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

  Future<bool> _confirmAutoCacheOfflineButton(BuildContext context) async {
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
                !value && await _confirmAutoCacheOfflineButton(context);

            if (newValue != value) {
              setState(() {
                autoOffline.value = newValue;
                widget.playlistData['autoCacheOffline'] = newValue;
                updateOfflinePlaylist(widget.playlistData, newValue);
              });
            }
          },
          icon:
              value
                  ? const Icon(FluentIcons.arrow_download_24_filled)
                  : const Icon(FluentIcons.arrow_download_off_24_filled),
        );
      },
    );
  }

  Widget _buildLikeButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: likeStatus,
      builder: (context, value, __) {
        return IconButton(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          icon:
              value
                  ? const Icon(FluentIcons.heart_24_filled)
                  : const Icon(FluentIcons.heart_24_regular),
          iconSize: pageHeaderIconSize,
          onPressed: () {
            if ([
              'album',
              'single',
              'ep',
              'broadcast',
              'other',
            ].contains(widget.playlistData['primary-type']?.toLowerCase()))
              updateAlbumLikeStatus(widget.playlistData, !likeStatus.value);
            else if (widget.playlistData['ytid'] != null)
              updatePlaylistLikeStatus(widget.playlistData, !likeStatus.value);
            if (mounted)
              setState(() {
                likeStatus.value = !likeStatus.value;
              });
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
                    onPressed: () {
                      if (mounted)
                        setState(() {
                          updateCustomPlaylist(
                            widget.playlistData,
                            customPlaylistName,
                            imageUrl: imageUrl,
                          );
                          showToast(context.l10n!.playlistUpdated);
                          GoRouter.of(context).pop();
                        });
                    },
                  ),
                ],
              );
            },
          ),
    );
  }

  void _handleSyncPlaylist() async {
    if (widget.playlistData['ytid'] != null) {
      widget.playlistData.addAll(
        await updatePlaylistList(context, widget.playlistData['ytid']),
      );
      _songsList.clear();
      if (mounted) setState(fetch);
    } else if (widget.playlistData['source'] == 'user-created') {
      setState(() {
        _songsList = widget.playlistData['list'] ?? [];
      });
    } else {
      final updatedPlaylist = await getPlaylistInfoForWidget(
        widget.playlistData,
      );
      if (updatedPlaylist.isNotEmpty) {
        if (mounted)
          setState(() {
            _songsList = updatedPlaylist['list'];
          });
      }
    }
  }

  void _updateSongsListOnRemove(int indexOfRemovedSong) {
    final dynamic songToRemove = _songsList.elementAt(indexOfRemovedSong);
    showToastWithButton(
      context.l10n!.songRemoved,
      context.l10n!.undo.toUpperCase(),
      () {
        addSongToCustomPlaylist(
          context,
          widget.playlistData['title'],
          songToRemove,
          indexToInsert: indexOfRemovedSong,
        );
        _songsList.insert(indexOfRemovedSong, songToRemove);
        if (mounted) setState(() {});
      },
    );
    if (mounted)
      setState(() {
        _songsList.removeAt(indexOfRemovedSong);
      });
  }

  Widget _buildSortSongActionButton() {
    return DropdownButton<String>(
      borderRadius: BorderRadius.circular(5),
      dropdownColor: _theme.colorScheme.secondaryContainer,
      underline: const SizedBox.shrink(),
      iconEnabledColor: _theme.colorScheme.primary,
      elevation: 0,
      iconSize: 30,
      icon: const Icon(FluentIcons.filter_16_filled),
      items:
          <String>[context.l10n!.name, context.l10n!.artist].map((
            String value,
          ) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
      onChanged: (item) {
        if (mounted)
          setState(() {
            final playlist = widget.playlistData['list'] ?? [];

            void sortBy(String key) {
              playlist.sort((a, b) {
                final valueA = a[key].toString().toLowerCase();
                final valueB = b[key].toString().toLowerCase();
                return valueA.compareTo(valueB);
              });
            }

            if (item == context.l10n!.name) {
              sortBy('title');
            } else if (item == context.l10n!.artist) {
              sortBy('artist');
            }

            widget.playlistData['list'] = playlist;

            // Reset pagination and reload
            _songsList.clear();
            fetch();
          });
      },
    );
  }
}
