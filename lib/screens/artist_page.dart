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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/notifiable_future.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/utilities/url_launcher.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/artist_header.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/genre_list.dart';
import 'package:reverbio/widgets/horizontal_card_scroller.dart';
import 'package:reverbio/widgets/song_bar.dart';
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
  late ThemeData _theme;
  List albums = [];
  List others = [];
  List singles = [];
  final likeStatus = ValueNotifier(false);
  late final NotifiableFuture<dynamic> dataFuture = NotifiableFuture(
    copyMap(widget.artistData),
  );

  @override
  void initState() {
    super.initState();
    dataFuture.runFuture(_setupArtistData());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      likeStatus.value = isArtistAlreadyLiked(widget.artistData);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(FluentIcons.arrow_left_24_filled),
          onPressed: () => GoRouter.of(context).pop(context),
          iconSize: pageHeaderIconSize,
        ),
        actions: [
          _buildLikeButton(),
          if (widget.artistData['mbid'] != null)
            IconButton(
              iconSize: pageHeaderIconSize,
              onPressed: () {
                if (widget.artistData['mbid'] != null) {
                  final uri = Uri.parse(
                    'https://musicbrainz.org/artist/${widget.artistData['mbid']}',
                  );
                  launchURL(uri);
                }
              },
              icon: Icon(
                FluentIcons.database_link_24_filled,
                color: _theme.colorScheme.primary,
              ),
            ),
          _buildSyncButton(),
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
        style: TextStyle(color: _theme.colorScheme.primary, fontSize: 18),
      ),
    );
  }

  Widget _buildSyncButton() {
    return IconButton(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.arrow_sync_24_filled),
      iconSize: pageHeaderIconSize,
      onPressed: () async {
        final data = await getArtistDetails(widget.artistData, refresh: true);
        if (mounted)
          setState(() {
            widget.artistData.addAll(data);
          });
      },
    );
  }

  Widget _buildLikeButton() {
    return StatefulBuilder(
      builder: (context, setState) {
        return ListenableBuilder(
          listenable: userLikedArtistsList,
          builder: (context, child) {
            return FutureBuilder(
              future: Future.microtask(
                () => isArtistAlreadyLiked(widget.artistData),
              ),
              builder: (context, snapshot) {
                bool value =
                    likeStatus.value = isArtistAlreadyLiked(widget.artistData);
                if (!snapshot.hasError &&
                    snapshot.hasData &&
                    snapshot.data != null &&
                    snapshot.connectionState != ConnectionState.waiting)
                  value = snapshot.data!;
                return IconButton(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  icon:
                      value
                          ? const Icon(FluentIcons.heart_24_filled)
                          : const Icon(FluentIcons.heart_24_regular),
                  iconSize: pageHeaderIconSize,
                  onPressed: () {
                    updateArtistLikeStatus(
                      widget.artistData,
                      !likeStatus.value,
                    );
                    if (mounted) setState(() {});
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBody() {
    if (widget.artistData?['musicbrainz'] == null)
      return FutureBuilder(
        future: _setupArtistData(),
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
      widget.artistData?['artist'] ??
          widget.artistData?['name'] ??
          widget.artistData?['title'] ??
          widget.artistData?['value'] ??
          '',
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

  NotifiableFuture _getAlbums(dynamic artistData) {
    return NotifiableFuture.withFuture(
      albums,
      Future.microtask(() async {
        if (!dataFuture.isComplete) await dataFuture.completerFuture;
        albums =
            artistData?['musicbrainz']?['release-groups'] == null
                ? []
                : List.from(artistData?['musicbrainz']['release-groups'])
                    .where(
                      (value) =>
                          value['primary-type'].toString().toLowerCase() ==
                          'album',
                    )
                    .map((ele) {
                      ele['source'] = 'musicbrainz';
                      ele['artist'] = artistData?['artist'];
                      ele['artistId'] = artistData?['id'];
                      ele['isAlbum'] = true;
                      ele['ytid'] = null;
                      return ele;
                    })
                    .map((e) {
                      e = Map<String, dynamic>.from(e);
                      return e;
                    })
                    .toList();
        return getAlbumsCoverArt(albums);
      }),
    );
  }

  NotifiableFuture _getOthers(dynamic artistData) {
    return NotifiableFuture.withFuture(
      others,
      Future.microtask(() async {
        if (!dataFuture.isComplete) await dataFuture.completerFuture;
        others =
            artistData?['musicbrainz']?['release-groups'] == null
                ? []
                : List.from(artistData?['musicbrainz']?['release-groups'])
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
                      ele['artist'] = artistData?['artist'];
                      ele['artistId'] = artistData?['id'];
                      ele['isAlbum'] = false;
                      ele['ytid'] = null;
                      return ele;
                    })
                    .map((e) {
                      e = Map<String, dynamic>.from(e);
                      return e;
                    })
                    .toList();
        return getAlbumsCoverArt(others);
      }),
    );
  }

  NotifiableList<SongBar> _getSingles() {
    return NotifiableList.fromAsync(
      Future.microtask(() async {
        if (!dataFuture.isComplete) await dataFuture.completerFuture;
        singles =
            (widget.artistData?['musicbrainz']?['release-groups'] == null
                    ? []
                    : List.from(
                          widget.artistData?['musicbrainz']?['release-groups'],
                        )
                        .where(
                          (value) =>
                              value['primary-type'].toString().toLowerCase() ==
                              'single',
                        )
                        .map((ele) {
                          ele['source'] = 'musicbrainz';
                          ele['artist'] = widget.artistData?['artist'];
                          ele['artistId'] = widget.artistData?['id'];
                          ele['isAlbum'] = false;
                          ele['isSong'] = true;
                          ele['ytid'] = null;
                          ele['image'] =
                              pickRandomItem(
                                widget.artistData?['discogs']?['images'] ?? [],
                              )?['uri150'];
                          return ele;
                        }))
                .map((e) {
                  e = Map<String, dynamic>.from(e);
                  return e;
                })
                .toList();
        return singles.map((e) => initializeSongBar(e, context));
      }),
    );
  }

  Future<dynamic> _setupArtistData() async {
    final _initData = copyMap(widget.artistData);
    final artistData = <String, dynamic>{};
    if (widget.artistData?['musicbrainz'] == null) {
      artistData.addAll(
        await Future.microtask(() async {
          return copyMap(
            Map<String, dynamic>.from(await getArtistDetails(_initData)),
          );
        }),
      );
    }
    _initData.addAll(artistData);
    widget.artistData.clear();
    widget.artistData.addAll(_initData);
    return widget.artistData;
  }

  Widget _buildContentList() {
    final _singles = _getSingles();
    final _albums = _getAlbums(widget.artistData);
    final _others = _getOthers(widget.artistData);
    return dataFuture.build(
      loading:
          () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsetsGeometry.all(10),
              child: Spinner(),
            ),
          ),
      data:
          (data) => SliverMainAxisGroup(
            slivers: [
              //Albums
              ListenableBuilder(
                listenable: _albums,
                builder: (context, child) {
                  return SliverToBoxAdapter(
                    child:
                        albums.isEmpty
                            ? const SizedBox.shrink()
                            : HorizontalCardScroller(
                              future: _albums.completerFuture,
                              icon: FluentIcons.cd_16_filled,
                              title: context.l10n!.albums,
                            ),
                  );
                },
              ),
              //Others
              ListenableBuilder(
                listenable: _others,
                builder: (context, child) {
                  return SliverToBoxAdapter(
                    child:
                        others.isEmpty
                            ? const SizedBox.shrink()
                            : HorizontalCardScroller(
                              future: _others.completerFuture,
                              icon: FluentIcons.cd_16_filled,
                              title: context.l10n!.others,
                            ),
                  );
                },
              ),
              //Singles
              ListenableBuilder(
                listenable: _singles,
                builder: (context, child) {
                  return _singles.isEmpty
                      ? const SliverToBoxAdapter(child: SizedBox.shrink())
                      : SongList(
                        page: 'singles',
                        title: context.l10n!.singles,
                        songBars: _singles,
                      );
                },
              ),
            ],
          ),
    );
  }
}
