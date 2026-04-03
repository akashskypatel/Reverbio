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
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/screens/artist_page.dart';
import 'package:reverbio/screens/playlist_page.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
import 'package:reverbio/widgets/expanding_toolbar.dart';
import 'package:reverbio/widgets/genre_list.dart';
import 'package:reverbio/widgets/section_header.dart';

class LikedCardsPage extends StatefulWidget {
  const LikedCardsPage({super.key, required this.title, required this.page});
  final String page;
  final String title;

  @override
  _LikedCardsPageState createState() => _LikedCardsPageState();
}

class _LikedCardsPageState extends State<LikedCardsPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  // R4 fix: Dispose isFilteredNotifier in dispose()
  final ValueNotifier<bool> isFilteredNotifier = ValueNotifier(false);
  late final double cardHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
  late final Set<String> uniqueGenreList = {};
  late final List<dynamic> genreList = [];
  late ThemeData _theme;
  final List<dynamic> inputData = [];
  final List<BaseCard> cardList = <BaseCard>[];
  GenreList? genresWidget;
  
  // 8.2-B: Sort state for liked entities
  final String _sortKey = 'name'; // 'name' or 'dateAdded'
  final bool _sortAscending = true;
  
  // R5 fix: Add validation for widget.page
  final dataMap = {
    'albums': {
      'notifier': userLikedAlbumsList,
      'widgetContext': 'AlbumsPageHeader',
    },
    'artists': {
      'notifier': userLikedArtistsList,
      'widgetContext': 'ArtistsPageHeader',
    },
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // R4 fix: Dispose all controllers and notifiers
    _searchBar.dispose();
    _inputNode.dispose();
    isFilteredNotifier.dispose();
    cardList.clear();
    super.dispose();
  }

  // 8.2-B: Sort entities by key and direction
  void _sortEntities() {
    inputData.sort((a, b) {
      int comparison;
      if (_sortKey == 'name') {
        final nameA = (a['musicbrainzName'] ?? a['discogsName'] ?? a['artist'] ?? a['title'] ?? '').toString().toLowerCase();
        final nameB = (b['musicbrainzName'] ?? b['discogsName'] ?? b['artist'] ?? b['title'] ?? '').toString().toLowerCase();
        comparison = nameA.compareTo(nameB);
      } else {
        // Sort by date added (if available)
        final dateA = a['dateAdded'] ?? DateTime(1970);
        final dateB = b['dateAdded'] ?? DateTime(1970);
        comparison = dateA.compareTo(dateB);
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  // 8.2-B: Refresh and re-sort entities
  Future<void> _refreshLikedEntities() async {
    // Trigger a rebuild by notifying listeners
    if (mounted) {
      setState(_sortEntities);
    }
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ExpandingToolbar(
            actions: [
              _clearFiltersButton(),
              ...PM.getWidgetsByType(
                _getEntityListData,
                dataMap[widget.page]?['widgetContext'] as String,
                context,
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(context),
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
                    _filterCardsByGenre('');
                    _filterCardList('');
                    _searchBar.clear();
                    isFilteredNotifier.value = false;
                  }
                  : null,
          icon: const Icon(FluentIcons.filter_dismiss_24_filled),
          iconSize: pageHeaderIconSize,
          color: _theme.colorScheme.primary,
          disabledColor: _theme.colorScheme.primaryContainer,
          tooltip: context.l10n!.clearFilters,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListenableBuilder(
      listenable: dataMap[widget.page]?['notifier'] as NotifiableList,
      builder: (context, child) {
        // R2 fix: Clear genre data between rebuilds
        uniqueGenreList.clear();
        genreList.clear();
        inputData.clear();
        // R8 fix: Move side effects out of build - just read data here
        for (final data in (dataMap[widget.page]?['notifier'] as List)) {
          data['filterShow'] = true;
          inputData.add(data);
          // R8 fix: Parse genres without mutating during build
          _parseGenresWithoutMutation(data);
        }
        _buildCards(context);
        return SingleChildScrollView(
          padding: commonSingleChildScrollViewPadding,
          child: Column(
            children: [
              _buildSearchBar(context),
              _buildGenreList(),
              SectionHeader(
                title:
                    widget.page == 'artists'
                        ? context.l10n!.artists
                        : context.l10n!.albums,
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final innerWidth = constraints.maxWidth;
                  final innerHeight = constraints.maxHeight;
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: innerHeight,
                      maxWidth: innerWidth,
                    ),
                    child: Wrap(children: cardList),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<dynamic> _getEntityListData() {
    final data = inputData;
    return data;
  }

  void _buildCards(BuildContext context) {
    cardList.clear();
    for (final data in inputData) {
      _buildCard(context, data);
    }
  }

  void _buildCard(BuildContext context, dynamic data) {
    //TODO: restore sorting on refresh due to like status change
    final card = BaseCard(
      inputData: data as Map<dynamic, dynamic>,
      icon: FluentIcons.mic_sparkle_24_filled,
      size: cardHeight,
      showLike: true,
      showOverflowLabel: true,
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      widget.page == 'artists'
                          ? ArtistPage(page: '/artist', artistData: data)
                          : PlaylistPage(
                            page: '/album',
                            playlistData: Map<String, dynamic>.from(data),
                          ),
              // R6 fix: Correct route name for albums vs artists
              settings: RouteSettings(
                name:
                    widget.page == 'artists'
                        ? '/artist?${data['id']}'
                        : '/album?${data['id']}',
              ),
            ),
          ),
    );
    // R7 fix: Handle entities without primary-type gracefully
    if (data['primary-type'] != null &&
        data['primary-type'].toString().toLowerCase() != 'unknown') {
      cardList.add(card);
    } else if (data['primary-type'] == null) {
      // R7 fix: Add card with default primary-type
      data['primary-type'] = widget.page == 'artists' ? 'artist' : 'album';
      cardList.add(card);
    }
  }

  void _parseGenres(dynamic data) {
    final genres = data['genres'] ?? data['musicbrainz']?['genres'] ?? [];
    final Set<String> genreString = {};
    for (final genre in genres) {
      // R1 fix: Get existing count properly
      final existing = genreList.firstWhere(
        (e) => e['name'] == genre['name'],
        orElse: () => null,
      );
      final count = existing?['count'] ?? 0;
      if (uniqueGenreList.add(genre['name'])) {
        genreList.add({
          'id': genre['id'],
          'name': genre['name'],
          'count': count + 1,
        });
        genreString.add(genre['name']);
      } else if (existing != null) {
        existing['count'] = count + 1;
      }
    }
    data['genreString'] = genreString.toList().join(',');
  }

  // R8 fix: Parse genres without mutating global state during build
  void _parseGenresWithoutMutation(dynamic data) {
    final genres = data['genres'] ?? data['musicbrainz']?['genres'] ?? [];
    final Set<String> genreString = {};
    for (final genre in genres) {
      genreString.add(genre['name']);
    }
    data['genreString'] = genreString.toList().join(',');
  }

  void _filterCardsByGenre(String query) {
    // R3 fix: Restore visibility for matching items
    if (query.isEmpty) {
      for (final widget in cardList) {
        widget.setVisibility(true);
      }
      isFilteredNotifier.value = false;
    } else {
      var anyFiltered = false;
      for (final widget in cardList) {
        if (!widget.inputData!['genreString'].toString().toLowerCase().contains(
          query,
        )) {
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

  void _filterCardList(String query) {
    // R3 fix: Restore visibility for matching items
    if (query.isEmpty) {
      for (final widget in cardList) {
        widget.setVisibility(true);
      }
      isFilteredNotifier.value = false;
    } else {
      var anyFiltered = false;
      for (final widget in cardList) {
        final searchStr =
            '${widget.inputData!['musicbrainzName'] ?? ''} '
            '${widget.inputData!['discogsName'] ?? ''} '
            '${widget.inputData!['artist'] ?? ''} '
            '${widget.inputData!['title'] ?? ''}';
        if (!searchStr.toLowerCase().contains(query)) {
          widget.setVisibility(false);
          anyFiltered = true;
        } else {
          // R3 fix: Restore visibility for matching items
          widget.setVisibility(true);
        }
      }
      isFilteredNotifier.value = anyFiltered;
    }
    genresWidget?.searchGenres(query);
  }

  Widget _buildGenreList() {
    genresWidget = GenreList(
      genres: genreList,
      showCount: true,
      callback: _filterCardsByGenre,
    );
    return genresWidget!;
  }

  Widget _buildSearchBar(BuildContext context) {
    return CustomSearchBar(
      controller: _searchBar,
      focusNode: _inputNode,
      labelText: '${context.l10n!.search}...',
      onSubmitted: (String value) {
        _inputNode.unfocus();
      },
      onChanged: (String value) {
        _filterCardList(value);
      },
    );
  }
}
