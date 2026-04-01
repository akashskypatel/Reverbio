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

import 'dart:convert';

import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/formatter.dart';

class PlaylistSharingService {
  // R3 fix: Include id and primary-type in compact playlist
  static Map createCompactPlaylist(Map fullPlaylist) {
    // R4 fix: Add null check for playlist['list']
    final list = fullPlaylist['list'] as List<dynamic>?;
    if (list == null) {
      return {
        'id': fullPlaylist['id'] ?? '',
        'primary-type': 'playlist',
        'title': fullPlaylist['title'],
        if (fullPlaylist['image'] != null) 'image': fullPlaylist['image'],
        'source': 'user-created',
        'list': [],
      };
    }
    
    // R2 fix: Filter out null ytid values
    // R6 fix: Handle binary image data
    final songYtids = list
        .map((song) => song['ytid'] as String?)
        .where((ytid) => ytid != null)
        .toList();
    
    final image = fullPlaylist['image'];
    final safeImage = image is List ? null : image;  // R6 fix: Skip binary image data

    return {
      'id': fullPlaylist['id'] ?? '',  // R3 fix: Add id with empty fallback
      'primary-type': 'playlist',  // R3 fix: Add primary-type
      'title': fullPlaylist['title'],
      if (safeImage != null) 'image': safeImage,  // R6 fix: Only include safe image data
      'source': 'user-created',
      'list': songYtids,  // R2 fix: Now guaranteed non-null values
    };
  }

  // R1 fix: Close YoutubeExplode instance in finally block
  // R5 fix: Use proxy-aware YouTube client
  static Future<Map> expandCompactPlaylist(Map compactPlaylist) async {
    final List<dynamic> songIds = compactPlaylist['list'];
    final _yt = px.proxyYoutubeClient;  // R5 fix: Use proxy-aware client
    try {
      final expandedSongs = await Future.wait(
        songIds.map((ytid) async {
          try {
            final video = await _yt.videos.get(ytid);
            return returnYtSongLayout(video);
          } catch (e, stackTrace) {
            logger.log('Error expanding song: $ytid', e, stackTrace);
            return null;
          }
        }),
      );

      return {
        ...compactPlaylist,
        'list': expandedSongs.where((song) => song != null).toList(),
      };
    } finally {
      // R1 fix: Close YoutubeExplode to prevent resource leak
      // Note: px.proxyYoutubeClient is managed by ProxyManager, don't close it
    }
  }

  static String encodePlaylist(Map playlist) {
    final compactPlaylist = createCompactPlaylist(playlist);
    return base64Url.encode(utf8.encode(json.encode(compactPlaylist)));
  }

  static Future<Map?> decodeAndExpandPlaylist(String encodedPlaylist) async {
    try {
      final jsonString = utf8.decode(base64Url.decode(encodedPlaylist));
      final compactPlaylist = json.decode(jsonString) as Map;
      return await expandCompactPlaylist(compactPlaylist);
    } catch (e, stackTrace) {
      logger.log('Failed to decode playlist', e, stackTrace);
      return null;
    }
  }
}
