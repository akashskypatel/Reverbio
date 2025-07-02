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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/settings_manager.dart';

List userLikedAlbumsList = Hive.box(
  'user',
).get('likedAlbums', defaultValue: []);

List cachedAlbumsList = Hive.box('cache').get('cachedAlbums', defaultValue: []);

final ValueNotifier<int> currentLikedAlbumsLength = ValueNotifier<int>(
  userLikedAlbumsList.length,
);

dynamic _getCachedAlbum(String id) {
  try {
    final cached = cachedAlbumsList.where((e) => e['id'].contains(id)).toList();
    if (cached.isEmpty) return null;
    return cached.first;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

Future<dynamic> getAlbumDetailsById(String id) async {
  try {
    final cached = _getCachedAlbum(id);
    if (cached != null)
      if (cached['list'] == null || cached['list'].isEmpty)
        await getTrackList(cached);
      else
        return cached;
    final album = await mb.releaseGroups.get(
      id,
      inc: ['artists', 'releases', 'annotation', 'tags', 'genres', 'ratings'],
    );
    album['artist'] = album['artist'] ?? album['artist-credit'].first['name'];
    album['album'] = album['title'];
    await getAlbumCoverArt(album);
    await getTrackList(album);
    cachedAlbumsList.addOrUpdate('id', album['id'], album);
    addOrUpdateData('cache', 'cachedAlbums', cachedAlbumsList);
    return album;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return {};
  }
}

Future<Map<String, dynamic>> findMBAlbum(String title, String artist) async {
  try {
    final albums =
        (await mb.releaseGroups.search(
              '("$title" AND artist:"$artist" AND type:"album") OR ("$artist" AND artist:"$title" AND type:"album")',
            ))['release-groups']
            as List;
    if (albums.isEmpty) return {};
    final id = (albums.first['artist-credit'] as List).first['artist']['id'];
    final artistInfo = Map.from(await getArtistDetails(id));
    if (artistInfo.isNotEmpty) {
      albums.first['artist-details'] = artistInfo;
      albums.first['artist'] = artistInfo['artist'];
      albums.first['artistId'] = artistInfo['id'];
    }
    albums.first['album'] = albums.first['title'];
    await getAlbumCoverArt(albums.first);
    cachedAlbumsList.addOrUpdate('id', albums.first['id'], albums.first);
    addOrUpdateData('cache', 'cachedAlbums', cachedAlbumsList);
    return albums.first;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<dynamic> getAlbumCoverArt(dynamic album) async {
  if (album.isEmpty) return album;
  try {
    final result = await mb.coverArt.get(album['id'], 'release-group');
    if (result['error'] == null) {
      album['images'] = result['images'];
      album['release'] = result['release'];
    }
    return album;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return album;
  }
}

Future<dynamic> getAlbumsCoverArt(List<dynamic> albums) async {
  if (albums.isEmpty) return albums;
  try {
    return albums.map((value) async {
      final cached = _getCachedAlbum(value['id']);
      if (cached == null || cached['images'] == null) {
        return getAlbumCoverArt(value);
      } else
        return cached;
    }).wait;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return albums;
  }
}

Future<dynamic> getSinglesTrackList(List<dynamic> singlesReleases) async {
  try {
    final tracks = [];
    for (final release in singlesReleases) {
      final cached = _getCachedAlbum(release['id']) ?? {};
      release['list'] =
          release['list'] is List
              ? release['list']
              : (cached['list'] is List
                  ? cached['list']
                  : await getTrackList(release));
      if (release['list'] != null && release['list'].isNotEmpty) {
        for (final track in release['list']) {
          if (!tracks.any((e) => checkSong(e, track)))
            tracks.add({
              'id': 'mb=${track['mbid']}',
              'mdid': track['mbid'],
              'album': release['title'],
              'title': track['title'],
              'artist': release['artist'],
              'primary-type': 'song',
              'image': track['image'],
              'duration': track['duration'],
            });
        }
      }
    }
    return tracks.toList();
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return [];
  }
}

Future<List?> getTrackList(dynamic album) async {
  try {
    final countryCode =
        userGeolocation['countryCode'] ??
        (await getIPGeolocation())['countryCode'];
    final albumId = album['id'];
    final cached = _getCachedAlbum(albumId);

    if (cached != null &&
        cached['list'] != null &&
        (cached['list'] as List).isNotEmpty) {
      album['list'] = cached['list'];
      return album['list'];
    }

    final result = await mb.releases.browse(
      'release-group',
      albumId,
      inc: ['recordings', 'artist-credits'],
      paginated: false,
    );

    if (result['error'] != null) return null;

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
      release['media']?.forEach((media) {
        media['tracks']?.forEach((track) {
          if (tracklist.add(track['title'])) {
            final artist = (track['artist-credit'] as List)
                .map((value) {
                  return value['name'];
                })
                .join(', ');
            album['list'].add({
              'index': i++,
              'mbid': track['id'],
              'mbidType': 'track',
              'ytid': null,
              'title': track['title'],
              'album': album['title'],
              'source': null,
              'artist': artist,
              'artist-credit': track['artist-credit'],
              'image':
                  (album['image'] ?? '').toLowerCase() == 'null'
                      ? null
                      : album['image'],
              'lowResImage':
                  (album['image'] ?? '').toLowerCase() == 'null'
                      ? null
                      : album['image'],
              'highResImage':
                  (album['image'] ?? '').toLowerCase() == 'null'
                      ? null
                      : album['image'],
              'duration': (track['length'] ?? 0) ~/ 1000,
              'isLive': false,
              'primary-type': 'song',
            });
          }
        });
      });
    }
    cachedAlbumsList.addOrUpdate('id', albumId, album);
    addOrUpdateData('cache', 'cachedAlbums', cachedAlbumsList);
    return album['list'];
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

/// Returns current liked status if successful.
Future<bool> updateAlbumLikeStatus(dynamic album, bool add) async {
  try {
    if (add) {
      userLikedAlbumsList.addOrUpdate('id', album['id'], {
        'id': album['id'],
        'artist': album['artist'],
        'title': album['title'],
        'image': album['image'],
        'genres': album['genres'] ?? album['musicbrainz']?['genres'] ?? [],
        'primary-type': 'album',
      });
      currentLikedAlbumsLength.value++;
      album['album'] = album['title'];
      PM.onEntityLiked(album);
    } else {
      userLikedAlbumsList.removeWhere((value) => value['id'] == album['id']);
      currentLikedAlbumsLength.value--;
    }
    addOrUpdateData('user', 'likedAlbums', userLikedAlbumsList);
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

bool isAlbumAlreadyLiked(albumIdToCheck) =>
    userLikedAlbumsList.any((album) => album['id'] == albumIdToCheck);
