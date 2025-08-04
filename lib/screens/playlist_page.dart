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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/playlist_sharing.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/playlist_header.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:reverbio/widgets/song_list.dart';
import 'package:reverbio/widgets/spinner.dart';

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
  dynamic _playlist;
  late ThemeData _theme;
  bool _isLoading = true;
  var _currentLastLoadedId = 0;
  late final likeStatus = ValueNotifier<bool>(getLikeStatus());

  @override
  void initState() {
    super.initState();
    _initializePlaylist();
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool getLikeStatus() {
    if ([
      'artist',
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
    if (widget.playlistData?['source'] == 'musicbrainz') {
      await getTrackList(widget.playlistData);
    }
    if (widget.playlistData['id'] != null &&
        widget.playlistData['id']?.contains('yt=')) {
      final uri = Uri.parse('?${widget.playlistData['id']}');
      widget.playlistData['ytid'] = uri.queryParameters['yt'];
    }

    _playlist =
        widget.playlistData['list'] != null &&
                widget.playlistData['list'].length > 0
            ? widget.playlistData
            : (widget.playlistData['source'] == 'user-created'
                ? userCustomPlaylists.value.firstWhere(
                  (playlist) =>
                      playlist['title'] == widget.playlistData['title'],
                  orElse: () => null,
                )
                : (widget.playlistData['ytid'] != null
                    ? await getPlaylistInfoForWidget(
                      widget.playlistData,
                      isArtist: widget.isArtist,
                    )
                    : ([
                          'artist',
                          'album',
                          'single',
                          'ep',
                          'broadcast',
                          'other',
                        ].contains(
                          widget.playlistData['primary-type']?.toLowerCase(),
                        )
                        ? await getAlbumDetailsById(widget.playlistData)
                        : null)));

    if (_playlist != null) {
      _loadMore();
    }
  }

  void _loadMore() {
    _isLoading = true;
    fetch().then((List<dynamic> fetchedList) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (fetchedList.isNotEmpty) {
            _songsList.addAll(fetchedList);
          }
        });
      }
    });
  }

  Future<List<dynamic>> fetch() async {
    final list = <dynamic>[];
    if (_playlist['list'] == null) return list;
    final _count = _playlist['list'].length as int;
    //TODO: restore pagination to large playlists
    for (var i = 0; i < _count; i++) {
      list.add(_playlist['list'][_currentLastLoadedId]);
      _currentLastLoadedId++;
    }

    //_currentPage++;
    return list;
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Scaffold(
      appBar: _buildNavigationBar(),
      body:
          _playlist != null
              ? _buildList()
              : SizedBox(
                height: MediaQuery.sizeOf(context).height - 100,
                child: const Spinner(),
              ),
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
        SongList(
          page: 'playlist',
          inputData: _songsList,
          isEditable: _playlist['source'] == ['user-created'],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildNavigationBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        iconSize: pageHeaderIconSize,
        onPressed:
            () => GoRouter.of(context).pop(),
      ),
      actions: [
        _buildLikeButton(),
        const SizedBox(width: 10),
        if (_playlist != null) ...[
          _buildSyncButton(),
          const SizedBox(width: 10),
          if (_playlist['source'] == 'user-created')
            IconButton(
              icon: const Icon(FluentIcons.share_24_regular),
              iconSize: pageHeaderIconSize,
              onPressed: () async {
                final encodedPlaylist = PlaylistSharingService.encodePlaylist(
                  _playlist,
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
          if (_playlist != null && _playlist['source'] == 'user-created')
            _buildEditButton(),
          if (kDebugMode) const SizedBox(width: 24, height: 24),
        ],
      ],
    );
  }

  dynamic _getPlaylistData() {
    final data =
        ['album', 'single', 'ep', 'broadcast', 'other'].contains(widget.page) ||
                (_playlist['isAlbum'] ?? false)
            ? {
              ...(_playlist as Map),
              'album': _playlist['title'],
              'title': null,
            }
            : _songsList;
    return data;
  }

  Widget _buildPlaylistImage() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    return BaseCard(
      inputData: _playlist,
      size: isLandscape ? 300 : screenWidth / 2.5,
      icon: widget.cardIcon,
      showLike: true,
    );
  }

  Widget _buildPlaylistHeader() {
    final _songsLength =
        _playlist['list'] == null ? 0 : _playlist['list'].length;

    return PlaylistHeader(
      _buildPlaylistImage(),
      ['album', 'single', 'ep', 'broadcast', 'other'].contains(widget.page)
          ? _playlist['artist'] != null
              ? '${_playlist['artist']} - ${_playlist['title']}'
              : _playlist['title']
          : _playlist['title'],
      _songsLength,
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
              'artist',
              'album',
              'single',
              'ep',
              'broadcast',
              'other',
            ].contains(widget.playlistData['primary-type']?.toLowerCase()))
              updateAlbumLikeStatus(widget.playlistData, !likeStatus.value);
            else if (widget.playlistData['ytid'] != null)
              updatePlaylistLikeStatus(_playlist, !likeStatus.value);
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
            builder: (BuildContext context) {
              var customPlaylistName = _playlist['title'];
              var imageUrl = _playlist['image'];

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
                          final index = userCustomPlaylists.value.indexOf(
                            widget.playlistData,
                          );

                          if (index != -1) {
                            final newPlaylist = {
                              'id':
                                  'uc=${customPlaylistName.replaceAll(r'\s+', '_')}',
                              'title': customPlaylistName,
                              'source': 'user-created',
                              'primary-type': 'playlist',
                              if (imageUrl != null) 'image': imageUrl,
                              'list': widget.playlistData['list'],
                            };
                            final updatedPlaylists = List<Map>.from(
                              userCustomPlaylists.value,
                            );
                            updatedPlaylists[index] = newPlaylist;
                            userCustomPlaylists.value = updatedPlaylists;
                            addOrUpdateData(
                              'user',
                              'customPlaylists',
                              updatedPlaylists,
                            );
                            _playlist = newPlaylist;
                            showToast(context.l10n!.playlistUpdated);
                          }
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
    if (_playlist['ytid'] != null) {
      _playlist = await updatePlaylistList(context, _playlist['ytid']);
      _songsList.clear();
      if (mounted)
        setState(() {
          _currentLastLoadedId = 0;
          _loadMore();
        });
    } else if (_playlist['source'] == 'user-created') {
      setState(() {
        _songsList = _playlist['list'] ?? [];
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
        addSongInCustomPlaylist(
          context,
          _playlist['title'],
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
            final playlist = _playlist['list'] ?? [];

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

            _playlist['list'] = playlist;

            // Reset pagination and reload
            _songsList.clear();
            _currentLastLoadedId = 0;
            _loadMore();
          });
      },
    );
  }

  Widget _buildSongListItem(int index, bool isRemovable) {
    if (index >= _songsList.length) {
      if (!_isLoading) {
        _loadMore();
      }
      return const Spinner();
    }

    final borderRadius = getItemBorderRadius(index, _songsList.length);

    return SongBar(
      _songsList[index],
      onRemove:
          isRemovable
              ? () => {
                if (removeSongFromPlaylist(
                  _playlist,
                  _songsList[index],
                  removeOneAtIndex: index,
                ))
                  {_updateSongsListOnRemove(index)},
              }
              : null,
      borderRadius: borderRadius,
      showMusicDuration: true,
    );
  }
}
