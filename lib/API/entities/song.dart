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
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/widgets.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/lyrics_manager.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

List globalSongs = [];
final List userLikedSongsList =
    (Hive.box('user').get('likedSongs', defaultValue: []) as List).map((e) {
      e = Map<String, dynamic>.from(e);
      return e;
    }).toList();
final List<String> userOfflineSongs = Hive.box(
  'userNoBackup',
).get('offlineSongs', defaultValue: <String>[]);

final List cachedSongsList =
    (Hive.box('cache').get('cachedSongs', defaultValue: []) as List).map((e) {
      e = Map<String, dynamic>.from(e);
      return e;
    }).toList();

final ValueNotifier<int> currentLikedSongsLength = ValueNotifier<int>(
  userLikedSongsList.length,
);
final ValueNotifier<int> currentOfflineSongsLength = ValueNotifier<int>(
  userOfflineSongs.length,
);
final ValueNotifier<int> currentRecentlyPlayedLength = ValueNotifier<int>(
  userRecentlyPlayed.length,
);
final ValueNotifier<int> activeQueueLength = ValueNotifier<int>(
  audioHandler.queueSongBars.length,
);

int activeSongId = 0;

final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;

final Set<FutureTracker> getSongInfoQueue = {};

final FutureTracker _writeCacheFuture = FutureTracker(null);

Future<List> getSongsList(String searchQuery) async {
  try {
    final List<Video> searchResults = await yt.search.search(searchQuery);

    return searchResults.map(returnYtSongLayout).toList();
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return [];
  }
}

Future<List<dynamic>> getRecommendedSongs() async {
  try {
    if (globalSongs.isEmpty) {
      const playlistId = 'yt=PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx';
      globalSongs =
          (await getSongsFromPlaylist(
            playlistId,
          )).map((e) => Map<String, dynamic>.from(e)).toList();
      if (userCustomPlaylists.value.isNotEmpty) {
        for (final userPlaylist in userCustomPlaylists.value) {
          final _list =
              ((userPlaylist['list'] ?? []) as List).map((e) {
                e = Map<String, dynamic>.from(e);
                return e;
              }).toList();
          globalSongs.addOrUpdateAllWhere(checkSong, _list);
        }
      }
      globalSongs
        ..addOrUpdateAllWhere(checkSong, await getUserOfflineSongs())
        ..addOrUpdateAllWhere(checkSong, userLikedSongsList)
        ..addOrUpdateAllWhere(checkSong, userRecentlyPlayed)
        ..addOrUpdateAllWhere(checkSong, cachedSongsList);
    }
    return globalSongs;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return [];
  }
}

Future<bool> updateSongLikeStatus(dynamic song, bool add) async {
  try {
    song['id'] = parseEntityId(song);
    if (song['id']?.isEmpty) throw Exception('ID is null or empty');
    if (add && song != null) {
      userLikedSongsList.addOrUpdateWhere(checkSong, song);
      currentLikedSongsLength.value = userLikedSongsList.length;
      song['song'] = song['mbTitle'] ?? song['title'] ?? song['ytTitle'];
      unawaited(PM.triggerHook(song, 'onEntityLiked'));
    } else {
      userLikedSongsList.removeWhere((s) => checkSong(s, song));
      currentLikedSongsLength.value = userLikedSongsList.length;
    }
    unawaited(addOrUpdateData('user', 'likedSongs', userLikedSongsList));
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return !add;
  }
}

void moveLikedSong(int oldIndex, int newIndex) {
  final _song = userLikedSongsList[oldIndex];
  userLikedSongsList
    ..removeAt(oldIndex)
    ..insert(newIndex, _song);
  currentLikedSongsLength.value = userLikedSongsList.length;
  unawaited(addOrUpdateData('user', 'likedSongs', userLikedSongsList));
}

bool isSongAlreadyLiked(songToCheck) =>
    songToCheck is Map &&
    userLikedSongsList.any(
      (song) => song is Map && checkSong(song, songToCheck),
    );

void getSimilarSong(String songYtId) async {
  try {
    final song = await yt.videos.get(songYtId);
    final relatedSongs = await yt.videos.getRelatedVideos(song) ?? [];

    if (relatedSongs.isNotEmpty) {
      nextRecommendedSong = returnYtSongLayout(relatedSongs[0]);
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<Map<String, dynamic>> _findYTSong(dynamic song) async {
  Map<String, dynamic> ytSong = <String, dynamic>{};
  try {
    final id = parseEntityId(song);
    final ytid = id.ytid;
    if (ytid.isNotEmpty) {
      ytSong = await _getYTSongDetails(song);
      if (ytSong.isNotEmpty) {
        song['ytid'] = ytSong['id'];
        song['id'] = parseEntityId(song);
      }
    } else {
      final lcSongName =
          (song['mbTitle'] ?? song['title'] ?? song['ytTitle'] ?? '') as String;
      final lcArtist =
          (song['mbArtist'] ?? song['artist'] ?? song['ytArtist'] ?? '')
              as String;
      if (lcSongName.collapsed.isEmpty && lcArtist.collapsed.isEmpty)
        throw Exception('Cannot find YouTubeSong. Invalid song: $song');
      final qry = '$lcArtist $lcSongName';
      final results = await getSongsList(qry);
      results.sort((a, b) => b['views'].compareTo(a['views']));
      final result =
          results.where((value) {
            return checkTitleAndArtist(value, song) &&
                ((song['duration'] ?? 0) == 0 ||
                    (value['duration'] ?? 0) == 0 ||
                    withinPercent(
                      (song['duration'] as int).toDouble(),
                      (value['duration'] as int).toDouble(),
                      90,
                    ));
          }).toList();
      if (result.isNotEmpty) {
        ytSong = await _getYTSongDetails(result.first);
        if (ytSong.isNotEmpty) {
          song['ytid'] = ytSong['ytid'];
          ytSong['id'] = parseEntityId(song);
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return ytSong;
}

Map<String, dynamic>? getCachedSong(dynamic song) {
  try {
    dynamic cached = cachedSongsList.firstWhere(
      (e) => checkSong(song, e),
      orElse: () => <String, dynamic>{},
    );
    if (cached.isEmpty || !isSongValid(cached)) return null;
    cached = Map<String, dynamic>.from(cached);
    return cached;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

void addSongToCache(Map<String, dynamic> song) {
  if (isSongValid(song)) {
    cachedSongsList.addOrUpdateWhere(checkSong, song);
  }
}

Future<void> _writeToCache() async {
  try {
    await _writeCacheFuture.runFuture(
      addOrUpdateData(
        'cache',
        'cachedSongs',
        cachedSongsList.map((e) {
          e = Map<String, dynamic>.from(jsonDecode(jsonEncode(e)));
          return e;
        }).toList(),
      ),
    );
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<dynamic> _getSongByRecordingDetails(
  dynamic song, {
  bool getImage = true,
}) async {
  Map<String, dynamic> recording = {};
  try {
    final id = parseEntityId(song);
    final rcdId = ((song['rid'] ?? id.mbid) as String).mbid;
    String ytid = ((song['ytid'] ?? id.ytid) as String).ytid;
    if (rcdId.isEmpty) return song;
    final cached = getCachedSong(song);
    if (isSongValid(cached) && isMusicbrainzSongValid(cached)) {
      final cytid = ((cached!['ytid'] ?? id.ytid) as String).ytid;
      cached['ytid'] = cytid;
      if (song is Map) {
        for (final key in song.keys) {
          if (!cached.containsKey(key) &&
              !['id', 'title', 'artist', 'primary-type'].contains(key))
            cached[key] = song[key];
        }
      }
      cached['id'] = parseEntityId(cached);
      recording = cached;
    } else {
      recording.addAll(
        Map<String, dynamic>.from(
          await mb.recordings.get(
            rcdId,
            inc: [
              'artists',
              'releases',
              'release-groups',
              'isrcs',
              'url-rels',
              'artist-credits',
              'genres',
              'artist-rels',
              'release-rels',
              'release-group-rels',
            ],
          ),
        ),
      );
      recording['artist'] = combineArtists(recording) ?? 'Unknown';
      if (getImage)
        for (final release in (recording['releases'] ?? [])) {
          final coverArt = await mb.coverArt.get(release['id'], 'release');
          if (coverArt['error'] == null) {
            //TODO: parse by image size
            recording['images'] = coverArt['images'];
            break;
          }
        }
      if (ytid.isEmpty) {
        final ytLink =
            ((recording['relations'] ?? []) as List).firstWhere((e) {
              final url = (e['url']?['resource'] ?? '') as String;
              return youtubeValidate(url) ||
                  url.contains('youtube') ||
                  url.contains('youtu.be');
            }, orElse: () => {})['url']?['resource'];
        ytid = Uri.parse('${ytLink ?? ''}').queryParameters['v'] ?? '';
        recording['ytid'] = ytid;
      }
      if (recording['error'] == null) {
        recording.addAll(<String, dynamic>{
          'rid': (recording['id'] as String).mbid,
          'mbid': (recording['id'] as String).mbid,
          'mbTitle': recording['title'],
          'mbArtist': recording['artist'],
          'mbidType': 'recording',
          'duration': (recording['length'] ?? 0) ~/ 1000,
          'primary-type': 'song',
          'cachedAt': DateTime.now().toString(),
          'artist': recording['artist'],
          'musicbrainz': true,
          'isDerivative':
              derivativeRegex.hasMatch(recording['title'] ?? '') &&
              boundExtrasRegex.hasMatch(recording['title'] ?? ''),
          'derivative-type':
              (derivativeRegex.hasMatch(recording['title'] ?? '')
                      ? boundExtrasRegex
                          .firstMatch(recording['title'] ?? '')
                          ?.group(1)
                      : null)
                  as dynamic,
        });
        recording['id'] = parseEntityId(recording);
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  recording = Map<String, dynamic>.from(recording);
  return recording;
}

Future<dynamic> _findSongByIsrc(dynamic song) async {
  Map<String, dynamic> recording = {};
  try {
    final id = parseEntityId(song);
    final rcdId = ((song['rid'] ?? id.mbid) as String).mbid;
    final isrc = ((song['isrc'] ?? id.isrc) as String).isrc;
    if (rcdId.isNotEmpty)
      recording = await _getSongByRecordingDetails(song);
    else if (isrc.isEmpty)
      recording = await _findMBSong(song);
    else {
      final qry = 'isrc:$isrc';
      final qryResult =
          (await mb.recordings.search(qry, limit: 10))?['recordings'] ?? [];
      final recordings = List<Map<String, dynamic>>.from(qryResult);
      for (dynamic recording in recordings) {
        recording['artist'] = combineArtists(recording);
        if (song['ytid'] != null && song['ytid'].isNotEmpty)
          recording['ytid'] = song['ytid'];
        if ((recording['isrcs'] as List).contains(isrc)) {
          recording = await _getSongByRecordingDetails(recording);
          recording['isrc'] = isrc;
          recording['id'] = parseEntityId(recording);
          recording['id'] = (recording['id'] as String).mergedAbsentId(
            song['id'],
          );
          break;
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  recording = Map<String, dynamic>.from(recording);
  return recording;
}

Future<dynamic> _findMBSong(dynamic song) async {
  try {
    final cached = getCachedSong(song);
    if (isSongValid(cached) && isMusicbrainzSongValid(cached)) {
      if (song is Map && cached is Map) {
        for (final key in song.keys) {
          if (!cached!.containsKey(key) &&
              !['id', 'title', 'artist', 'primary-type'].contains(key))
            cached[key] = song[key];
        }
      }
      cached!['id'] = parseEntityId(cached);
      song = cached;
    } else {
      final id = parseEntityId(song);
      final mbid = ((song['mbid'] ?? id.mbid) as String).mbid;
      final isrc = ((song['isrc'] ?? id.isrc) as String).isrc;
      final ytid = ((song['ytid'] ?? id.ytid) as String).ytid;
      if (mbid.isNotEmpty) {
        dynamic songInfo = Map<String, dynamic>.from(
          await _getSongByRecordingDetails(song),
        );
        if (isSongValid(songInfo)) {
          song.addAll(songInfo);
        } else {
          songInfo = Map<String, dynamic>.from(await getAlbumInfo(song));
        }
        if (isSongValid(songInfo)) {
          song.addAll(songInfo);
        }
      } else if (isrc.isNotEmpty) {
        song.addAll(await _findSongByIsrc(song));
      } else {
        if (!isYouTubeSongValid(song) && ytid.isNotEmpty) {
          song['ytid'] = ytid;
          final ytSong = await _getYTSongDetails(song);
          if (ytSong.isNotEmpty) {
            song['ytid'] = ytid;
            song['id'] = parseEntityId(song);
            ytSong.remove('id');
            song.addAll(Map<String, dynamic>.from(ytSong));
          }
        }
        final String iArtist =
            combineArtists(song) ??
            song['mbArtist'] ??
            song['artist'] ??
            song['ytArtist'] ??
            '';
        final String iTitle = sanitizeSongTitle(
          song['mbTitle'] ?? song['title'] ?? song['ytTitle'] ?? '',
        );
        final artists = splitArtists(iArtist);
        final artistList = [];
        for (final artist in artists) {
          final splits = splitLatinNonLatin(artist.toLowerCase());
          final qry =
              'sortname:(${splits.map((e) => '"${e.trim()}"').join('OR')})'
                  .collapsed
                  .toLowerCase();
          final artistSearch =
              (((await mb.artists.search(qry, limit: 5))?['artists'] ?? [])
                    as List)
                ..sort((a, b) => a['name'].compareTo(b['name']));
          for (final artistResult in artistSearch) {
            artistResult['mbid'] = (artistResult['id'] as String).mbid;
            if (splits.any(
                  (e) => e.trim().contains(
                    artistResult['name'].trim().toLowerCase(),
                  ),
                ) ||
                splits.any(
                  (e) => e.trim().contains(
                    artistResult['sort-name'].trim().toLowerCase(),
                  ),
                )) {
              artistList.add(artistResult);
            }
          }
        }
        final artistQry =
            'artistname:(${artists.map((a) => splitLatinNonLatin(a.toLowerCase()).map((e) => '"${e.trim()}"').join('OR')).join('OR')})';
        final sTitle = removeDuplicates(
          splitLatinNonLatin(
            sanitizeSongTitle(iTitle).sanitized.toLowerCase(),
          ).map((e) => e.trim()).join('|'),
        ).replaceAll(' ', '|');
        final sArtist =
            removeDuplicates(
              sanitizeSongTitle(iArtist).cleansed.toLowerCase(),
            ).replaceAll(' ', '|').replaceAll(sTitle, '').collapsed;
        final phrase = '$sTitle|$sArtist';
        final qry =
            '((recording:$sTitle) AND ($artistQry)) OR (recording:($phrase) OR artistname:($phrase))';
        final qryResult =
            (await mb.recordings.search(qry, limit: 10))?['recordings'] ?? [];
        final recordings = List<Map<String, dynamic>>.from(qryResult);
        for (dynamic recording in recordings) {
          recording['rid'] = recording['id'];
          recording['artist'] = combineArtists(recording);
          if (song['ytid'] != null && song['ytid'].isNotEmpty)
            recording['ytid'] = song['ytid'];
          if (checkTitleAndArtist(song, recording)) {
            song['rid'] = recording['id'];
            song['mbid'] = recording['id'];
            song['mbidType'] = 'recording';
            song['id'] = parseEntityId(song);
            recording = await _getSongByRecordingDetails(song);
            recording['id'] = parseEntityId(recording);
            recording = Map<String, dynamic>.from(recording);
            song.addAll(recording);
            break;
          }
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  song['id'] = parseEntityId(song);
  song = Map<String, dynamic>.from(song);
  return song;
}

Future<StreamManifest> getSongManifest(String songId) async {
  try {
    final manifest =
        useProxies.value
            ? await pxm.getSongManifest(songId) ??
                await yt.videos.streams.getManifest(
                  songId,
                  //ytClients: userChosenClients,
                )
            : await yt.videos.streams.getManifest(
              songId,
              //ytClients: userChosenClients,
            );
    return manifest;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow; // Rethrow the exception to allow the caller to handle it
  }
}

const Duration _cacheDuration = Duration(hours: 3);

Future<void> getSongUrl(dynamic song, {bool skipDownload = false}) async {
  song['isError'] = false;
  song?.remove('error');
  final offlinePath = await getOfflinePath(song);
  if (!isMusicbrainzSongValid(song)) await queueSongInfoRequest(song);
  if (offlinePath != null) {
    song['songUrl'] = offlinePath;
  }
  if (offlinePath == null || offlinePath.isEmpty)
    await PM.getSongUrl(song, getSongYoutubeUrl);
  if (((song['autoCacheOffline'] ?? false) || autoCacheOffline.value) &&
      (song['songUrl'] != null && offlinePath == null) &&
      !skipDownload &&
      !(await FileDownloader().allTaskIds()).contains(song['id']))
    await makeSongOffline(song);
}

Future? queueSongInfoRequest(dynamic song) {
  try {
    final existing = getSongInfoQueue.where((e) => checkSong(e.data, song));
    if (existing.isEmpty) {
      final futureTracker = FutureTracker(song);
      getSongInfoQueue.add(futureTracker);
      return futureTracker.runFuture(getSongInfo(song));
    }
    return getSongInfoQueue.isNotEmpty
        ? existing.first.completer!.future
        : Future.value(song);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return Future.value(song);
  }
}

Future<Map<String, dynamic>> getSongInfo(dynamic song) async {
  late final String offlineId;
  try {
    if (song == null) return song;
    if (song is String) {
      song = <String, dynamic>{'id': song};
      song['id'] = parseEntityId(song);
    }
    if (song is Map) {
      song['id'] = parseEntityId(song);
      offlineId = getUserOfflineSong(song);
      song['id'] =
          offlineId.isEmpty
              ? song['id']
              : (song['id'] as String).mergedAbsentId(offlineId);
      song = Map<String, dynamic>.from(song);
      song['primary-type'] = song['primary-type'] ?? 'song';
      dynamic songInfo = await _findMBSong(song);
      if (!isSongValid(songInfo)) {
        songInfo = await getAlbumInfo(song);
      }
      if (isSongValid(songInfo)) {
        song.addAll(copyMap(songInfo));
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  song['title'] = song['mbTitle'] ?? song['title'] ?? song['ytTitle'] ?? '';
  song['artist'] = song['mbArtist'] ?? song['artist'] ?? song['ytArtist'] ?? '';
  song['id'] = parseEntityId(song);
  song = Map<String, dynamic>.from(song);
  addSongToCache(song as Map<String, dynamic>);
  unawaited(PM.triggerHook(song, 'onGetSongInfo'));
  getSongInfoQueue.removeWhere((e) => checkSong(e.data, song));
  if (getSongInfoQueue.isEmpty &&
      (_writeCacheFuture.completer?.future == null ||
          _writeCacheFuture.isComplete)) {
    unawaited(_writeToCache());
  }
  return song;
}

bool isYouTubeSongValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final idValid = isSongIdKeyValid(song, idKey: 'yt');
  final titleValid = isSongTitleValid(song);
  final artistValid = isSongArtistValid(song);
  final isFetched = song['youtube'] != null && song['youtube'] == true;
  return idValid && titleValid && artistValid && isFetched;
}

bool isMusicbrainzSongValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final idValid = isSongIdKeyValid(song, idKey: 'mb');
  final titleValid = isSongTitleValid(song);
  final artistValid = isSongArtistValid(song);
  final isFetched = song['musicbrainz'] != null && song['musicbrainz'] == true;
  return idValid && titleValid && artistValid && isFetched;
}

bool isSongValid(dynamic song) {
  final idValid = isSongIdValid(song);
  final titleValid = isSongTitleValid(song);
  final artistValid = isSongArtistValid(song);
  return idValid && titleValid && artistValid;
}

bool isSongIdValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final isValid =
      song.isNotEmpty && song['id'] != null && song['id'].isNotEmpty;
  return isValid;
}

bool isSongIdKeyValid(dynamic song, {String idKey = 'mbid'}) {
  if (song == null || !(song is Map)) return false;
  final id = parseEntityId(song);
  final ids = id.toIds;
  if (idKey == 'mbid' || idKey == 'mb')
    return song.isNotEmpty &&
        song['mbid'] != null &&
        song['mbid'].isNotEmpty &&
        (song['mbid'] as String).mbid.isNotEmpty &&
        ids['mb'] != null &&
        ids['mb']!.isNotEmpty &&
        (ids['mb'] as String).mbid.isNotEmpty;
  if (idKey == 'dcid' || idKey == 'dc')
    return song.isNotEmpty &&
        song['dcid'] != null &&
        song['dcid'].isNotEmpty &&
        (song['dcid'] as String).dcid.isNotEmpty &&
        ids['dc'] != null &&
        ids['dc']!.isNotEmpty &&
        (ids['dc'] as String).mbid.isNotEmpty;
  if (idKey == 'isrc' || idKey == 'is')
    return song.isNotEmpty &&
        song['isrc'] != null &&
        song['isrc'].isNotEmpty &&
        (song['isrc'] as String).isrc.isNotEmpty &&
        ids['is'] != null &&
        ids['is']!.isNotEmpty &&
        (ids['is'] as String).isrc.isNotEmpty;
  if (idKey == 'ucid' || idKey == 'uc')
    return song.isNotEmpty &&
        song['ucid'] != null &&
        song['ucid'].isNotEmpty &&
        (song['ucid'] as String).ucid.isNotEmpty &&
        ids['uc'] != null &&
        ids['uc']!.isNotEmpty &&
        (ids['uc'] as String).ucid.isNotEmpty;
  if (idKey == 'ytid' || idKey == 'yt')
    return song.isNotEmpty &&
        song['ytid'] != null &&
        song['ytid'].isNotEmpty &&
        (song['ytid'] as String).ytid.isNotEmpty &&
        ids['yt'] != null &&
        ids['yt']!.isNotEmpty &&
        (ids['yt'] as String).ytid.isNotEmpty;
  return false;
}

bool isSongTitleValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final title =
      song['mbTitle'] ?? song['title'] ?? song['ytTitle'] ?? song['song'];
  final isValid =
      song.isNotEmpty &&
      (title != null && title.isNotEmpty && title.toLowerCase() != 'unknown');
  return isValid;
}

bool isSongArtistValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final artist =
      ((song['mbArtist'] ?? song['artist'] ?? song['ytArtist']) is String
          ? song['artist']
          : null);
  final isValid =
      song.isNotEmpty &&
      (artist != null &&
          artist.isNotEmpty &&
          artist.toLowerCase() != 'unknown');
  return isValid;
}

Future<String> getSongYoutubeUrl(dynamic song, {bool waitForMb = false}) async {
  final context = NavigationManager().context;
  try {
    if (song == null) return '';
    if (!isMusicbrainzSongValid(song)) await queueSongInfoRequest(song);
    if (!isYouTubeSongValid(song)) {
      final ytSong =
          (song['id'] as String).ytid.isNotEmpty
              ? await _getYTSongDetails(song)
              : await _findYTSong(song);
      if (ytSong.isNotEmpty) {
        ytSong['id'] = parseEntityId(ytSong);
        ytSong['id'] = (ytSong['id'] as String).mergedAbsentId(song['id']);
        song.addAll(Map<String, dynamic>.from(ytSong));
      }
    }
    if (isYouTubeSongValid(song)) {
      unawaited(updateRecentlyPlayed(song));
      song['songUrl'] = await getYouTubeAudioUrl(song['ytid']);
      if (song['songUrl'] != null && song['songUrl'].isNotEmpty) {
        final uri = Uri.parse(song['songUrl']);
        final expires = int.tryParse(uri.queryParameters['expire'] ?? '0') ?? 0;
        song['songUrlExpire'] = expires;
        song['isError'] = false;
        song['source'] = 'youtube';
      }
    }
    if (song['songUrl'] == null || song['songUrl'].isEmpty) {
      logger.log(
        'Could not find YouTube stream for this song. ${song['artist']} - ${song['title']}',
        null,
        null,
      );
      song['error'] = context.l10n!.errorCouldNotFindAStream;
      song['isError'] = true;
      return '';
    }
    //check if url resolves
    if (await checkUrl(song['songUrl']) >= 400) {
      logger.log(
        'Song url could not be resolved. ${song['songUrl']}',
        null,
        null,
      );
      song['error'] = context.l10n!.urlError;
      song['isError'] = true;
      return '';
    }
    return song['songUrl'];
  } catch (e, stackTrace) {
    song['error'] = context.l10n!.urlError;
    song['isError'] = true;
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return '';
  }
}

Future<String?> getYouTubeAudioUrl(String songId) async {
  try {
    final qualitySetting = audioQualitySetting.value;
    final cacheKey = 'song_${songId}_${qualitySetting}_url';

    final cachedUrl = await getData(
      'cache',
      cacheKey,
      cachingDuration: _cacheDuration,
    );

    if (cachedUrl != null) {
      final uri = Uri.parse(cachedUrl);
      final expires = int.tryParse(uri.queryParameters['expire'] ?? '0') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      //add 5 second grace
      if (expires > (now + 5))
        if (await checkUrl(cachedUrl) < 400) return cachedUrl;
    }
    final manifest = await getSongManifest(songId);
    final audioQuality = selectAudioQuality(manifest.audioOnly.sortByBitrate());
    final audioUrl = audioQuality.url.toString();
    unawaited(addOrUpdateData('cache', cacheKey, audioUrl));
    return audioUrl;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

Future<Map<String, dynamic>> _getYTSongDetails(dynamic song) async {
  Map<String, dynamic> ytSong = {};
  try {
    if (song == null || song.isEmpty) return song;
    String songId = parseEntityId(song).ytid;
    final cached = getCachedSong(song);
    if (isSongValid(cached) && isYouTubeSongValid(cached)) {
      return cached!;
    } else if (songId.isNotEmpty) {
      songId = songId.ytid;
      final video = await yt.videos.get(songId);
      ytSong = returnYtSongLayout(video);
      ytSong['youtube'] = true;
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return ytSong;
}

Future<String?> getSongLyrics(String artist, String title) async {
  if (lastFetchedLyrics != '$artist - $title') {
    lyrics.value = null;
    var _lyrics = await LyricsManager().fetchLyrics(artist, title);
    if (_lyrics != null) {
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{2}'), '\n');
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{4}'), '\n\n');
      lyrics.value = _lyrics;
    } else {
      lyrics.value = 'not found';
    }

    lastFetchedLyrics = '$artist - $title';
    return _lyrics;
  }

  return lyrics.value;
}

bool isSongAlreadyOffline(songToCheck) => userOfflineSongs.any((song) {
  if (songToCheck is String) return checkEntityId(songToCheck, song);
  if (songToCheck is Map) return checkEntityId(songToCheck['id'], song);
  return false;
});

Future<void> makeSongOffline(dynamic song) async {
  try {
    await getUserOfflineSongs();
    if (isSongAlreadyOffline(song)) return;
    final _dir = await getApplicationSupportDirectory();
    final _audioDirPath =
        '${_dir.path}${Platform.pathSeparator}tracks${Platform.pathSeparator}';
    final _artworkDirPath =
        '${_dir.path}${Platform.pathSeparator}artworks${Platform.pathSeparator}';
    await Directory(_audioDirPath).create(recursive: true);
    await Directory(_artworkDirPath).create(recursive: true);

    final id = song['id'] = parseEntityId(song);
    if (!isYouTubeSongValid(song))
      song.addAll(Map<String, dynamic>.from(await _findYTSong(song)));
    final _audioFile =
        '$_audioDirPath$id.m4a'; // File('$_audioDirPath$id.m4a');
    final _artworkFile = File('$_artworkDirPath$id.jpg');

    try {
      final context = NavigationManager().context;
      await getSongUrl(song, skipDownload: true);
      if (song['songUrl'] == null)
        throw Exception('Could not find a download source.');
      final songUrl = song['songUrl'];
      final task = DownloadTask(
        taskId: id,
        url: songUrl,
        filename: '$id.m4a',
        directory: _audioDirPath,
        updates: Updates.statusAndProgress,
        displayName:
            '${song['mbTitle'] ?? song['title'] ?? song['ytTitle']} - ${song['mbArtist'] ?? song['artist'] ?? song['ytArtist']}',
        metaData: jsonEncode({
          'id': song['id'],
          'title': song['mbTitle'] ?? song['title'] ?? song['ytTitle'],
          'artist': song['mbArtist'] ?? song['artist'] ?? song['ytArtist'],
        }),
      );
      final result = await FileDownloader().enqueue(task);
      if (!result)
        showToast(
          '${context.l10n!.unableToDownload}: ${song['title']} - ${song['artist']}',
        );
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      throw Exception('Failed to download audio: $e');
    }

    try {
      final imagePath = await getValidImage(song);
      if (imagePath != null) {
        final artworkFile = await _downloadAndSaveArtworkFile(
          imagePath,
          _artworkFile.path,
        );

        if (artworkFile != null) {
          song['offlineArtworkPath'] = artworkFile.path;
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }

    song['offlineAudioPath'] = _audioFile;
    currentOfflineSongsLength.value = userOfflineSongs.length;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<List<dynamic>> getUserOfflineSongs() async {
  if (!(await checkOfflineFiles())) await getExistingOfflineSongs();
  return userOfflineSongs.map((e) {
    final cached = getCachedSong(e);
    if (isSongValid(cached)) return cached;
    return <String, dynamic>{'id': e, 'title': null, 'artist': null};
  }).toList();
}

String getUserOfflineSong(dynamic song) {
  final id = parseEntityId(song);
  final offline = userOfflineSongs.firstWhere(
    (e) => checkEntityId(e, id),
    orElse: () => '',
  );
  return offline;
}

Future<bool> checkOfflineFiles() async {
  final _dir = await getApplicationSupportDirectory();
  final _audioDirPath = '${_dir.path}${Platform.pathSeparator}tracks';
  final fileList =
      Directory(
        _audioDirPath,
      ).listSync().map((file) => basenameWithoutExtension(file.path)).toSet();
  final offlineSongsSet = userOfflineSongs.toSet();
  userOfflineSongs.removeWhere(
    (s) => !fileList.any((f) => checkEntityId(s, f)),
  );
  if (fileList.length != offlineSongsSet.length) return false;
  if (fileList.isEmpty && userOfflineSongs.isEmpty) return true;
  if ((userOfflineSongs.isEmpty && fileList.isNotEmpty) ||
      userOfflineSongs.length != fileList.length)
    return false;
  final exists = fileList.every(
    (f) => offlineSongsSet.any((s) => checkEntityId(f, s)),
  );
  return exists;
}

Future<void> getExistingOfflineSongs() async {
  final _dir = await getApplicationSupportDirectory();
  final _audioDirPath = '${_dir.path}${Platform.pathSeparator}tracks';
  await Directory(_audioDirPath).create(recursive: true);
  try {
    final fileList = Directory(_audioDirPath).listSync();
    if (Directory(_audioDirPath).existsSync())
      for (final file in fileList) {
        if (file is File && isAudio(file.path)) {
          final filename = basenameWithoutExtension(file.path);
          final ids = Uri.parse('?$filename').queryParameters;
          if ((ids['mb'] != null && ids['mb']!.isNotEmpty) ||
              (ids['yt'] != null && ids['yt']!.isNotEmpty) ||
              (ids['is'] != null && ids['is']!.isNotEmpty)) {
            userOfflineSongs.addOrUpdateWhere(checkEntityId, filename);
            currentOfflineSongsLength.value = userOfflineSongs.length;
          }
        }
      }
    currentOfflineSongsLength.value = userOfflineSongs.length;
    await addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<void> _matchFileToSongInfo(File file) async {
  try {
    final _dir = await getApplicationSupportDirectory();
    final _artworkDirPath = '${_dir.path}${Platform.pathSeparator}artworks';
    await Directory(_artworkDirPath).create(recursive: true);
    final filename = basenameWithoutExtension(file.path);
    final song = await queueSongInfoRequest(filename);
    final imageFiles = await _getRelatedFiles(_artworkDirPath, song);
    if (imageFiles.isNotEmpty) {
      song['offlineArtworkPath'] = imageFiles.first.path;
    }
    song['offlineAudioPath'] = file.path;
    userOfflineSongs.addOrUpdateWhere(checkEntityId, song['id']);
    await addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<String?> getOfflinePath(dynamic song) async {
  try {
    final _dir = await getApplicationSupportDirectory();
    final _audioDirPath = '${_dir.path}${Platform.pathSeparator}tracks';
    final _artworkDirPath = '${_dir.path}${Platform.pathSeparator}artworks';
    await Directory(_audioDirPath).create(recursive: true);
    await Directory(_artworkDirPath).create(recursive: true);
    song['id'] = parseEntityId(song);
    final audioFiles = await _getRelatedFiles(_audioDirPath, song);
    final artworkFiles = await _getRelatedFiles(_artworkDirPath, song);
    //TODO: add quality check
    if (audioFiles.isNotEmpty) song['offlineAudioPath'] = audioFiles.first.path;
    if (artworkFiles.isNotEmpty)
      song['offlineArtworkPath'] = artworkFiles.first.path;
    return song['offlineAudioPath'];
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return null;
}

Future<List<File>> _getRelatedFiles(String directory, dynamic entity) async {
  final files = <File>[];
  try {
    final ids = Uri.parse('?${entity['id']}').queryParameters;
    await for (final file in Directory(directory).list()) {
      for (final songId in ids.values) {
        if (file is File &&
            checkEntityId(songId, basenameWithoutExtension(file.path))) {
          files.add(file);
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return files;
}

Future<void> _deleteRelatedFiles(String directory, dynamic entity) async {
  try {
    final ids = Uri.parse('?${entity['id']}').queryParameters;
    await for (final file in Directory(directory).list()) {
      for (final songId in ids.values) {
        if (file is File &&
            basename(file.path).contains(songId) &&
            file.existsSync()) {
          await file.delete();
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<void> removeSongFromOffline(dynamic song) async {
  final context = NavigationManager().context;
  final _dir = await getApplicationSupportDirectory();
  final _audioDirPath = '${_dir.path}${Platform.pathSeparator}tracks';
  final _artworkDirPath = '${_dir.path}${Platform.pathSeparator}artworks';
  await Directory(_audioDirPath).create(recursive: true);
  await Directory(_artworkDirPath).create(recursive: true);
  song['id'] = parseEntityId(song);
  unawaited(_deleteRelatedFiles(_audioDirPath, song));
  unawaited(_deleteRelatedFiles(_artworkDirPath, song));
  song?.remove('offlineAudioPath');
  song?.remove('offlineArtworkPath');
  song?.remove('songUrl');
  song['isOffline'] = false;
  userOfflineSongs.removeWhere((s) => checkEntityId(song['id'], s));
  currentOfflineSongsLength.value = userOfflineSongs.length;
  await addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
  showToast(context.l10n!.songRemovedFromOffline);
}

Future<File?> _downloadAndSaveArtworkFile(Uri uri, String filePath) async {
  try {
    if (uri.isScheme('file') && doesFileExist(uri.toFilePath())) {
      final file = File(uri.toFilePath());
      await File(filePath).writeAsBytes(file.readAsBytesSync());
      return file;
    } else {
      final response = await http.get(uri);
      if (response.statusCode < 300) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        logger.log(
          'Failed to download file. Status code: ${response.statusCode}',
          null,
          null,
        );
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return null;
}

const recentlyPlayedSongsLimit = 50;

Future<void> updateRecentlyPlayed(dynamic song) async {
  try {
    if (userRecentlyPlayed.length == 1 &&
        checkSong(userRecentlyPlayed[0], song))
      return;
    if (userRecentlyPlayed.length >= recentlyPlayedSongsLimit) {
      userRecentlyPlayed.removeLast();
    }

    userRecentlyPlayed.removeWhere((s) => checkSong(s, song));
    currentRecentlyPlayedLength.value = userRecentlyPlayed.length;

    userRecentlyPlayed.insert(0, song);
    currentRecentlyPlayedLength.value = userRecentlyPlayed.length;
    await addOrUpdateData('user', 'recentlyPlayedSongs', userRecentlyPlayed);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

bool isSongLive(String? artist, String? album, String? title, String value) {
  // Convert to lowercase and remove title/artist
  final replaced =
      value
          .toLowerCase()
          .replaceAll(title?.toLowerCase() ?? '', '')
          .replaceAll(album?.toLowerCase() ?? '', '')
          .replaceAll(artist?.toLowerCase() ?? '', '')
          .sanitized;

  return liveRegex.hasMatch(replaced);
}

bool isSongDerivative(
  String? artist,
  String? album,
  String? title,
  String value,
) {
  final replaced =
      value
          .toLowerCase()
          .replaceAll(title?.toLowerCase() ?? '', '')
          .replaceAll(album?.toLowerCase() ?? '', '')
          .replaceAll(artist?.toLowerCase() ?? '', '')
          .sanitized;

  return derivativeRegex.hasMatch(replaced);
}

bool checkSong(dynamic songA, dynamic songB) {
  if (songA is Map) songA['id'] = parseEntityId(songA);
  if (songB is Map) songB['id'] = parseEntityId(songB);
  if (songA is String && songB is String)
    return (songA.isNotEmpty && songB.isNotEmpty) &&
        checkEntityId(songA, songB);
  if (songA is String && songB is Map)
    return (songA.isNotEmpty &&
            songB['id'] != null &&
            songB['id'].isNotEmpty) &&
        (checkEntityId(songA, songB['id']) ||
            checkEntityId(songB['id'], songA));
  if (songB is String && songA is Map)
    return (songB.isNotEmpty &&
            songA['id'] != null &&
            songA['id'].isNotEmpty) &&
        (checkEntityId(songB, songA['id']) ||
            checkEntityId(songA['id'], songB));
  if (songA['id'] == null ||
      songB['id'] == null ||
      songA['id']?.isEmpty ||
      songB['id']?.isEmpty)
    return checkTitleAndArtist(songA, songB);
  final idCheck = checkEntityId(songA['id'], songB['id']);
  final hashA = getSongHashCode(songA);
  final hashB = getSongHashCode(songB);
  final hashCheck =
      hashA != null &&
      hashB != null &&
      (getSongHashCode(songA) == getSongHashCode(songB));
  return idCheck || hashCheck;
}

int? getSongHashCode(dynamic song) {
  if (!(song is Map)) return null;
  if (!isSongTitleValid(song) || !isSongArtistValid(song)) return null;
  final title =
      (song['mbTitle'] ?? song['title'] ?? song['ytTitle'] ?? song['song'])
          as String?;
  final artist =
      (song['mbArtist'] ?? song['artist'] ?? song['ytArtist']) as String?;
  return title!.cleansed.toLowerCase().hashCode ^
      artist!.cleansed.toLowerCase().hashCode;
}

bool checkTitleAndArtist(dynamic songA, dynamic songB) {
  songA['artist'] = songA['artist'] ?? combineArtists(songA) ?? '';
  songB['artist'] = songB['artist'] ?? combineArtists(songB) ?? '';
  if (!isSongTitleValid(songA) ||
      !isSongTitleValid(songB) ||
      !isSongArtistValid(songA) ||
      !isSongArtistValid(songB))
    return false;
  if (songA['artist'].toLowerCase() == songB['artist'].toLowerCase() &&
      songB['title'].toLowerCase() == songA['title'].toLowerCase())
    return true;
  final artistListA =
      Set<String>()
        ..addAll(
          ((songA['artist-credit'] ?? []) as List).map(
            (e) =>
                (e['name'] ??
                    (e['artist'] is String ? e['artist'] : null) ??
                    e['musicbrainzName'] ??
                    e['discogsName'] ??
                    ''),
          ),
        )
        ..addAll(splitArtists(songA['artist']))
        ..removeWhere((e) => e.isEmpty);
  final artistListB =
      Set<String>()
        ..addAll(
          ((songB['artist-credit'] ?? []) as List).map(
            (e) =>
                (e['name'] ??
                    (e['artist'] is String ? e['artist'] : null) ??
                    e['musicbrainzName'] ??
                    e['discogsName'] ??
                    ''),
          ),
        )
        ..addAll(splitArtists(songB['artist']))
        ..removeWhere((e) => e.isEmpty);
  if (artistListA.containsAll(artistListB) &&
      songB['title'].toLowerCase() == songA['title'].toLowerCase())
    return true;
  final artistInATitleReplaced =
      ((songB['artist-credit'] ?? []) as List)
          .map(
            (e) =>
                e['name'] ?? (e['artist'] is String ? e['artist'] : null) ?? '',
          )
          .fold(
            ((songA['title'] ?? '') as String)
                .replaceFirstSubsequence(songA['channelName'] ?? '')
                .collapsed,
            (v, c) {
              final ss = v.findSubsequence(c);
              if (ss.isNotEmpty && weightedRatio(ss, c) >= 75) {
                v = v.replaceAll(ss, '').collapsed;
                artistListA.add(c);
              }
              return v;
            },
          )
          .collapsed;
  final artistInBTitleReplaced =
      ((songA['artist-credit'] ?? []) as List)
          .map(
            (e) =>
                e['name'] ?? (e['artist'] is String ? e['artist'] : null) ?? '',
          )
          .fold(
            ((songB['title'] ?? '') as String)
                .replaceFirstSubsequence(songB['channelName'] ?? '')
                .collapsed,
            (v, c) {
              final ss = v.findSubsequence(c);
              if (ss.isNotEmpty && weightedRatio(ss, c) >= 75) {
                v = v.replaceAll(ss, '').collapsed;
                artistListB.add(c);
              }
              return v;
            },
          )
          .collapsed;
  final aTitle = removeDuplicates(
    sanitizeSongTitle(
      artistInATitleReplaced.isNotEmpty
          ? artistInATitleReplaced
          : (songA['title'] ?? ''),
    ).toLowerCase(),
  );
  final aArtist = removeDuplicates(
    [(songA['artist'] ?? ''), ...artistListA].join(', ').toLowerCase(),
  );
  final bTitle = removeDuplicates(
    sanitizeSongTitle(
      artistInBTitleReplaced.isNotEmpty
          ? artistInBTitleReplaced
          : (songB['title'] ?? ''),
    ).toLowerCase(),
  );
  final bArtist = removeDuplicates(
    [(songB['artist'] ?? ''), ...artistListB].join(', ').toLowerCase(),
  );
  final artistCheck =
      (aArtist.length >= bArtist.length
          ? aArtist.sanitized.contains(bArtist.sanitized)
          : bArtist.sanitized.contains(aArtist.sanitized)) ||
      artistListA.any(
        (a) => artistListB.any(
          (b) =>
              b.sanitized.contains(a.sanitized) ||
              a.sanitized.contains(b.sanitized) ||
              b.sanitized
                  .replaceAll(r'\s', '')
                  .contains(a.sanitized.replaceAll(r'\s', '')) ||
              a.sanitized
                  .replaceAll(r'\s', '')
                  .contains(b.sanitized.replaceAll(r'\s', '')),
        ),
      ) ||
      artistListB.any(
        (b) => artistListA.any(
          (a) =>
              b.sanitized.contains(a.sanitized) ||
              a.sanitized.contains(b.sanitized) ||
              b.sanitized
                  .replaceAll(r'\s', '')
                  .contains(a.sanitized.replaceAll(r'\s', '')) ||
              a.sanitized
                  .replaceAll(r'\s', '')
                  .contains(b.sanitized.replaceAll(r'\s', '')),
        ),
      );
  final titleCheck =
      ratio(
        aTitle.replaceAllSubsequence(aArtist),
        bTitle.replaceAllSubsequence(bArtist),
      ) >=
      75;
  final aExtras =
      boundExtrasRegex
          .firstMatch(songA['title'] ?? '')?[0]
          ?.sanitized
          .toLowerCase();
  final bExtras =
      boundExtrasRegex
          .firstMatch(songB['title'] ?? '')?[0]
          ?.sanitized
          .toLowerCase();
  final extraCheck =
      (aExtras == null && bExtras == null) ||
      (aExtras != null &&
          bExtras != null &&
          weightedRatio(aExtras, bExtras) >= 90);
  final titleArtistRatio = weightedRatio(
    removeDuplicates('$aTitle $aArtist'),
    removeDuplicates('$bTitle $bArtist'),
  );
  final titleRatio = weightedRatio(
    removeDuplicates(bTitle),
    removeDuplicates(aTitle),
  );
  final artistRatio = weightedRatio(
    removeDuplicates(bArtist),
    removeDuplicates(aArtist),
  );
  final ratioCheck =
      aTitle != aArtist && bTitle != bArtist
          ? titleRatio >= 90 && artistRatio >= 90
          : titleArtistRatio >= 90;
  return ((titleCheck && artistCheck) || ratioCheck) && extraCheck;
}
