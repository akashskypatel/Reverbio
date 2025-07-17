import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/screens/artist_page.dart';
import 'package:reverbio/screens/playlist_page.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
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
  late final double cardHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
  late final Set<String> uniqueGenreList = {};
  late final List<dynamic> genreList = [];
  late ThemeData _theme;
  final List<dynamic> inputData = [];
  final List<BaseCard> cardList = <BaseCard>[];
  GenreList? genresWidget;
  ValueNotifier<bool> isFilteredNotifier = ValueNotifier(false);
  final dataMap = {
    'albums': {
      'list': userLikedAlbumsList,
      'notifier': currentLikedAlbumsLength,
      'widgetContext': 'AlbumsPageHeader',
    },
    'artists': {
      'list': userLikedArtistsList,
      'notifier': currentLikedArtistsLength,
      'widgetContext': 'ArtistsPageHeader',
    },
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    cardList.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          _clearFiltersButton(),
          ...PM.getWidgetsByType(
            _getEntityListData,
            dataMap[widget.page]?['widgetContext'] as String,
            context,
          ),
          if (kDebugMode) const SizedBox(width: 24, height: 24),
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
    return ValueListenableBuilder(
      valueListenable: dataMap[widget.page]?['notifier'] as ValueNotifier<int>,
      builder: (context, value, child) {
        inputData.clear();
        for (final data in (dataMap[widget.page]?['list'] as List)) {
          data['filterShow'] = true;
          inputData.add(data);
          _parseGenres(data);
        }
        _buildCards(context);
        return SingleChildScrollView(
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
                          : PlaylistPage(page: '/album', playlistData: data),
              settings: RouteSettings(name: '/artist?${data['id']}'),
            ),
          ),
    );
    cardList.add(card);
  }

  void _parseGenres(dynamic data) {
    final genres = data['genres'] ?? data['musicbrainz']?['genres'] ?? [];
    final Set<String> genreString = {};
    for (final genre in genres) {
      final count = genreList.where((e) => e['name'] == genre['name']).length;
      if (uniqueGenreList.add(genre['name'])) {
        genreList.add({
          'id': genre['id'],
          'name': genre['name'],
          'count': count + 1,
        });
        genreString.add(genre['name']);
      } else {
        final existing = genreList.firstWhere(
          (e) => e['name'] == genre['name'],
        );
        existing['count'] = count + 1;
      }
    }
    data['genreString'] = genreString.toList().join(',');
  }

  void _filterCardsByGenre(String query) {
    if (query.isEmpty) {
      for (final widget in cardList) {
        widget.setVisibility(true);
        isFilteredNotifier.value = false;
      }
    } else {
      for (final widget in cardList) {
        if (!widget.inputData!['genreString'].toString().toLowerCase().contains(
          query,
        )) {
          widget.setVisibility(false);
          isFilteredNotifier.value = true;
        }
      }
    }
  }

  void _filterCardList(String query) {
    if (query.isEmpty) {
      for (final widget in cardList) {
        widget.setVisibility(true);
        isFilteredNotifier.value = false;
      }
    } else {
      for (final widget in cardList) {
        final searchStr =
            '${widget.inputData!['musicbrainzName'] ?? ''} '
            '${widget.inputData!['discogsName'] ?? ''} '
            '${widget.inputData!['artist'] ?? ''} '
            '${widget.inputData!['title'] ?? ''}';
        if (!searchStr.toLowerCase().contains(query)) {
          widget.setVisibility(false);
          isFilteredNotifier.value = true;
        }
      }
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
      //loadingProgressNotifier: _fetchingSongs,
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
