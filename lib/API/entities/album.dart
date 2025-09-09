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
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/utils.dart';

final List userLikedAlbumsList =
    (Hive.box('user').get('likedAlbums', defaultValue: []) as List).map((e) {
      e = Map<String, dynamic>.from(e);
      return e;
    }).toList();

final List cachedAlbumsList =
    (Hive.box('cache').get('cachedAlbums', defaultValue: []) as List).map((e) {
      e = Map<String, dynamic>.from(e);
      return e;
    }).toList();

final ValueNotifier<int> currentLikedAlbumsLength = ValueNotifier<int>(
  userLikedAlbumsList.length,
);

final Set<FutureTracker> getAlbumInfoQueue = {};

final FutureTracker _writeCacheFuture = FutureTracker(null);

dynamic _getCachedAlbum(dynamic album) {
  try {
    Map cached = cachedAlbumsList.firstWhere(
      (e) => checkAlbum(e, album),
      orElse: () => <String, dynamic>{},
    );
    if (cached.isEmpty) return null;
    cached = Map<String, dynamic>.from(cached);
    return cached;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

void addAlbumToCache(Map<String, dynamic> album) {
  if (isAlbumValid(album)) {
    cachedAlbumsList.addOrUpdateWhere(checkAlbum, album);
  }
}

Future<void> _writeToCache() async {
  try {
    await _writeCacheFuture.runFuture(
      addOrUpdateData(
        'cache',
        'cachedAlbums',
        cachedAlbumsList.map((e) {
          e = copyMap(e);
          return e;
        }).toList(),
      ),
    );
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future queueAlbumInfoRequest(dynamic album) {
  try {
    final existing = getAlbumInfoQueue.where((e) => checkAlbum(e.data, album));
    if (existing.isEmpty) {
      final futureTracker = FutureTracker(album);
      getAlbumInfoQueue.add(futureTracker);
      return futureTracker.runFuture(getAlbumInfo(album));
    }
    return getAlbumInfoQueue.isNotEmpty
        ? existing.first.completer!.future
        : Future.value(album);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return Future.value(album);
  }
}

Future<Map<String, dynamic>> getAlbumInfo(dynamic album) async {
  Map<String, dynamic> albumData = {};
  try {
    if (album is String && album.mbid.isNotEmpty) {
      albumData = Map<String, dynamic>.from(await _findMBAlbum(album));
    } else {
      final id = parseEntityId(album);
      final ids = Uri.parse('?$id').queryParameters;
      final mbid =
          ((album['id'] ?? album['mbid'] ?? id.mbid ?? ids['mb'] ?? '')
                  as String)
              .mbid;
      if (mbid.isNotEmpty) {
        albumData = Map<String, dynamic>.from(
          await _getAlbumDetailsById(album),
        );
      } else if (isAlbumTitleValid(album)) {
        albumData = Map<String, dynamic>.from(
          await _findMBAlbum(
            album['title'],
            artist: isAlbumArtistValid(album) ? album['artist'] : null,
          ),
        );
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  album = Map<String, dynamic>.from(albumData);
  album['id'] = parseEntityId(album);
  addAlbumToCache(album);
  await PM.triggerHook(album, 'onGetAlbumInfo');
  getAlbumInfoQueue.removeWhere((e) => checkAlbum(e.data, album));
  if (getAlbumInfoQueue.isEmpty &&
      (_writeCacheFuture.completer?.future == null ||
          _writeCacheFuture.isComplete)) {
    unawaited(_writeToCache());
  }
  return album;
}

Future<Map> _getAlbumDetailsById(dynamic album) async {
  try {
    final id = parseEntityId(album);
    final ids = Uri.parse('?${parseEntityId(id)}').queryParameters;
    final cached = _getCachedAlbum(album);
    if (isAlbumValid(cached) && isMusicbrainzAlbumValid(cached)) {
      if (cached['images'] == null) {
        cached.addAll(await getAlbumCoverArt(cached));
      }
      if (cached['list'] == null || cached['list'].isEmpty) {
        cached['list'] = await getTrackList(cached);
      }
      if (album is Map && cached is Map) {
        for (final key in album.keys) {
          if (!cached.containsKey(key) &&
              !['id', 'title', 'artist', 'primary-type'].contains(key))
            cached[key] = album[key];
        }
      }
      album = cached;
    } else {
      if (ids['mb'] == null) {
        throw Exception('Invalid album data');
      }
      album = await mb.releaseGroups.get(
        ids['mb']!,
        inc: ['artists', 'releases', 'annotation', 'tags', 'genres', 'ratings'],
      );
      if (album['error'] != null) throw album['error'];
      album['artist'] = combineArtists(album) ?? album['artist'];
      album['album'] = album['title'];
      album['cachedAt'] = DateTime.now().toString();
      album['musicbrainz'] = true;
      await getAlbumCoverArt(album);
      if (album['primary-type']?.toLowerCase() != 'single')
        await getTrackList(album);
      else
        await _getSinglesDetails(album);
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  album = Map<String, dynamic>.from(album);
  parseEntityId(album);
  return album;
}

Future<Map<String, dynamic>> _findMBAlbum(
  String title, {
  String? artist,
  int? limit,
}) async {
  Map<String, dynamic> albumData = {};
  try {
    final query =
        artist == null
            ? '(\'$title\' AND type:\'album\')'
            : '(\'$title\' AND artist:\'$artist\' AND type:\'album\') OR (\'$artist\' AND artist:\'$title\' AND type:\'album\')';
    final albQry = await mb.releaseGroups.search(query, limit: limit ?? 25);
    final albums = ((albQry ?? {})['release-groups'] ?? []) as List;
    if (albums.isEmpty) return {};
    albumData = Map<String, dynamic>.from(albums.first);
    final id = (albumData['artist-credit'] as List).first['artist']['id'];
    final artistInfo = await getArtistDetails(id);
    if (artistInfo.isNotEmpty) {
      albumData['artist-details'] = artistInfo;
      albumData['artist'] = artistInfo['artist'];
      albumData['artistId'] = artistInfo['id'];
    }
    albumData['album'] = albumData['title'];
    albumData['artist'] = combineArtists(albumData) ?? albumData['artist'];
    albumData['cachedAt'] = DateTime.now().toString();
    await getAlbumCoverArt(albumData);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return {'id': null, 'title': title, 'artist': artist};
  }
  parseEntityId(albumData);
  return albumData;
}

Future<Map<String, dynamic>> getAlbumCoverArt(
  Map<String, dynamic> album,
) async {
  if (album.isEmpty) return album;
  try {
    final ids = Uri.parse('?${parseEntityId(album)}').queryParameters;
    if (ids['mb'] != null) {
      final result = Map<String, dynamic>.from(
        await mb.coverArt.get(ids['mb']!, 'release-group'),
      );
      if (result['error'] == null) {
        album['images'] = result['images'];
        album['release'] = result['release'];
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return album;
}

Future<dynamic> getAlbumsCoverArt(List<dynamic> albums) async {
  if (albums.isEmpty) return albums;
  try {
    for (dynamic album in albums) {
      album = Map<String, dynamic>.from(album);
      final cached = _getCachedAlbum(album);
      if (isAlbumValid(cached)) {
        if (cached['images'] == null) {
          cached.addAll(await getAlbumCoverArt(cached));
        }
        if (album is Map && cached is Map) {
          for (final key in album.keys) {
            if (!cached.containsKey(key) &&
                !['id', 'title', 'artist', 'primary-type'].contains(key))
              cached[key] = album[key];
          }
        }
        album = cached;
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return albums;
}

Future<dynamic> _getSinglesDetails(dynamic song) async {
  final id = parseEntityId(song);
  final ids = Uri.parse('?${parseEntityId(id)}').queryParameters;
  final rgid =
      song['mbidType'] == 'release-group'
          ? ((song['rgid'] ?? song['mbid'] ?? '') as String).mbid
          : (ids['mb'] ?? (song['mbid'] as String).mbid);
  if (rgid.isEmpty) return song;
  try {
    final cached = _getCachedAlbum(song);
    if (cached != null && cached['list'] != null && cached['list'].length > 1)
      cached.remove('list');
    if (isAlbumValid(cached) &&
        isMusicbrainzAlbumValid(cached) &&
        cached['list'] != null &&
        cached['list'].isNotEmpty) {
      if (song is Map && cached is Map) {
        for (final key in song.keys) {
          if (!cached.containsKey(key) &&
              !['id', 'title', 'artist', 'primary-type'].contains(key))
            cached[key] = song[key];
        }
      }
      for (dynamic recording in cached['list']) {
        recording = copyMap(await getSongInfo(recording));
        if (isYouTubeSongValid(recording) &&
            checkTitleAndArtist(cached, recording)) {
          cached['ytid'] = (recording['ytid'] as String).ytid;
          cached['id'] = parseEntityId(cached);
          break;
        }
      }
      song = cached;
    } else {
      final recordings =
          (await mb.recordings.search('rgid:$rgid'))?['recordings'] ?? [];
      for (final recording in recordings) {
        recording['artist'] = combineArtists(recording);
        if (isYouTubeSongValid(recording)) recording['ytid'] = song['ytid'];
        if (checkTitleAndArtist(song, recording) ||
            (!isSongTitleValid(song) && !isSongArtistValid(song))) {
          //final result = copyMap(await getSongInfo(recording['id']));
          song.addAll(<String, dynamic>{
            'rgid': (song['id'] as String).mbid,
            'rid': (recording['id'] as String).mbid,
            'mbidType': 'release-group',
            'list': [recording],
          });
          recording.removeWhere(
            (key, value) => ['id', 'mbid', 'mbidType'].contains(key),
          );
          song.addAll(recording);
          break;
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  parseEntityId(song);
  song = Map<String, dynamic>.from(song);
  return song;
}

Future<dynamic> getSinglesTrackList(List<dynamic> singlesReleases) async {
  try {
    final tracks = [];
    for (final releaseGroup in singlesReleases) {
      tracks.add(await _getSinglesDetails(releaseGroup));
    }
    return tracks.toList();
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return [];
  }
}

Future<List?> getTrackList(dynamic album) async {
  try {
    final albumId = parseEntityId(album);
    final cached = _getCachedAlbum(album);
    if (isAlbumValid(cached) &&
        cached['list'] != null &&
        cached['list'].isNotEmpty) {
      return cached['list'];
    }
    final ids = albumId.toIds;
    final mbid = ((album['mbid'] ?? ids['mb'] ?? '') as String).mbid;
    if (mbid.isEmpty) return album['list'] ?? [];
    final recordings =
        (await mb.recordings.search(
          'rgid:$mbid',
          paginated: false,
        ))?['recordings'] ??
        [];
    final trackList = LinkedHashSet<String>();
    album['list'] = [];
    for (dynamic recording in recordings) {
      if (!(derivativeRegex.hasMatch(recording['title'] ?? '') &&
              boundExtrasRegex.hasMatch(recording['title'] ?? '')) &&
          trackList.add(recording['title'])) {
        recording['artist'] =
            combineArtists(recording) ?? combineArtists(album);
        final cached = getCachedSong(recording);
        if (isSongValid(cached)) {
          recording = cached;
        }
        recording.addAll({
          'image': album['image'] ?? album['images'],
          'lowResImage': album['image'] ?? album['images'],
          'highResImage': album['image'] ?? album['images'],
        });
        recording = Map<String, dynamic>.from(recording);
        album['list'].add(recording);
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  parseEntityId(album);
  album = Map<String, dynamic>.from(album);
  return album['list'];
}

/// Returns current liked status if successful.
Future<bool> updateAlbumLikeStatus(dynamic album, bool add) async {
  try {
    if (add) {
      album['id'] = parseEntityId(album);
      if (album['id']?.isEmpty) throw Exception('ID is null or empty');
      if (album['id'] != null &&
          (album['image'] == null || album['image'].isEmpty))
        unawaited(getAlbumCoverArt(Map<String, dynamic>.from(album)));
      userLikedAlbumsList.addOrUpdate('id', album['id'], <String, dynamic>{
        'id': album['id'],
        'artist': album['artist'],
        'title': album['title'],
        'image': album['image'],
        'genres': album['genres'] ?? album['musicbrainz']?['genres'] ?? [],
        'primary-type': album['primary-type'],
      });
      currentLikedAlbumsLength.value = userLikedAlbumsList.length;
      album['album'] = album['title'];
      await PM.triggerHook(album, 'onEntityLiked');
    } else {
      userLikedAlbumsList.removeWhere((value) => checkAlbum(album, value));
      currentLikedAlbumsLength.value = userLikedAlbumsList.length;
    }
    unawaited(addOrUpdateData('user', 'likedAlbums', userLikedAlbumsList));
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return !add;
  }
}

bool isMusicbrainzAlbumValid(dynamic album) {
  if (album == null || !(album is Map)) return false;
  final idValid = isAlbumIdValid(album);
  final titleValid = isAlbumTitleValid(album);
  final artistValid = isAlbumArtistValid(album);
  final isFetched =
      album['musicbrainz'] != null && album['musicbrainz'] == true;
  return idValid && titleValid && artistValid && isFetched;
}

bool isAlbumValid(dynamic album) {
  if (album == null || !(album is Map)) return false;
  return album['primary-type'] != null &&
      isAlbumIdValid(album) &&
      isAlbumTitleValid(album) &&
      isAlbumArtistValid(album);
}

bool isAlbumIdValid(dynamic album) {
  if (album == null || !(album is Map)) return false;
  album['id'] = parseEntityId(album['id']);
  return album.isNotEmpty && album['id'] != null && album['id'].isNotEmpty;
}

bool isAlbumTitleValid(dynamic album) {
  if (album == null || !(album is Map)) return false;
  final title = album['title'] ?? album['album'];
  return album.isNotEmpty &&
      (title != null && title.isNotEmpty && title != 'unknown');
}

bool isAlbumArtistValid(dynamic album) {
  if (album == null || !(album is Map)) return false;
  final artist = (album['artist'] is String ? album['artist'] : null);
  return album.isNotEmpty &&
      (artist != null && artist.isNotEmpty && artist != 'unknown');
}

bool isAlbumAlreadyLiked(albumToCheck) =>
    albumToCheck is Map &&
    userLikedAlbumsList.any(
      (album) => album is Map && checkAlbum(album, albumToCheck),
    );

int? getAlbumHashCode(dynamic album) {
  if (!(album is Map)) return null;
  if (!isAlbumTitleValid(album) || !isAlbumArtistValid(album)) return null;
  final title = (album['title'] ?? album['album']) as String?;
  final artist = album['artist'] as String?;
  return title!.cleansed.toLowerCase().hashCode ^
      artist!.cleansed.toLowerCase().hashCode;
}

bool checkAlbum(dynamic albumA, dynamic albumB) {
  if (albumA == null || albumB == null || albumA.isEmpty || albumB.isEmpty)
    return false;
  if (albumA is Map) albumA['id'] = parseEntityId(albumA);
  if (albumB is Map) albumB['id'] = parseEntityId(albumB);
  if (albumA is String && albumB is String)
    return (albumA.isNotEmpty && albumB.isNotEmpty) &&
        checkEntityId(albumA, albumB);
  if (albumA is String && albumB is Map)
    return (albumA.isNotEmpty &&
            albumB['id'] != null &&
            albumB['id'].isNotEmpty) &&
        (checkEntityId(albumA, albumB['id']) ||
            checkEntityId(albumB['id'], albumA));
  if (albumB is String && albumA is Map)
    return (albumB.isNotEmpty &&
            albumA['id'] != null &&
            albumA['id'].isNotEmpty) &&
        (checkEntityId(albumB, albumA['id']) ||
            checkEntityId(albumA['id'], albumB));
  if (albumA['id'] == null ||
      albumB['id'] == null ||
      albumA['id'].isEmpty ||
      albumB['id'].isEmpty)
    return getAlbumHashCode(albumA) == getAlbumHashCode(albumB);
  parseEntityId(albumA);
  parseEntityId(albumB);
  return checkEntityId(albumA['id'], albumB['id']);
}
