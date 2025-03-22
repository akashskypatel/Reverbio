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

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';

List userLikedAlbumsList = Hive.box(
  'user',
).get('likedAlbums', defaultValue: []);

late final ValueNotifier<int> currentLikedAlbumsLength;

Future<dynamic> getAlbumCoverArt(List<dynamic> albums) async {
  if (albums.isEmpty) return null;
  try {
    return albums.map((value) async {
      final result = await mb.coverArt.get(value['id'], 'release-group');
      if (value['error'] == null) {
        value['images'] = result['images'];
        value['release'] = result['release'];
      }
      return value;
    }).wait;
  } catch (e, stackTrace) {
    logger.log('error in getAlbumCoverArt', e, stackTrace);
    return null;
  }
}

Future<dynamic> getReleaseGroupDetails(String id) async {
  if (id == '') return null;
  return mb.releaseGroups.get(
    id,
    inc: [
      'artists',
      'releases',
      'artist-credits',
      'annotation',
      'tags',
      'genres',
      'ratings',
      'artist-rels',
      'release-rels',
    ],
  );
}

Future<dynamic> getAlbumsTrackList(List<dynamic> albums) async {
  try {
    final tracklist = LinkedHashSet<String>();
    final tracks = [];
    for (final album in albums) {
      if (await getTrackList(album)) {
        for (final track in album['list']) {
          if (tracklist.add(track['title'].toString().toLowerCase().trim()))
            tracks.add({
              'title': track['title'],
              'artist': album['artist'],
              'primary-type': 'song',
            });
        }
      }
    }
    return tracks.toList();
  } catch (e, stackTrace) {
    logger.log('error in getAlbumsTrackList', e, stackTrace);
    return [];
  }
}

Future<bool> getTrackList(dynamic album) async {
  try {
    final countryCode =
        userGeolocation['countryCode'] ??
        (await getIPGeolocation())['countryCode'];
    final albumId = album['id'];

    final result = await mb.releases.browse(
      'release-group',
      albumId,
      inc: ['recordings'],
      paginated: false,
    );

    if (result['error'] != null) return false;

    final sortedReleases =
        (result['releases'] as List)..sort(
          (a, b) =>
              (DateTime.tryParse(a['date'] ?? DateTime.now().toString()) ??
                      DateTime.now())
                  .compareTo(
                    DateTime.tryParse(b['date'] ?? DateTime.now().toString()) ??
                        DateTime.now(),
                  ),
        );

    final lowerCountryCode = countryCode?.toString().toLowerCase();
    final effectiveReleases = () {
      if (lowerCountryCode != null) {
        final byCountry =
            sortedReleases
                .where(
                  (release) =>
                      release['country']?.toString().toLowerCase() ==
                      lowerCountryCode,
                )
                .toList();
        if (byCountry.isNotEmpty) return byCountry;
      }

      final byXW =
          sortedReleases
              .where(
                (release) =>
                    release['country']?.toString().toLowerCase() == 'xw',
              )
              .toList();
      if (byXW.isNotEmpty) return byXW;

      final byOfficial =
          sortedReleases
              .where(
                (release) =>
                    release['status']?.toString().toLowerCase() == 'official',
              )
              .toList();
      if (byOfficial.isNotEmpty) return [byOfficial.first];

      return [sortedReleases.first];
    }();

    final tracklist = LinkedHashSet<String>();
    album['list'] = [];

    var i = 0;
    for (final release in effectiveReleases) {
      release['media'].forEach((media) {
        media['tracks'].forEach((track) {
          if (tracklist.add(track['title'])) {
            album['list'].add({
              'id': i++,
              'ytid': null,
              'title': track['title'],
              'source': null,
              'artist': album['artist'],
              'image': album['image'],
              'lowResImage': album['image'],
              'highResImage': album['image'],
              'duration': track['length'],
              'isLive': false,
              'primary-type': 'song',
            });
          }
        });
      });
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('error in getTrackList', e, stackTrace);
    return false;
  }
}

/// Returns current liked status if successful.
Future<bool> updateAlbumLikeStatus(dynamic album, bool add) async {
  try {
    if (add) {
      userLikedAlbumsList.addOrUpdate('id', album['id'], {
        'id': album['id'],
        'title': album['title'],
      });
      currentLikedAlbumsLength.value++;
    } else {
      userLikedAlbumsList.removeWhere((value) => value['id'] == album['id']);
      currentLikedAlbumsLength.value--;
    }
    addOrUpdateData('user', 'likedAlbums', userLikedAlbumsList);
    return add;
  } catch (e, stackTrace) {
    logger.log('error in updateAlbumLikeStatus:', e, stackTrace);
    rethrow;
  }
}

bool isAlbumAlreadyLiked(albumIdToCheck) =>
    userLikedAlbumsList.any((album) => album['id'] == albumIdToCheck);
