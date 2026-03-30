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

import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/notifiable_future.dart';
import 'package:reverbio/utilities/utils.dart';

// R14 fix: Changed from Set to List for clarity (Set had no custom hashCode/==)
final List<NotifiableFuture<Map<String, dynamic>>> getAlbumInfoQueue = [];

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
    cachedAlbumsList.addOrUpdate(album, checkAlbum);
  }
}

Map<String, dynamic> minimizeAlbumData(dynamic album) {
  return {
    'id': parseEntityId(album),
    'primary-type': album['primary-type'] ?? 'album',
    'genres': album['genres'] ?? album['musicbrainz']?['genres'] ?? [],
    'title': album['title'],
    'artist': album['artist'],
    'artist-credit': album['artist-credit'],
    'first-release-date': album['first-release-date'],
    // R12 fix: Add type check before accessing e['id'] on non-Maps
    'list':
        ((album['list'] ?? []) as Iterable).where((e) => e != null).map((e) {
          if (e is String) return e;
          if (e is Map) return e['id'];
          return e.toString();
        }).toList(),
    'cachedAt': DateTime.now().toString(),
    'image':
        album['validImage'] ??
        album['highResImage'] ??
        album['lowResImage'] ??
        album['image'],
  };
}

NotifiableFuture<Map<String, dynamic>> queueAlbumInfoRequest(dynamic album) {
  try {
    final existing = getAlbumInfoQueue.where((e) => checkAlbum(e.data, album));
    if (existing.isEmpty) {
      final futureTracker = NotifiableFuture<Map<String, dynamic>>.withFuture(
        album,
        getAlbumInfo(album),
      );
      getAlbumInfoQueue.add(futureTracker);
      return futureTracker;
    } else {
      return existing.first;
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return NotifiableFuture.fromValue(album);
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
    return album;  // R2 fix: Return original album on error, don't cache empty data
  }
  // R2 fix: Don't cache invalid/empty album data
  if (!isAlbumValid(albumData)) return album;
  album = Map<String, dynamic>.from(albumData);
  album['id'] = parseEntityId(album);
  addAlbumToCache(album);
  await PM.triggerHook(album, 'onGetAlbumInfo');
  getAlbumInfoQueue.removeWhere((e) => checkAlbum(e.data, album));
  if (getAlbumInfoQueue.isEmpty) {
    cachedAlbumsList.writeToCache();
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
        final albumArtist = combineArtists(cached);
        cached['list'] = cached['list'].map((e) {
          e['album'] = cached['title'];
          e['albumArtist'] = albumArtist;
          return e;
        }).toList();
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
      if (album['error'] != null) return album;
      album['artist'] = combineArtists(album) ?? album['artist'];
      album['album'] = album['title'];
      album['cachedAt'] = DateTime.now().toString();
      album['musicbrainz'] = true;
      await getAlbumCoverArt(album);
      // R8 fix: Assign return value of getTrackList to album['list']
      if (album['primary-type']?.toLowerCase() != 'single')
        album['list'] = await getTrackList(album);
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

// R7 fix: Helper function to escape Lucene special characters
String _escapeLucene(String input) {
  const specialChars = r'+-&|!(){}[]^"~*?:\/';
  final buffer = StringBuffer();
  for (final char in input.split('')) {
    if (specialChars.contains(char)) {
      buffer.write('\\');
    }
    buffer.write(char);
  }
  return buffer.toString();
}

Future<Map<String, dynamic>> _findMBAlbum(
  String title, {
  String? artist,
  int? limit,
}) async {
  Map<String, dynamic> albumData = {};
  try {
    // R7 fix: Escape Lucene special characters to prevent query injection
    final escapedTitle = _escapeLucene(title);
    final escapedArtist = artist != null ? _escapeLucene(artist) : null;
    final query =
        artist == null
            ? '(\'$escapedTitle\' AND type:\'album\')'
            : '(\'$escapedTitle\' AND artist:\'$escapedArtist\' AND type:\'album\') OR (\'$escapedArtist\' AND artist:\'$escapedTitle\' AND type:\'album\')';
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
    album['image'] = (await getValidImage(album)).toString();
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return album;
}

Future<dynamic> getAlbumsCoverArt(List<dynamic> albums) async {
  if (albums.isEmpty) return albums;
  try {
    // R1 fix: Use indexed loop to actually modify the list (loop variable reassignment has no effect)
    for (int i = 0; i < albums.length; i++) {
      final album = Map<String, dynamic>.from(albums[i]);
      final cached = _getCachedAlbum(album);
      if (isAlbumValid(cached)) {
        if (cached['images'] == null) {
          cached.addAll(await getAlbumCoverArt(cached));
        }
        // album is already Map<String, dynamic>, no need to check
        for (final key in album.keys) {
          if (!cached.containsKey(key) &&
              !['id', 'title', 'artist', 'primary-type'].contains(key))
            cached[key] = album[key];
        }
        albums[i] = cached;
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
  // R3 fix: Add null-safe fallback for mbid (was causing NoSuchMethodError on null)
  final rgid =
      song['mbidType'] == 'release-group'
          ? ((song['rgid'] ?? song['mbid'] ?? '') as String).mbid
          : (ids['mb'] ?? (song['mbid'] ?? '') as String).mbid;
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
      final albumArtist = combineArtists(cached);
      // R13 fix: Use indexed loop to actually update list elements (loop variable reassignment has no effect)
      for (int i = 0; i < cached['list'].length; i++) {
        final recording = copyMap(await getSongInfo(cached['list'][i]));
        recording['album'] = cached['title'];
        recording['albumArtist'] = albumArtist;
        if (isYouTubeSongValid(recording) &&
            checkTitleAndArtist(cached, recording)) {
          cached['ytid'] = (recording['ytid'] as String).ytid;
          cached['id'] = parseEntityId(cached);
          cached['list'][i] = recording;
          break;
        }
      }
      song = cached;
    } else {
      final recordings =
          (await mb.recordings.search('rgid:$rgid'))?['recordings'] ?? [];
      final albumArtist = combineArtists(song);
      for (final recording in recordings) {
        recording['artist'] = combineArtists(recording);
        if (isYouTubeSongValid(recording)) recording['ytid'] = song['ytid'];
        if (checkTitleAndArtist(song, recording) ||
            (!isSongTitleValid(song) && !isSongArtistValid(song))) {
          song.addAll(<String, dynamic>{
            'rgid': (song['id'] as String).mbid,
            'rid': (recording['id'] as String).mbid,
            'album': songTitle(song),
            'albumArtist': albumArtist,
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
    final list = <Map<String, dynamic>>[];
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
          'album': album['title'],
          'albumArtist': combineArtists(album),
          'image': album['validImage'] ?? album['image'] ?? album['images'],
          'lowResImage':
              album['validImage'] ?? album['image'] ?? album['images'],
          'highResImage':
              album['validImage'] ?? album['image'] ?? album['images'],
        });
        recording = Map<String, dynamic>.from(recording);
        list.add(recording);
      }
    }
    album['list'] = list;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  parseEntityId(album);
  return album['list'];
}

/// Returns current liked status if successful.
Future<bool> updateAlbumLikeStatus(dynamic album, bool add) async {
  try {
    if (add) {
      album['id'] = parseEntityId(album);
      // R10 fix: Check for null OR empty (not just empty)
      if (album['id'] == null || album['id'].isEmpty) throw Exception('ID is null or empty');
      // R11 fix: Pass original album directly, not a copy
      if (album['image'] == null || album['image'].isEmpty)
        unawaited(getAlbumCoverArt(album));
      userLikedAlbumsList.addOrUpdate(minimizeAlbumData(album), checkAlbum);
      album['album'] = album['title'];
      await PM.triggerHook(album, 'onEntityLiked');
    } else {
      userLikedAlbumsList.removeWhere((value) => checkAlbum(album, value));
    }
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
  // R4 fix: Remove side effect - validation should not mutate input
  final id = parseEntityId(album['id']);
  return album.isNotEmpty && id.isNotEmpty;
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
    userLikedAlbumsList.any((album) => checkAlbum(album, albumToCheck));

int? getAlbumHashCode(dynamic album) {
  if (!(album is Map)) return null;
  if (!isAlbumTitleValid(album) || !isAlbumArtistValid(album)) return null;
  // R6 fix: Use safe access patterns instead of force-unwrap
  final title = (album['title'] ?? album['album']) as String?;
  final artist = album['artist'] as String?;
  if (title == null || artist == null) return null;
  return title.cleansed.toLowerCase().hashCode ^
      artist.cleansed.toLowerCase().hashCode;
}

bool checkAlbum(dynamic albumA, dynamic albumB) {
  if (albumA == null || albumB == null || albumA.isEmpty || albumB.isEmpty)
    return false;
  // R5 fix: Use local variables instead of mutating inputs, add type guards
  final idA = albumA is Map ? parseEntityId(albumA) : albumA;
  final idB = albumB is Map ? parseEntityId(albumB) : albumB;
  if (albumA is String && albumB is String)
    return (albumA.isNotEmpty && albumB.isNotEmpty) &&
        checkEntityId(albumA, albumB);
  if (albumA is String && albumB is Map)
    return (albumA.isNotEmpty &&
            idB != null &&
            idB.isNotEmpty) &&
        (checkEntityId(albumA, idB) ||
            checkEntityId(idB, albumA));
  if (albumB is String && albumA is Map)
    return (albumB.isNotEmpty &&
            idA != null &&
            idA.isNotEmpty) &&
        (checkEntityId(albumB, idA) ||
            checkEntityId(idA, albumB));
  if (idA == null ||
      idB == null ||
      idA.isEmpty ||
      idB.isEmpty)
    return getAlbumHashCode(albumA) == getAlbumHashCode(albumB);
  return checkEntityId(idA, idB);
}
