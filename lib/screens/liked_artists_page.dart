import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/screens/artist_page.dart';
import 'package:reverbio/screens/playlist_page.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
import 'package:reverbio/widgets/genre_list.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

class LikedCardsPage extends StatefulWidget {
  const LikedCardsPage({
    super.key,
    required this.navigatorObserver,
    required this.title,
    required this.page,
  });
  final RouteObserver<PageRoute> navigatorObserver;
  final String page;
  final String title;

  @override
  _LikedCardsPageState createState() => _LikedCardsPageState();
}

class _LikedCardsPageState extends State<LikedCardsPage> with RouteAware {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  late final double cardHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
  late final Set<String> uniqueGenreList = {};
  late final List<dynamic> genreList = [];
  final List<dynamic> inputData = [];
  late Future<dynamic> dataFuture;
  final List<BaseCard> cardList = <BaseCard>[];

  @override
  void initState() {
    super.initState();
    _setDataFutures();
    dataFuture.then((value) {
      for (final data in value as List) {
        data['filterShow'] = true;
        inputData.add(data);
        _parseGenres(data);
      }
      if (mounted) setState(() {});
    });
    currentLikedArtistsLength.addListener(_listener);
    currentLikedAlbumsLength.addListener(_listener);
  }

  @override
  void dispose() {
    dataFuture.ignore();
    currentLikedArtistsLength.removeListener(_listener);
    currentLikedAlbumsLength.removeListener(_listener);
    widget.navigatorObserver.unsubscribe(this);
    cardList.clear();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the RouteObserver
    final route = ModalRoute.of(context);
    if (route != null) {
      widget.navigatorObserver.subscribe(this, route as PageRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
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
            _buildCardsGrid(context),
          ],
        ),
      ),
    );
  }

  void _listener() {
    if (mounted) setState(_setDataFutures);
  }

  void _setDataFutures() {
    switch (widget.page) {
      case 'artists':
        dataFuture = _getArtistsDetails();
      case 'albums':
        dataFuture = _getAlbumsDetails();
      default:
        break;
    }
  }

  Widget _buildCardsGrid(BuildContext context) {
    return FutureBuilder(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          inputData.clear();
          return const Padding(padding: EdgeInsets.all(35), child: Spinner());
        }
        if (snapshot.connectionState == ConnectionState.done) {
          if (inputData.isEmpty)
            for (final data in snapshot.data as List) {
              data['filterShow'] = true;
              inputData.add(data);
              _parseGenres(data);
            }
          _buildCards(context);
          return LayoutBuilder(
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
          );
        }
        return Text(
          widget.page == 'artists'
              ? context.l10n!.noLikedartists
              : context.l10n!.noLikedAlbums,
          textAlign: TextAlign.center,
        );
      },
    );
  }

  void _buildCards(BuildContext context) {
    cardList.clear();
    for (final data in inputData) {
      _buildCard(context, data);
    }
  }

  void _buildCard(BuildContext context, dynamic data) {
    //TODO: restore sorting on refresh due to like status change
    //TODO: add custom sorting
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
                          ? ArtistPage(
                            artistData: data,
                            navigatorObserver: widget.navigatorObserver,
                          )
                          : PlaylistPage(
                            playlistData: data,
                            navigatorObserver: widget.navigatorObserver,
                          ),
              settings: RouteSettings(name: 'artist?${data['id']}'),
            ),
          ),
    );
    cardList.add(card);
  }

  Future<dynamic> _getArtistsDetails() async {
    final futures = <Future>[];
    for (final artist in userLikedArtistsList) {
      futures.add(getArtistDetailsById(artist['id']));
    }
    return futures.wait;
  }

  Future<dynamic> _getAlbumsDetails() async {
    final futures = <Future>[];
    for (final album in userLikedAlbumsList) {
      futures.add(getAlbumDetailsById(album['id']));
    }
    return futures.wait;
  }

  void _parseGenres(dynamic data) {
    //TODO: Add search by genre
    //TODO: Search genres
    final genres = data['genres'] ?? data['musicbrainz']['genres'] ?? [];
    for (final genre in genres) {
      final count = genreList.where((e) => e['name'] == genre['name']).length;
      if (uniqueGenreList.add(genre['name'])) {
        genreList.add({
          'id': genre['id'],
          'name': genre['name'],
          'count': count + 1,
        });
      } else {
        final existing = genreList.firstWhere(
          (e) => e['name'] == genre['name'],
        );
        existing['count'] = count + 1;
      }
    }
  }

  void _filterCardList(String query) {
    if (query.isEmpty) {
      for (final widget in cardList) {
        widget.setVisibility(true);
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
        }
      }
    }
  }

  Widget _buildGenreList() {
    //TODO: add custom sorting
    genreList.sort(
      (a, b) => a['name'].toString().compareTo(b['name'].toString()),
    );
    return GenreList(genres: genreList, showCount: true);
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
