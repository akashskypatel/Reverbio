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
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';

List userLikedAlbumsList = Hive.box(
  'user',
).get('likedAlbums', defaultValue: []);

List cachedAlbumsList = Hive.box('cache').get('cachedAlbums', defaultValue: []);

late final ValueNotifier<int> currentLikedAlbumsLength;

dynamic _getCachedAlbum(String id) {
  try {
    final cached = cachedAlbumsList.where((e) => e['id'] == id);
    if (cached.isEmpty) return null;
    return cached.first;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

Future<dynamic> getAlbumCoverArt(List<dynamic> albums) async {
  if (albums.isEmpty) return null;
  try {
    return albums.map((value) async {
      final cached = _getCachedAlbum(value['id']);
      if (cached == null || cached['images'] == null) {
        final result = await mb.coverArt.get(value['id'], 'release-group');
        if (value['error'] == null) {
          value['images'] = result['images'];
          value['release'] = result['release'];
        }
        cachedAlbumsList.addOrUpdate('id', value['id'], value);
        addOrUpdateData('cache', 'cachedAlbums', cachedAlbumsList);
        return value;
      } else
        return cached;
    }).wait;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
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

Future<dynamic> getSinglesTrackList(List<dynamic> singlesReleases) async {
  try {
    final tracklist = LinkedHashSet<String>();
    final tracks = [];
    for (final release in singlesReleases) {
      final cached = _getCachedAlbum(release['id']);
      if (cached != null && cached['list'] != null) {
        tracks.addAll(cached['list']);
      } else {
        final fetched = await getTrackList(release);
        if (fetched) {
          for (final track in release['list']) {
            if (tracklist.add(track['title'].toString().toLowerCase().trim()))
              tracks.add({
                'id': 'mb=${track['mbid']}',
                'mdid': track['mbid'],
                'album': release['title'],
                'title': track['title'],
                'artist': release['artist'],
                'primary-type': 'song',
              });
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

Future<bool> getTrackList(dynamic album) async {
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
      return true;
    }

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
              'index': i++,
              'mbid': track['id'],
              'ytid': null,
              'title': track['title'],
              'source': null,
              'artist': album['artist'],
              'image': (album['image'] ?? '').toLowerCase() == 'null' ? null : album['image'],
              'lowResImage': (album['image'] ?? '').toLowerCase() == 'null' ? null : album['image'],
              'highResImage': (album['image'] ?? '').toLowerCase() == 'null' ? null : album['image'],
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
    return true;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
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
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

bool isAlbumAlreadyLiked(albumIdToCheck) =>
    userLikedAlbumsList.any((album) => album['id'] == albumIdToCheck);
