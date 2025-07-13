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
import 'dart:math';

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
    final cached =
        cachedAlbumsList.where((e) => e['id']?.contains(id) ?? false).toList();
    if (cached.isEmpty) return null;
    return cached.first;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

Future<dynamic> getAlbumDetailsById(dynamic albumData) async {
  try {
    final id = parseEntityId(albumData);
    final ids = Uri.parse('?${parseEntityId(id)}').queryParameters;
    final cached = _getCachedAlbum(id);
    if (cached != null) {
      await getAlbumCoverArt(cached);
      if (cached['list'] == null || cached['list'].isEmpty)
        await getTrackList(cached);
      else
        return cached;
    }
    if (ids['mb'] == null) return {};
    final album = await mb.releaseGroups.get(
      ids['mb']!,
      inc: ['artists', 'releases', 'annotation', 'tags', 'genres', 'ratings'],
    );
    album['artist'] = combineArtists(album) ?? album['artist'];
    album['album'] = album['title'];
    album['cachedAt'] = DateTime.now().toString();
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

Future<Map<String, dynamic>> findMBAlbum(
  String title, {
  String? artist,
  int? limit,
}) async {
  try {
    final query =
        artist == null
            ? '(\'$title\' AND type:\'album\')'
            : '(\'$title\' AND artist:\'$artist\' AND type:\'album\') OR (\'$artist\' AND artist:\'$title\' AND type:\'album\')';
    final albQry = await mb.releaseGroups.search(query, limit: limit ?? 25);
    final albums = ((albQry ?? {})['release-groups'] ?? []) as List;
    if (albums.isEmpty) return {};
    final id = (albums.first['artist-credit'] as List).first['artist']['id'];
    final artQry = await getArtistDetails(id);
    final artistInfo = Map.from(artQry ?? {});
    if (artistInfo.isNotEmpty) {
      albums.first['artist-details'] = artistInfo;
      albums.first['artist'] = artistInfo['artist'];
      albums.first['artistId'] = artistInfo['id'];
    }
    albums.first['album'] = albums.first['title'];
    albums.first['artist'] =
        combineArtists(albums.first) ?? albums.first['artist'];
    albums.first['cachedAt'] = DateTime.now().toString();
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
    final ids = Uri.parse('?${parseEntityId(album)}').queryParameters;
    if (ids['mb'] != null) {
      final result = await mb.coverArt.get(ids['mb']!, 'release-group');
      if (result['error'] == null) {
        album['images'] = result['images'];
        album['release'] = result['release'];
      }
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
        final coverArt = await mb.coverArt.get(release['id'], 'release');
        for (final track in release['list']) {
          if (!tracks.any((e) => checkSong(e, track))) {
            if (coverArt['error'] == null) {
              track['images'] = coverArt['images'];
            }
            final artist =
                combineArtists(track) ?? combineArtists(release) ?? '';
            tracks.add({
              'id': 'mb=${track['mbid']}',
              'mdid': track['mbid'],
              'reid': release['id'],
              'mbidType': 'track',
              'album': release['title'],
              'title': track['title'],
              'artist': artist,
              'primary-type': 'song',
              'image': track['image'],
              'cachedAt': DateTime.now().toString(),
              'duration': (track['length'] ?? 0) ~/ 1000,
            });
            release['duration'] = max(
              release['duration'] ?? 0,
              (track['length'] ?? 0) ~/ 1000,
            );
          }
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
      final coverArt = await mb.coverArt.get(release['id'], 'release');
      if (coverArt['error'] == null) {
        release['images'] = coverArt['images'];
      }
      release['media']?.forEach((media) {
        media['tracks']?.forEach((track) {
          if (tracklist.add(track['title'])) {
            final artist =
                combineArtists(track) ??
                combineArtists(media) ??
                combineArtists(release) ??
                combineArtists(album) ??
                '';
            album['list'].add({
              'index': i++,
              'id': 'mb=${track['id']}',
              'mbid': track['id'],
              'mbidType': 'track',
              'ytid': null,
              'title': track['title'],
              'album': album['title'],
              'source': null,
              'artist': artist,
              'artist-credit':
                  track['artist-credit'] ??
                  media['artist-credit'] ??
                  release['artist-credit'] ??
                  album['artist-credit'],
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
      album['id'] = parseEntityId(album);
      if (album['id']?.isEmpty) throw Exception('ID is null or empty');
      if (album['id'] != null &&
          (album['image'] == null || album['image'].isEmpty))
        unawaited(getAlbumCoverArt(album));
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
      userLikedAlbumsList.removeWhere((value) => checkAlbum(album, value));
      currentLikedAlbumsLength.value--;
    }
    addOrUpdateData('user', 'likedAlbums', userLikedAlbumsList);
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return !add;
  }
}

bool isAlbumAlreadyLiked(albumToCheck) =>
    albumToCheck is Map &&
    userLikedAlbumsList.any(
      (album) => album is Map && checkAlbum(album, albumToCheck),
    );

int? getAlbumHashCode(dynamic album) {
  if (!(album is Map)) return null;
  if ((album['title'] ?? album['song']) == null || album['artist'] == null)
    return null;
  return (album['title'] ?? album['album']).toLowerCase().hashCode ^
      album['artist'].toLowerCase().hashCode;
}

bool checkAlbum(dynamic album, dynamic otherAlbum) {
  if (album == null || otherAlbum == null) return false;
  if (album['id'] == null || otherAlbum['id'] == null)
    return getAlbumHashCode(album) == getAlbumHashCode(otherAlbum);
  parseEntityId(album);
  parseEntityId(otherAlbum);
  return checkEntityId(album['id'], otherAlbum['id']);
}
