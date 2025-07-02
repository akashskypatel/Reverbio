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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/artist_header.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/genre_list.dart';
import 'package:reverbio/widgets/horizontal_card_scroller.dart';
import 'package:reverbio/widgets/song_list.dart';
import 'package:reverbio/widgets/spinner.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({
    super.key,
    required this.page,
    this.artistData,
    this.cardIcon = FluentIcons.mic_sparkle_24_regular,
  });
  final String page;
  final dynamic artistData;
  final IconData cardIcon;

  @override
  _ArtistPageState createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(context),
          iconSize: pageHeaderIconSize,
        ),
        actions: [
          ...PM.getWidgetsByType(_getArtistData, 'ArtistPageHeader', context),
          if (kDebugMode) const SizedBox(width: 24, height: 24),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Text(
        '${context.l10n!.error}!',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.artistData['musicbrainz'] == null)
      return FutureBuilder(
        future: _setupData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(35), child: Spinner());
          } else if (snapshot.hasError) {
            return _buildErrorWidget(context);
          } else if (snapshot.connectionState == ConnectionState.done) {
            return CustomScrollView(
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
                _buildContentList(),
              ],
            );
          } else {
            return _buildErrorWidget(context);
          }
        },
      );
    else
      return CustomScrollView(
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
          _buildContentList(),
        ],
      );
  }

  dynamic _getArtistData() {
    final data = {...(widget.artistData as Map), 'title': null, 'album': null};
    return data;
  }

  Widget buildArtistHeader() {
    return ArtistHeader(
      _buildArtistImage(),
      widget.artistData['artist'] ?? widget.artistData['name'],
    );
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

  Future<dynamic> _setupData() async {
    if (widget.artistData['musicbrainz'] == null)
      widget.artistData.addAll(
        Map<String, dynamic>.from(
          await getArtistDetails(widget.artistData['id']),
        ),
      );

    albums =
        widget.artistData['musicbrainz']['release-groups'] == null
            ? []
            : List.from(widget.artistData['musicbrainz']['release-groups'])
                .where(
                  (value) =>
                      value['primary-type'].toString().toLowerCase() == 'album',
                )
                .map((ele) {
                  ele['source'] = 'musicbrainz';
                  ele['artist'] = widget.artistData['artist'];
                  ele['artistId'] = widget.artistData['id'];
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
                  ele['source'] = 'musicbrainz';
                  ele['primary-type'] = ele['primary-type'] ?? 'unknown';
                  ele['artist'] = widget.artistData['artist'];
                  ele['artistId'] = widget.artistData['id'];
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
                  ele['source'] = 'musicbrainz';
                  ele['artist'] = widget.artistData['artist'];
                  ele['artistId'] = widget.artistData['id'];
                  ele['isAlbum'] = false;
                  ele['isSong'] = true;
                  ele['ytid'] = null;
                  ele['image'] =
                      pickRandomItem(
                        widget.artistData['discogs']['images'] as List,
                      )['uri150'];
                  return ele;
                })
                .toList();

    return widget.artistData;
  }

  Widget _buildContentList() {
    return SliverMainAxisGroup(
      slivers: [
        //Albums
        if (albums.isNotEmpty)
          SliverToBoxAdapter(
            child: HorizontalCardScroller(
              future: getAlbumsCoverArt(albums),
              icon: FluentIcons.cd_16_filled,
              title: context.l10n!.albums,
            ),
          ),
        //Others
        if (others.isNotEmpty)
          SliverToBoxAdapter(
            child: HorizontalCardScroller(
              future: getAlbumsCoverArt(others),
              icon: FluentIcons.cd_16_filled,
              title: context.l10n!.others,
            ),
          ),
        //Singles
        if (singles.isNotEmpty)
          SongList(
            page: 'singles',
            title: context.l10n!.singles,
            future: getSinglesTrackList(singles),
          ),
      ],
    );
  }
}
