import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/screens/artist_page.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/custom_search_bar.dart';
import 'package:reverbio/widgets/genre_list.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

class LikedArtistsPage extends StatefulWidget {
  const LikedArtistsPage({super.key, required this.navigatorObserver});
  final RouteObserver<PageRoute> navigatorObserver;

  @override
  _LikedArtistsPageState createState() => _LikedArtistsPageState();
}

class _LikedArtistsPageState extends State<LikedArtistsPage> with RouteAware {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  late final double artistHeight =
      MediaQuery.sizeOf(context).height * 0.25 / 1.1;
  late final Set<String> uniqueGenreList = {};
  late final List<dynamic> genreList = [];
  final List<dynamic> artistDetails = [];
  late Future<dynamic> artistsFuture;
  final List<BaseCard> artistCards = <BaseCard>[];

  @override
  void initState() {
    super.initState();
    artistsFuture = _getArtistsDetails();
    artistsFuture.then((value) {
      for (final data in value as List) {
        data['filterShow'] = true;
        artistDetails.add(data);
        _parseGenres(data);
      }
      if (mounted) setState(() {});
    });
    currentLikedArtistsLength.addListener(_listener);
  }

  @override
  void dispose() {
    artistsFuture.ignore();
    currentLikedArtistsLength.removeListener(_listener);
    widget.navigatorObserver.unsubscribe(this);
    artistCards.clear();
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
      appBar: AppBar(title: Text(context.l10n!.artists)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSearchBar(context),
            _buildGenreList(),
            SectionHeader(title: context.l10n!.artists),
            _buildArtistsGrid(context),
          ],
        ),
      ),
    );
  }

  void _listener() {
    if (mounted)
      setState(() {
        artistsFuture = _getArtistsDetails();
      });
  }

  Widget _buildArtistsGrid(BuildContext context) {
    return FutureBuilder(
      future: artistsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          artistDetails.clear();
          return const Padding(padding: EdgeInsets.all(35), child: Spinner());
        }
        if (snapshot.connectionState == ConnectionState.done) {
          if (artistDetails.isEmpty)
            for (final data in snapshot.data as List) {
              data['filterShow'] = true;
              artistDetails.add(data);
              _parseGenres(data);
            }
          _buildArtistCards(context);
          return LayoutBuilder(
            builder: (context, constraints) {
              final innerWidth = constraints.maxWidth;
              final innerHeight = constraints.maxHeight;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: innerHeight,
                  maxWidth: innerWidth,
                ),
                child: Wrap(children: artistCards),
              );
            },
          );
        }
        return const Text(
          'You dont have any liked artists.',
          textAlign: TextAlign.center,
        );
      },
    );
  }

  void _buildArtistCards(BuildContext context) {
    artistCards.clear();
    for (final data in artistDetails) {
      _buildArtistCard(context, data);
    }
  }

  void _buildArtistCard(BuildContext context, dynamic data) {
    //TODO: restore sorting on refresh due to like status change
    //TODO: add custom sorting
    final card = BaseCard(
      inputData: data as Map<dynamic, dynamic>,
      icon: FluentIcons.mic_sparkle_24_filled,
      size: artistHeight,
      showLike: true,
      showOverflowLabel: true,
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ArtistPage(
                    artistData: data,
                    navigatorObserver: widget.navigatorObserver,
                  ),
              settings: RouteSettings(name: 'artist?${data['id']}'),
            ),
          ),
    );
    artistCards.add(card);
  }

  Future<dynamic> _getArtistsDetails() async {
    final futures = <Future>[];
    for (final artist in userLikedArtistsList) {
      futures.add(getArtistDetailsById(artist['id']));
    }
    return futures.wait;
  }

  void _parseGenres(dynamic data) {
    //TODO: Add search by genre
    //TODO: Search genres
    for (final genre in data['musicbrainz']['genres']) {
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

  void _filterArtistList(String query) {
    if (query.isEmpty) {
      for (final widget in artistCards) {
        widget.setVisibility(true);
      }
    } else {
      for (final widget in artistCards) {
        if (!widget.inputData!['musicbrainzName']
            .toString()
            .toLowerCase()
            .contains(query)) {
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
        _filterArtistList(value);
      },
    );
  }
}
