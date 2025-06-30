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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/custom_bar.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
import 'package:reverbio/widgets/horizontal_card_scroller.dart';
import 'package:reverbio/widgets/playlist_bar.dart';
import 'package:reverbio/widgets/section_title.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:reverbio/widgets/spinner.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

List searchHistory = Hive.box('user').get('searchHistory', defaultValue: []);

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetching = ValueNotifier(false);
  int maxSongsInList = 15;
  Future<dynamic>? _artistSearchFuture;
  Future<dynamic>? _songsSearchFuture;
  Future<dynamic>? _albumsSearchFuture;
  Future<dynamic>? _playlistsSearchFuture;
  List _suggestionsList = [];
  final itemsNumber = recommendedCardsNumber;
  int _stillSearching = 0;
  @override
  void dispose() {
    _searchBar.dispose();
    _inputNode.dispose();
    _artistSearchFuture?.ignore();
    _songsSearchFuture?.ignore();
    _albumsSearchFuture?.ignore();
    _playlistsSearchFuture?.ignore();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> search() async {
    //TODO: add genre search
    final query = _searchBar.text;

    if (query.isEmpty) {
      _suggestionsList = [];
      if (mounted) setState(() {});
      return;
    }

    _fetching.value = true;

    if (!searchHistory.contains(query)) {
      searchHistory.insert(0, query);
      addOrUpdateData('user', 'searchHistory', searchHistory);
    }

    _setFutures(query);
    if (mounted) setState(() {});
  }

  void _setFutures(String query) {
    try {
      _stillSearching = 4;
      _artistSearchFuture = searchArtistsDetails(
        [query],
        exact: false,
        limit: itemsNumber,
        paginated: true,
      );
      _songsSearchFuture = getSongsList(query);
      _albumsSearchFuture = getPlaylists(query: query, type: 'album');
      _playlistsSearchFuture = getPlaylists(query: query, type: 'playlist');
      _artistSearchFuture?.asStream().listen((data) => {}).onDone(() {
        _stillSearching--;
        _fetching.value = _stillSearching > 0;
      });
      _songsSearchFuture?.asStream().listen((data) => {}).onDone(() {
        _stillSearching--;
        _fetching.value = _stillSearching > 0;
      });
      _albumsSearchFuture?.asStream().listen((data) => {}).onDone(() {
        _stillSearching--;
        _fetching.value = _stillSearching > 0;
      });
      _playlistsSearchFuture?.asStream().listen((data) => {}).onDone(() {
        _stillSearching--;
        _fetching.value = _stillSearching > 0;
      });
    } catch (e, stackTrace) {
      logger.log('Error while searching online songs', e, stackTrace);
      _stillSearching = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.search)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            CustomSearchBar(
              loadingProgressNotifier: _fetching,
              controller: _searchBar,
              focusNode: _inputNode,
              labelText: '${context.l10n!.search}...',
              /* onChanged: (value) async {
                if (value.isNotEmpty) {
                  _suggestionsList = await getSearchSuggestions(value);
                } else {
                  _suggestionsList = [];
                }
                if (mounted) setState(() {});
              }, */
              onSubmitted: (String value) {
                search();
                _suggestionsList = [];
                _inputNode.unfocus();
              },
            ),
            if (_songsSearchFuture == null && _albumsSearchFuture == null)
              ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 7),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount:
                    _suggestionsList.isEmpty
                        ? searchHistory.length
                        : _suggestionsList.length,
                itemBuilder: (BuildContext context, int index) {
                  final suggestionsNotAvailable = _suggestionsList.isEmpty;
                  final query =
                      suggestionsNotAvailable
                          ? searchHistory[index]
                          : _suggestionsList[index];

                  final borderRadius = getItemBorderRadius(
                    index,
                    _suggestionsList.isEmpty
                        ? searchHistory.length
                        : _suggestionsList.length,
                  );

                  return CustomBar(
                    query,
                    FluentIcons.search_24_regular,
                    borderRadius: borderRadius,
                    onTap: () async {
                      _searchBar.text = query;
                      await search();
                      _inputNode.unfocus();
                    },
                    onLongPress: () async {
                      final confirm =
                          await _showConfirmationDialog(context) ?? false;

                      if (confirm) {
                        if (mounted)
                          setState(() {
                            searchHistory.remove(query);
                          });

                        addOrUpdateData('user', 'searchHistory', searchHistory);
                      }
                    },
                  );
                },
              )
            else
              Column(
                children: [
                  FutureBuilder(
                    future: _artistSearchFuture,
                    builder: _buildArtistList,
                  ),
                  FutureBuilder(
                    future: _albumsSearchFuture,
                    builder: _buildAlbumList,
                  ),
                  FutureBuilder(
                    future: _playlistsSearchFuture,
                    builder: _buildPlaylistList,
                  ),
                  FutureBuilder(
                    future: _songsSearchFuture,
                    builder: _buildSongList,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistList(BuildContext context, AsyncSnapshot snapshot) {
    if (snapshot.connectionState == ConnectionState.done &&
        snapshot.hasData &&
        snapshot.data.isNotEmpty)
      return HorizontalCardScroller(
        icon: FluentIcons.mic_sparkle_24_filled,
        title: context.l10n!.artist,
        future: Future.value(snapshot.data),
      );
    if (snapshot.connectionState == ConnectionState.waiting)
      return Column(
        children: [
          SectionTitle(
            context.l10n!.artist,
            Theme.of(context).colorScheme.primary,
          ),
          const Center(
            child: Padding(padding: EdgeInsets.all(35), child: Spinner()),
          ),
        ],
      );
    return const SizedBox.shrink();
  }

  Widget _buildSongList(BuildContext context, AsyncSnapshot snapshot) {
    if (snapshot.connectionState == ConnectionState.done &&
        snapshot.hasData &&
        snapshot.data.isNotEmpty)
      return Column(
        children: [
          SectionTitle(
            context.l10n!.songs,
            Theme.of(context).colorScheme.primary,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(7),
            itemCount:
                snapshot.data.length > maxSongsInList
                    ? maxSongsInList
                    : snapshot.data.length,
            itemBuilder: (BuildContext context, int index) {
              final borderRadius = getItemBorderRadius(
                index,
                snapshot.data.length > maxSongsInList
                    ? maxSongsInList
                    : snapshot.data.length,
              );
              return SongBar(
                snapshot.data[index],
                showMusicDuration: true,
                borderRadius: borderRadius,
              );
            },
          ),
        ],
      );
    if (snapshot.connectionState == ConnectionState.waiting)
      return Column(
        children: [
          SectionTitle(
            context.l10n!.songs,
            Theme.of(context).colorScheme.primary,
          ),
          const Center(
            child: Padding(padding: EdgeInsets.all(35), child: Spinner()),
          ),
        ],
      );
    return const SizedBox.shrink();
  }

  Widget _buildAlbumList(BuildContext context, AsyncSnapshot snapshot) {
    if (snapshot.connectionState == ConnectionState.done &&
        snapshot.hasData &&
        snapshot.data.isNotEmpty)
      return Column(
        children: [
          SectionTitle(
            context.l10n!.albums,
            Theme.of(context).colorScheme.primary,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount:
                snapshot.data.length > maxSongsInList
                    ? maxSongsInList
                    : snapshot.data.length,
            itemBuilder: (BuildContext context, int index) {
              final playlist = snapshot.data[index];

              final borderRadius = getItemBorderRadius(
                index,
                snapshot.data.length > maxSongsInList
                    ? maxSongsInList
                    : snapshot.data.length,
              );

              return PlaylistBar(
                key: ValueKey(playlist['ytid']),
                playlist['title'],
                playlistId: playlist['ytid'],
                playlistArtwork: playlist['image'],
                cardIcon: FluentIcons.cd_16_filled,
                isAlbum: true,
                borderRadius: borderRadius,
              );
            },
          ),
        ],
      );
    if (snapshot.connectionState == ConnectionState.waiting)
      return Column(
        children: [
          SectionTitle(
            context.l10n!.albums,
            Theme.of(context).colorScheme.primary,
          ),
          const Center(
            child: Padding(padding: EdgeInsets.all(35), child: Spinner()),
          ),
        ],
      );
    return const SizedBox.shrink();
  }

  Widget _buildPlaylistList(BuildContext context, AsyncSnapshot snapshot) {
    if (snapshot.connectionState == ConnectionState.done &&
        snapshot.hasData &&
        snapshot.data.isNotEmpty)
      return Column(
        children: [
          SectionTitle(
            context.l10n!.playlists,
            Theme.of(context).colorScheme.primary,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: commonListViewBottmomPadding,
            itemCount:
                snapshot.data.length > maxSongsInList
                    ? maxSongsInList
                    : snapshot.data.length,
            itemBuilder: (BuildContext context, int index) {
              final playlist = snapshot.data[index];
              return PlaylistBar(
                key: ValueKey(playlist['ytid']),
                playlist['title'],
                playlistId: playlist['ytid'],
                playlistArtwork: playlist['image'],
                cardIcon: FluentIcons.apps_list_24_filled,
              );
            },
          ),
        ],
      );
    if (snapshot.connectionState == ConnectionState.waiting)
      return Column(
        children: [
          SectionTitle(
            context.l10n!.playlist,
            Theme.of(context).colorScheme.primary,
          ),
          const Center(
            child: Padding(padding: EdgeInsets.all(35), child: Spinner()),
          ),
        ],
      );
    return const SizedBox.shrink();
  }

  Future<bool?> _showConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          message: context.l10n!.removeSearchQueryQuestion,
          confirmText: context.l10n!.confirm,
          cancelText: context.l10n!.cancel,
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }
}
