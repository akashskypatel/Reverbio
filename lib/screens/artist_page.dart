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
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/widgets/artist_header.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/genre_list.dart';
import 'package:reverbio/widgets/horizontal_card_scroller.dart';
import 'package:reverbio/widgets/song_list.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({
    super.key,
    this.artistData,
    this.cardIcon = FluentIcons.mic_sparkle_24_regular,
    required this.navigatorObserver,
  });

  final dynamic artistData;
  final IconData cardIcon;
  final RouteObserver<PageRoute> navigatorObserver;

  @override
  _ArtistPageState createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> with RouteAware {
  late final double playlistHeight =
      MediaQuery.sizeOf(context).height * 0.25 / 1.1;
  late final isLargeScreen = MediaQuery.of(context).size.width > 480;
  late final screenWidth = MediaQuery.sizeOf(context).width;
  dynamic albums;
  dynamic others;
  dynamic singles;

  @override
  void initState() {
    super.initState();
    _setupData();
  }

  @override
  void dispose() {
    widget.navigatorObserver.unsubscribe(this);
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(context),
        ),
        actions: [],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: buildArtistHeader(),
            ),
          ),
          if (widget.artistData?['musicbrainz']?['genres'] != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GenreList(
                  genres: widget.artistData?['musicbrainz']?['genres'],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildContentList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildArtistHeader() {
    return ArtistHeader(_buildArtistImage(), widget.artistData['artist']);
  }

  Widget _buildArtistImage() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    return BaseCard(
      inputData: widget.artistData,
      size: isLandscape ? 300 : screenWidth / 2.5,
      icon: widget.cardIcon,
      showLike: true,
    );
  }

  void _setupData() {
    albums =
        widget.artistData['musicbrainz']['release-groups'] == null
            ? []
            : List.from(widget.artistData['musicbrainz']['release-groups'])
                .where(
                  (value) =>
                      value['primary-type'].toString().toLowerCase() == 'album',
                )
                .map((ele) {
                  ele['artist'] = widget.artistData['artist'];
                  ele['artist-details'] = widget.artistData;
                  ele['isAlbum'] = true;
                  ele['ytid'] = null;
                  return ele;
                })
                .toList();

    others =
        widget.artistData['musicbrainz']['release-groups'] == null
            ? []
            : List.from(widget.artistData['musicbrainz']['release-groups'])
                .where(
                  (value) =>
                      value['primary-type'].toString().toLowerCase() !=
                          'album' &&
                      value['primary-type'].toString().toLowerCase() !=
                          'single',
                )
                .map((ele) {
                  ele['primary-type'] = ele['primary-type'] ?? 'unknown';
                  ele['artist'] = widget.artistData['artist'];
                  ele['artist-details'] = widget.artistData;
                  ele['isAlbum'] = false;
                  ele['ytid'] = null;
                  return ele;
                })
                .toList();
    singles =
        widget.artistData['musicbrainz']['release-groups'] == null
            ? []
            : List.from(widget.artistData['musicbrainz']['release-groups'])
                .where(
                  (value) =>
                      value['primary-type'].toString().toLowerCase() ==
                      'single',
                )
                .map((ele) {
                  ele['artist'] = widget.artistData['artist'];
                  ele['artist-details'] = widget.artistData;
                  ele['isAlbum'] = false;
                  ele['isSong'] = true;
                  ele['ytid'] = null;
                  return ele;
                })
                .toList();
  }

  Widget _buildContentList() {
    return Column(
      children: [
        //Albums
        if (albums.isNotEmpty)
          HorizontalCardScroller(
            future: getAlbumCoverArt(albums),
            icon: FluentIcons.cd_16_filled,
            title: context.l10n!.albums,
            navigatorObserver: widget.navigatorObserver,
          ),
        //Others
        if (others.isNotEmpty)
          HorizontalCardScroller(
            future: getAlbumCoverArt(others),
            icon: FluentIcons.cd_16_filled,
            title: context.l10n!.others,
            navigatorObserver: widget.navigatorObserver,
          ),
        //Singles
        if (singles.isNotEmpty)
          SongList(
            title: context.l10n!.songs,
            future: getAlbumsTrackList(singles),
          ),
      ],
    );
  }
}
