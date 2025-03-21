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
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Future<dynamic> _recommendedPlaylistsFuture = getPlaylists(
    playlistsNum: recommendedCardsNumber,
  );
  final Future<dynamic> _recommendedSongsFuture = getRecommendedSongs();
  dynamic _recommendedSongs;

  @override
  void initState() {
    super.initState();
    _recommendedSongsFuture.then(
      (songs) => setState(() {
        _recommendedSongs = songs;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reverbio')),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: announcementURL,
              builder: (_, _url, __) {
                if (_url == null) return const SizedBox.shrink();

                return AnnouncementBox(
                  message: context.l10n!.newAnnouncement,
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  textColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  url: _url,
                );
              },
            ),
            Column(
              children: [
                HorizontalCardScroller(
                  title: context.l10n!.suggestedPlaylists,
                  future: _recommendedPlaylistsFuture,
                ),
                if (_recommendedSongs != null)
                  FutureBuilder(
                    future: _recommendedSongsFuture,
                    builder: (context, snapshot) {
                      return HorizontalCardScroller(
                        title: context.l10n!.suggestedArtists,
                        future: _parseArtistList(_recommendedSongs),
                      );
                    },
                  ),
                SongList(
                  title: context.l10n!.recommendedForYou,
                  future: _recommendedSongsFuture,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<dynamic> _parseArtistList(List<dynamic> data) async {
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
    return getArtistsDetails(artists);
  }
}
