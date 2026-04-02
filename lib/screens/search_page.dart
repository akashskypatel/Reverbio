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

import 'dart:async';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/screens/artist_page.dart';
import 'package:reverbio/screens/playlist_page.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/animated_heart.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/custom_bar.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
import 'package:reverbio/widgets/expanding_toolbar.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/song_list.dart';
import 'package:reverbio/widgets/spinner.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  // R6 fix: Dispose _fetching in dispose()
  final ValueNotifier<bool> _fetching = ValueNotifier(false);
  late ThemeData _theme;
  int maxSongsInList = 15;
  // R1 fix: Use request ID to track and cancel stale requests
  int _requestId = 0;
  final itemsNumber = recommendedCardsNumber;
  Map _suggestionList = {};
  final _submitLimit = 10;
  final _suggestionLimit = 10;

  @override
  void dispose() {
    _searchBar.dispose();
    _inputNode.dispose();
    _fetching.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> search({dynamic data, CustomBar? bar}) async {
    if (data == null) return;
    if (!(data is String)) {
      switch (data['entity']) {
        case 'artist':
        case 'artists':
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ArtistPage(page: '/artist', artistData: data),
              settings: RouteSettings(name: '/artist?${data['id']}'),
            ),
          );
        case 'album':
        case 'albums':
        case 'release-group':
        case 'release-groups':
        case 'playlist':
        case 'playlists':
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PlaylistPage(
                    page: '/album',
                    playlistData: Map<String, dynamic>.from(data),
                  ),
              settings: RouteSettings(name: '/album?${data['id']}'),
            ),
          );
        case 'youtube':
          await _setSearchFuture(
            data['value'],
            limit: _submitLimit,
            minimal: false,
            maxScore: 50,
          );
          if (mounted)
            setState(() {
              _searchBar.text = data['value'];
            });
        default:
      }
    } else {
      await _setSearchFuture(
        data,
        limit: _submitLimit,
        minimal: false,
        maxScore: 50,
      );
      if (mounted)
        setState(() {
          _searchBar.text = data;
        });
    }
    // R9/R10 fix: Add size cap and prevent empty strings
    final query = _searchBar.text.trim();
    if (query.isNotEmpty && !searchHistory.contains(query)) {
      if (mounted)
        setState(() {
          // R9 fix: Cap search history at 50 items
          if (searchHistory.length >= 50) {
            searchHistory.removeLast();
          }
          // R11 fix: Remove duplicate if exists and move to front
          searchHistory.remove(query);
          searchHistory.insert(0, query);
        });
    }
  }

  // R1 fix: Use request ID to track and cancel stale requests
  Future<void> _setSearchFuture(
    String value, {
    int? limit,
    int maxScore = 0,
    int offset = 0,
    bool minimal = true,
    String? entity,
    dynamic resultList,
  }) async {
    _fetching.value = true;
    // R1 fix: Increment request ID to cancel previous request
    _requestId++;
    final currentRequestId = _requestId;
    // R2 fix: Clear stale cache when query changes
    if (value != _searchBar.text) {
      _suggestionList.clear();
    }
    try {
      final result = await getAllSearchSuggestions(
        value,
        limit: limit,
        offset: offset,
        minimal: minimal,
        maxScore: maxScore,
        entity: entity,
        resultList: resultList,
      );
      // Only update if this is still the current request
      if (currentRequestId == _requestId && mounted) {
        setState(() {
          _suggestionList = result;
          _fetching.value = false;
        });
      }
    } catch (error) {
      // Only update if this is still the current request
      if (currentRequestId == _requestId && mounted) {
        setState(() {
          _fetching.value = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n!.search),
        actions: [
          ExpandingToolbar(
            actions: [
              SizedBox.square(
                dimension: pageHeaderIconSize + 16,
                child: ValueListenableBuilder(
                  valueListenable: _fetching,
                  builder:
                      (context, value, __) =>
                          value
                              ? const Padding(
                                padding: EdgeInsetsGeometry.all(8),
                                child: Spinner(),
                              )
                              : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.topCenter,
              child: CustomSearchBar(
                searchDelayMs: 200,
                loadingProgressNotifier: _fetching,
                controller: _searchBar,
                focusNode: _inputNode,
                labelText: '${context.l10n!.search}...',
                onChanged: (value) async {
                  if (value.isNotEmpty) {
                    await _setSearchFuture(
                      value,
                      limit: _suggestionLimit,
                      maxScore: 50,
                    );
                  } else {
                    _fetching.value = false;
                    // R1 fix: Increment request ID to cancel previous request
                    _requestId++;
                    // R2 fix: Clear stale cache
                    _suggestionList.clear();
                  }
                  if (mounted) setState(() {});
                },
                onSubmitted: (String value) async {
                  await search(data: value);
                  _inputNode.unfocus();
                },
              ),
            ),
            // R1 fix: Show history when no search, suggestions when searching
            if (_requestId == 0 && _searchBar.text.isEmpty)
              _buildSearchSubList('history', {
                'count': searchHistory.length,
                'offset': 0,
                'data': searchHistory,
              }),
            if (_requestId > 0 && _searchBar.text.isNotEmpty)
              _buildSuggestionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSubList(String header, dynamic suggestionList) {
    final entityName = <String, Map<String, dynamic>>{
      'artist': {
        'localization': context.l10n!.artists,
        'icon': FluentIcons.mic_sparkle_24_filled,
        'action': updateArtistLikeStatus,
        'getLiked': isArtistAlreadyLiked,
      },
      'artists': {
        'localization': context.l10n!.artists,
        'icon': FluentIcons.mic_sparkle_24_filled,
        'action': updateArtistLikeStatus,
        'getLiked': isArtistAlreadyLiked,
      },
      'album': {
        'localization': context.l10n!.albums,
        'icon': FluentIcons.cd_16_filled,
        'action': updateAlbumLikeStatus,
        'getLiked': isAlbumAlreadyLiked,
      },
      'albums': {
        'localization': context.l10n!.albums,
        'icon': FluentIcons.cd_16_filled,
        'action': updateAlbumLikeStatus,
        'getLiked': isAlbumAlreadyLiked,
      },
      'release-group': {
        'localization': context.l10n!.albums,
        'icon': FluentIcons.cd_16_filled,
        'action': updateAlbumLikeStatus,
        'getLiked': isAlbumAlreadyLiked,
      },
      'release-groups': {
        'localization': context.l10n!.albums,
        'icon': FluentIcons.cd_16_filled,
        'action': updateAlbumLikeStatus,
        'getLiked': isAlbumAlreadyLiked,
      },
      'song': {
        'localization': context.l10n!.songs,
        'icon': FluentIcons.music_note_2_24_filled,
        'action': updateSongLikeStatus,
        'getLiked': isSongAlreadyLiked,
      },
      'songs': {
        'localization': context.l10n!.songs,
        'icon': FluentIcons.music_note_2_24_filled,
        'action': updateSongLikeStatus,
        'getLiked': isSongAlreadyLiked,
      },
      'recording': {
        'localization': context.l10n!.songs,
        'icon': FluentIcons.music_note_2_24_filled,
        'action': updateSongLikeStatus,
        'getLiked': isSongAlreadyLiked,
      },
      'recordings': {
        'localization': context.l10n!.songs,
        'icon': FluentIcons.music_note_2_24_filled,
        'action': updateSongLikeStatus,
        'getLiked': isSongAlreadyLiked,
      },
      'playlist': {
        'localization': context.l10n!.playlists,
        'icon': Icons.playlist_play,
        'trailing': FluentIcons.play_circle_24_filled,
        'action': updatePlaylistLikeStatus,
        'getLiked': isPlaylistAlreadyLiked,
      },
      'playlists': {
        'localization': context.l10n!.playlists,
        'icon': Icons.playlist_play,
        'trailing': FluentIcons.play_circle_24_filled,
        'action': updatePlaylistLikeStatus,
        'getLiked': isPlaylistAlreadyLiked,
      },
    };
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      slivers: [
        if ([
          'song',
          'songs',
          'recording',
          'recordings',
        ].contains(header.toLowerCase()))
          SongList(
            title: entityName[header.toLowerCase()]!['localization']!,
            page: 'search',
            songMaps: NotifiableList<Map<String, dynamic>>.from(
              suggestionList['data'] as List<Map<String, dynamic>>,
            ),
            expandedActions: _buildPrevNextButtons(header, suggestionList),
          )
        else
          SliverMainAxisGroup(
            slivers: [
              if (entityName[header.toLowerCase()]?['localization'] != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: commonSingleChildScrollViewPadding,
                    child: SectionHeader(
                      title: entityName[header.toLowerCase()]!['localization']!,
                      actions: _buildPrevNextButtons(header, suggestionList),
                      actionsExpanded: true,
                    ),
                  ),
                ),
              ..._getItems(header, suggestionList, entityName),
            ],
          ),
      ],
    );
  }

  List<Widget> _buildPrevNextButtons(String header, dynamic suggestionList) {
    return [
      IconButton(
        onPressed:
            (suggestionList['offset'] ?? 0) > 0
                ? () async {
                  final _limit = header == 'playlist' ? 20 : _submitLimit;
                  final offset = math.max(
                    0,
                    (suggestionList['offset'] ?? 0) - _limit,
                  );
                  await _setSearchFuture(
                    _searchBar.text,
                    limit: _limit,
                    offset: offset,
                    minimal: false,
                    maxScore: 50,
                    entity: header.toLowerCase(),
                    resultList: suggestionList['resultList'],
                  );
                }
                : null,
        icon: Icon(
          FluentIcons.chevron_left_24_filled,
          color:
              (suggestionList['offset'] ?? 0) > 0
                  ? _theme.colorScheme.primary
                  : _theme.colorScheme.inversePrimary,
        ),
      ),
      IconButton(
        onPressed:
            // R8 fix: Check if we've reached end of results
            (suggestionList['data'] ?? []).isNotEmpty &&
                    (suggestionList['data'] as List).length >=
                        (header == 'playlist' ? 20 : _submitLimit)
                ? () async {
                  final _limit = header == 'playlist' ? 20 : _submitLimit;
                  final offset = (suggestionList['offset'] ?? 0) + _limit;
                  await _setSearchFuture(
                    _searchBar.text,
                    limit: _limit,
                    offset: offset,
                    minimal: false,
                    maxScore: 50,
                    entity: header.toLowerCase(),
                    resultList: suggestionList['resultList'],
                  );
                }
                : null,
        icon: Icon(
          FluentIcons.chevron_right_24_filled,
          color:
              (suggestionList['data'] ?? []).isNotEmpty
                  ? _theme.colorScheme.primary
                  : _theme.colorScheme.inversePrimary,
        ),
      ),
    ];
  }

  List<Widget> _getItems(
    String header,
    dynamic suggestionList,
    Map<String, Map<String, dynamic>> entityName,
  ) {
    header = header.toLowerCase();
    int index = 0;
    return (suggestionList['data'] as List).fold([], (list, element) {
      final element = suggestionList['data'][index];
      final query =
          element is String
              ? element
              : element['value'] +
                  (element['artist'] != null ? ' by ${element['artist']}' : '');
      final borderRadius = getItemBorderRadius(
        index,
        suggestionList['data'].length,
      );
      bool isLiked =
          entityName[header]?['getLiked'] != null &&
          entityName[header]!['getLiked']!(element) as bool;
      final entityLikeStatus = ValueNotifier(isLiked);
      final likedLoading = ValueNotifier(false);
      list.add(
        StatefulBuilder(
          builder: (ctx, setState) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: commonSingleChildScrollViewPadding,
                child: GestureDetector(
                  // R3 fix: Add empty onDoubleTap to prevent tap delay
                  onDoubleTap: () {},
                  onDoubleTapDown: (details) async {
                    likedLoading.value = true;
                    final like = await entityName[header]?['action'](
                      element,
                      !entityLikeStatus.value,
                    );
                    if (ctx.mounted)
                      setState(() {
                        isLiked = entityLikeStatus.value = like;
                        likedLoading.value = false;
                      });
                    AnimatedHeart.show(
                      context: context,
                      details: details,
                      like: like,
                    );
                  },
                  child: CustomBar(
                    tileName: query,
                    tileIcon:
                        entityName[header]?['icon'] ??
                        FluentIcons.search_24_regular,
                    borderRadius: borderRadius,
                    onTap: () async {
                      await search(data: element);
                      _inputNode.unfocus();
                    },
                    // R4 fix: Only show removal for history items
                    onLongPress:
                        header == 'history'
                            ? () async {
                              final confirm =
                                  await _showConfirmationDialog(ctx) ?? false;
                              if (confirm) {
                                if (ctx.mounted)
                                  setState(() {
                                    searchHistory.remove(query);
                                  });
                              }
                            }
                            : null,
                    trailing:
                        entityName[header]?['action'] != null
                            ? ValueListenableBuilder(
                              valueListenable: entityLikeStatus,
                              builder: (context, value, __) {
                                return IconButton(
                                  onPressed: () async {
                                    likedLoading.value = true;
                                    final likeVal =
                                        await entityName[header]?['action'](
                                          element,
                                          !value,
                                        );
                                    if (context.mounted)
                                      setState(() {
                                        isLiked =
                                            entityLikeStatus.value = likeVal;
                                        likedLoading.value = false;
                                      });
                                  },
                                  icon: Icon(
                                    isLiked
                                        ? FluentIcons.heart_24_filled
                                        : FluentIcons.heart_24_regular,
                                  ),
                                );
                              },
                            )
                            : null,
                  ),
                ),
              ),
            );
          },
        ),
      );
      index++;
      return list;
    });
  }

  Widget _buildSuggestionList() {
    // R2 fix: Show cached suggestions while loading
    final suggestions = Map<String, dynamic>.from(_suggestionList);
    return Column(
      children:
          suggestions.entries
              .map((e) => _buildSearchSubList(e.key, e.value))
              .toList(),
    );
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
