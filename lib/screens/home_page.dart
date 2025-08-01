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
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/announcement_box.dart';
import 'package:reverbio/widgets/horizontal_card_scroller.dart';
import 'package:reverbio/widgets/song_list.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ThemeData _theme;
  Future<dynamic> _recommendedPlaylistsFuture = getPlaylists(
    playlistsNum: recommendedCardsNumber,
  );
  Future<dynamic> _recommendedSongsFuture = getRecommendedSongs();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reverbio'),
        actions: [
          _buildSyncButton(),
          if (kDebugMode) const SizedBox(width: 24, height: 24),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: commonBarPadding,
              child: ValueListenableBuilder<String?>(
                valueListenable: announcementURL,
                builder: (context, _url, __) {
                  if (_url == null) return const SizedBox.shrink();
                  return AnnouncementBox(
                    message: context.l10n!.newAnnouncement,
                    backgroundColor: _theme.colorScheme.secondaryContainer,
                    textColor: _theme.colorScheme.onSecondaryContainer,
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
                builder: (context, value, __) {
                  //TODO: add pagination suggestedPlaylists
                  return HorizontalCardScroller(
                    title: context.l10n!.suggestedPlaylists,
                    future: _recommendedPlaylistsFuture,
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
                    //TODO: add pagination suggestedArtists
                    return HorizontalCardScroller(
                      title: context.l10n!.suggestedArtists,
                      future: _recommendedArtistsFuture,
                      icon: FluentIcons.mic_sparkle_24_filled,
                    );
                  },
                ),
              ),
            ),
          //TODO: add pagination recommendedForYou
          SongList(
            page: 'recommended',
            title: context.l10n!.recommendedForYou,
            future: _recommendedSongsFuture,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton() {
    return IconButton(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.arrow_sync_24_filled),
      iconSize: pageHeaderIconSize,
      onPressed: () {
        setState(() {
          _recommendedPlaylistsFuture = getPlaylists(
            playlistsNum: recommendedCardsNumber,
          );
          _recommendedSongsFuture =
              getRecommendedSongs()..then((songs) {
                if (mounted) {
                  setState(() {
                    _recommendedSongs = songs;
                  });
                  _parseArtistList(_recommendedSongs);
                }
              });
        });
      },
    );
  }

  void _parseArtistList(List<dynamic> data) {
    final artists =
        data
            .fold(<String>[], (v, e) {
              if (e['artist'] != null && e['artist'].isNotEmpty) {
                v.addAll(
                  splitArtists(
                    e['artist']
                        .split('~')[0]
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim()
                        .toLowerCase(),
                  ),
                );
              }
              if (e['channelName'] != null && e['channelName'].isNotEmpty) {
                v.addAll(
                  splitArtists(
                    e['channelName']
                        .split('~')[0]
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim()
                        .toLowerCase(),
                  ),
                );
              }
              return v;
            })
            .toSet()
            .toList();
    _recommendedArtistsFuture = getRecommendedArtists(artists, 8);
  }
}
