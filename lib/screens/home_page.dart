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

import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/widgets/announcement_box.dart';
import 'package:reverbio/widgets/horizontal_card_scroller.dart';
import 'package:reverbio/widgets/song_list.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key, required this.navigatorObserver});
  final RouteObserver<PageRoute> navigatorObserver;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final Future<dynamic> _recommendedPlaylistsFuture = getPlaylists(
    playlistsNum: recommendedCardsNumber,
  );
  final Future<dynamic> _recommendedSongsFuture = getRecommendedSongs();
  dynamic _recommendedSongs;
  Future<dynamic>? _recommendedArtistsFuture;
  @override
  void initState() {
    super.initState();
    _recommendedSongsFuture.then((songs) {
      if (mounted) {
        setState(() {
          _recommendedSongs = songs;
        });
        _parseArtistList(_recommendedSongs);
      }
    });
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
      appBar: AppBar(title: const Text('Reverbio')),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: commonBarPadding,
              child: ValueListenableBuilder<String?>(
                valueListenable: announcementURL,
                builder: (_, _url, __) {
                  if (_url == null) return const SizedBox.shrink();

                  return AnnouncementBox(
                    message: context.l10n!.newAnnouncement,
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    textColor:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                    url: _url,
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: commonBarPadding,
              child: ValueListenableBuilder<int>(
                valueListenable: currentLikedPlaylistsLength,
                builder: (_, value, __) {
                  return HorizontalCardScroller(
                    title: context.l10n!.suggestedPlaylists,
                    future: _recommendedPlaylistsFuture,
                    navigatorObserver: widget.navigatorObserver,
                  );
                },
              ),
            ),
          ),
          if (_recommendedSongs != null && _recommendedArtistsFuture != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: commonBarPadding,
                child: FutureBuilder(
                  future: _recommendedSongsFuture,
                  builder: (context, snapshot) {
                    //return SizedBox.shrink();
                    return HorizontalCardScroller(
                      title: context.l10n!.suggestedArtists,
                      future: _recommendedArtistsFuture,
                      navigatorObserver: widget.navigatorObserver,
                    );
                  },
                ),
              ),
            ),
          SongList(
            page: 'recommended',
            title: context.l10n!.recommendedForYou,
            future: _recommendedSongsFuture,
          ),
        ],
      ),
    );
  }

  void _parseArtistList(List<dynamic> data) {
    final artists =
        data
            .where((e) => e['artist'] != null)
            .map(
              (e) =>
                  e['artist']
                      .toString()
                      .split('~')[0]
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .trim()
                      .toLowerCase(),
            )
            .toSet()
            .toList();
    _recommendedArtistsFuture = getRecommendedArtists(artists, 8);
  }
}
