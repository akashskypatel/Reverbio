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
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/services/lyrics_manager.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/file_scanner.dart';
import 'package:reverbio/utilities/file_tagger.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/media_utils.dart';
import 'package:reverbio/utilities/notifiable_future.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final List globalSongs = [];
int activeSongId = 0;

final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;

final Set<NotifiableFuture<Map<String, dynamic>>> getSongInfoQueue = {};

const Duration _cacheDuration = Duration(hours: 3);

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
      globalSongs.addAll(
        (await getSongsFromPlaylist(playlistId)).map((e) {
          parseEntityId(e);
          return Map<String, dynamic>.from(e);
        }),
      );
      if (userCustomPlaylists.isNotEmpty) {
        for (final userPlaylist in userCustomPlaylists) {
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
      userLikedSongsList.addOrUpdate(song, checkSong);
      song['song'] = songTitle(song);
      await PM.triggerHook(song, 'onEntityLiked');
    } else {
      userLikedSongsList.removeWhere((s) => checkSong(s, song));
    }
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
}

bool isSongAlreadyLiked(songToCheck) =>
    songToCheck is Map &&
    userLikedSongsList.any((song) => checkSong(song, songToCheck));

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

Future<Map<String, dynamic>> findYTSong(dynamic song, {String? newYtid}) async {
  Map<String, dynamic> ytSong = {};
  try {
    if (newYtid != null && newYtid.isNotEmpty) {
      final newId = (song['id'] as String).mergedReplacedId(
        parseEntityId(newYtid),
      );
      song['ytid'] = newYtid;
      song['id'] = newId;
    }
    final ytid = ((song['ytid'] ?? song['id']) as String).ytid;
    if (ytid.isNotEmpty) {
      ytSong = await _getYTSongDetails(song);
    } else {
      final ytSongs = await _findYTSong(song);
      if (ytSongs.isNotEmpty) {
        ytSong = await _getYTSongDetails(ytSongs.first);
        song['ytSongs'] = ytSongs;
      }
    }
    if (ytSong.isNotEmpty) {
      ytSong['id'] = parseEntityId(ytSong);
      ytSong['id'] = (ytSong['id'] as String).mergedAbsentId(song['id']);
      if (song['title'] != null) ytSong.remove('title');
      if (song['artist'] != null) ytSong.remove('artist');
      song.addAll(ytSong);
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  addSongToCache(song as Map<String, dynamic>);
  if (getSongInfoQueue.isEmpty) cachedSongsList.writeToCache();
  return song;
}

Future<List<dynamic>> _findYTSong(dynamic song) async {
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
      final lcSongName = songTitle(song);
      final lcArtist = songArtist(song);
      if (lcSongName.collapsed.isEmpty && lcArtist.collapsed.isEmpty)
        throw Exception('Cannot find YouTubeSong. Invalid song: $song');
      final qry = '$lcArtist $lcSongName';
      final results = await getSongsList(qry);
      results.sort((a, b) => b['views'].compareTo(a['views']));
      final result =
          results.where((value) {
              return checkTitleAndArtist(value, song) &&
                  ((song['isDerivative'] ?? false) ==
                      (value['isDerivative'] ?? false)) &&
                  ((song['isLive'] ?? false) == (value['isLive'] ?? false)) &&
                  ((song['duration'] ?? 0) == 0 ||
                      (value['duration'] ?? 0) == 0 ||
                      withinPercent(
                        (song['duration'] as int).toDouble(),
                        (value['duration'] as int).toDouble(),
                        90,
                      ));
            }).toList()
            ..sort((a, b) => b['views'].compareTo(a['views']));
      return result;
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return [];
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
    cachedSongsList.addOrUpdate(song, checkSong);
  }
}

Map<String, dynamic> minimizeSongData(dynamic song) {
  song['audioTags']?.remove('pictures');
  return {
    'id': parseEntityId(song),
    'primary-type': song['primary-type'] ?? 'song',
    'title': songTitle(song),
    'artist': songArtist(song),
    'artist-credit': song['artist-credit'],
    'devicePath': song['devicePath'],
    'songUrl': song['songUrl'],
    'offlineAudioPath': song['offlineAudioPath'],
    'duration': song['duration'],
    'cachedAt': DateTime.now().toString(),
    'audioTags': song['audioTags'],
    'image':
        song['validImage'] ??
        song['highResImage'] ??
        song['lowResImage'] ??
        song['image'],
  };
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
      final rcdResult = await mb.recordings.get(
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
      );
      if (rcdResult['error'] != null) {
        return song;
      }
      recording.addAll(Map<String, dynamic>.from(rcdResult));
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
      } else {
        recording = song;
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
        if (!isSongValid(songInfo)) {
          songInfo = Map<String, dynamic>.from(await getAlbumInfo(song));
        }
        if (isSongValid(songInfo)) {
          songInfo['id'] = parseEntityId(songInfo).mergedReplacedId(song['id']);
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
            combineArtists(song) ?? songArtist(song).nullIfEmpty ?? '';
        final String iTitle = sanitizeSongTitle(songTitle(song));
        if (!(iArtist.isUnknown && iTitle.isUnknown)) {
          final artists =
              splitArtists(
                iArtist,
              ).where((artist) => !artist.toLowerCase().isUnknown).toList();
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
              artists.isNotEmpty
                  ? 'AND (artistname:(${artists.map((a) => splitLatinNonLatin(a.toLowerCase()).map((e) => '"${e.trim()}"').join('OR')).join('OR')}))'
                  : '';
          final sTitle = removeDuplicates(
            splitLatinNonLatin(
              sanitizeSongTitle(iTitle).cleansed.toLowerCase(),
            ).map((e) => e.trim()).join('|'),
          ).replaceAll(' ', '|');
          final sArtist =
              removeDuplicates(
                sanitizeSongTitle(iArtist).cleansed.toLowerCase(),
              ).replaceAll(' ', '|').replaceAll(sTitle, '').collapsed;
          final phrase =
              sArtist.toLowerCase().isUnknown ? sTitle : '$sTitle|$sArtist';
          final qry =
              '((recording:$sTitle) $artistQry) OR (recording:($phrase) OR artistname:($phrase))';
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
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  song['id'] = parseEntityId(song);
  song = Map<String, dynamic>.from(song);
  return song;
}

Future<dynamic> getSongUrl(dynamic song, {bool skipDownload = false}) async {
  song['isError'] = false;
  song?.remove('error');
  final offlinePath =
      !(await FileDownloader().allTaskIds()).contains(song['id'])
          ? await getOfflinePath(song)
          : null;
  if (offlinePath != null) {
    song['songUrl'] = offlinePath;
  }
  if (offlinePath == null || offlinePath.isEmpty) {
    final _songUrl = await PM.getSongUrl(song, getSongYoutubeUrl);
    song['songUrl'] = _songUrl;
  }

  if (((song['autoCacheOffline'] ?? false) || autoCacheOffline.value) &&
      (song['songUrl'] != null && offlinePath == null) &&
      !skipDownload &&
      !(await FileDownloader().allTaskIds()).contains(song['id']))
    await makeSongOffline(song);
  return song;
}

NotifiableFuture<Map<String, dynamic>> queueSongInfoRequest(dynamic song) {
  if (song == null) return NotifiableFuture.fromValue(song);
  if (song is String) {
    song = <String, dynamic>{'id': song};
    song['id'] = parseEntityId(song);
  }
  try {
    final existing = getSongInfoQueue.where((e) => checkSong(e.data, song));
    if (existing.isEmpty) {
      final futureTracker = NotifiableFuture<Map<String, dynamic>>.withFuture(
        song,
        getSongInfo(song),
      );
      getSongInfoQueue.add(futureTracker);
      return futureTracker;
    } else {
      return existing.first;
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return NotifiableFuture.fromValue(song);
  }
}

SongBar initializeSongBar(
  Map<String, dynamic> song,
  BuildContext context, {
  BorderRadius? borderRadius,
}) {
  return SongBar(
    song,
    context,
    borderRadius: borderRadius ?? BorderRadius.zero,
    showMusicDuration: true,
  );
}

NotifiableFuture<Map<String, dynamic>> initializeSongBarFuture(dynamic song) {
  try {
    parseEntityId(song);
    if (!isSongValid(song)) {
      return queueSongInfoRequest(song);
    } else {
      final futureTracker = NotifiableFuture<Map<String, dynamic>>(song)
        ..runFuture(Future.value(song));
      return futureTracker;
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    final futureTracker = NotifiableFuture<Map<String, dynamic>>(song)
      ..runFuture(Future.value(song));
    return futureTracker;
  }
}

Future<Map<String, dynamic>> getSongInfo(dynamic song) async {
  late final String offlineId;
  await cachedSongsList.ensureInitialized();
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
  song['title'] = songTitle(song);
  song['artist'] = songArtist(song);
  song['id'] = parseEntityId(song);
  song = Map<String, dynamic>.from(song);
  addSongToCache(song as Map<String, dynamic>);
  await PM.triggerHook(song, 'onGetSongInfo');
  getSongInfoQueue.removeWhere((e) => checkSong(e.data, song));
  if (getSongInfoQueue.isEmpty) {
    cachedSongsList.writeToCache();
  }
  return song;
}

String songTitle(dynamic song) {
  if (song == null) return '';
  if (!(song is Map)) return '';
  return song['mbTitle'] ??
      song['title'] ??
      song['ytTitle'] ??
      song['song'] ??
      '';
}

String songArtist(dynamic song) {
  if (song == null) return '';
  if (!(song is Map)) return '';
  return combineArtists(song) ??
      song['mbArtist'] ??
      song['artist'] ??
      song['ytArtist'] ??
      '';
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
  if (idKey == 'flnm' || idKey == 'fn')
    return song.isNotEmpty &&
        song['flnm'] != null &&
        song['flnm'].isNotEmpty &&
        (song['flnm'] as String).flnm.isNotEmpty &&
        ids['fn'] != null &&
        ids['fn']!.isNotEmpty &&
        (ids['fn'] as String).flnm.isNotEmpty;
  return false;
}

bool isSongTitleValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final title = songTitle(song);
  final isValid =
      song.isNotEmpty && (title.isNotEmpty && !title.toLowerCase().isUnknown);
  return isValid;
}

bool isSongArtistValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final artist = songArtist(song).nullIfEmpty;
  final isValid =
      song.isNotEmpty &&
      (artist != null && artist.isNotEmpty && !artist.toLowerCase().isUnknown);
  return isValid;
}

Future<String> getSongYoutubeUrl(dynamic song, {bool waitForMb = false}) async {
  final context = NavigationManager().context;
  String songUrl = '';
  try {
    if (song == null) return '';
    if (!isYouTubeSongValid(song)) await findYTSong(song);
    if (isYouTubeSongValid(song)) {
      unawaited(updateRecentlyPlayed(song));
      final songId = song['ytid'];
      final qualitySetting = audioQualitySetting.value;
      final cacheKey = 'song_${songId}_${qualitySetting}_url';

      final cachedUrl = await HiveService.getData('cache', cacheKey);

      if (cachedUrl != null) {
        final uri = Uri.parse(cachedUrl);
        final expires = int.tryParse(uri.queryParameters['expire'] ?? '0') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        //add 5 second grace
        if (expires > (now + 5))
          if (await checkUrl(cachedUrl) < 400) return cachedUrl;
      } else {
        songUrl =
            song['songUrl'] = await px.getYouTubeAudioUrl(
              song['ytid'],
              streamRequestTimeout.value,
              audioQualitySetting.value,
              useProxies.value,
            );
        if (songUrl.isNotEmpty) {
          await HiveService.addOrUpdateData<String>('cache', cacheKey, songUrl);
          final uri = Uri.parse(songUrl);
          final expires =
              int.tryParse(uri.queryParameters['expire'] ?? '0') ?? 0;
          song['songUrlExpire'] = expires;
          song['isError'] = false;
          song['source'] = 'youtube';
        }
      }
      if (songUrl.isEmpty) {
        logger.log(
          'Could not find YouTube stream for this song. ${song['artist']} - ${song['title']}',
          null,
          null,
        );
        songUrl = song['songUrl'] = '';
        song['error'] = context.l10n!.errorCouldNotFindAStream;
        song['isError'] = true;
      }
      //check if url resolves
      if (await checkUrl(songUrl) >= 400) {
        logger.log('Song url could not be resolved. $songUrl', null, null);
        songUrl = song['songUrl'] = '';
        song['error'] = context.l10n!.urlError;
        song['isError'] = true;
      }
    }
  } catch (e, stackTrace) {
    song['error'] = context.l10n!.urlError;
    song['isError'] = true;
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return songUrl;
}

Future<Map<String, dynamic>> _getYTSongDetails(dynamic song) async {
  Map<String, dynamic> ytSong = {};
  try {
    if (song == null || song.isEmpty) return song;
    String songId = parseEntityId(song).ytid;
    final cached = cachedSongsList.firstWhere(
      (e) => checkEntityId(songId, e['id']),
      orElse: () => <String, dynamic>{},
    );
    if (isSongValid(cached) && isYouTubeSongValid(cached)) {
      cached['youtube'] = true;
      return cached;
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

Future<String?> getSongLyrics(dynamic song) async {
  final artist = songArtist(song);
  final title = songTitle(song);
  if (lastFetchedLyrics != '$artist - $title' ||
      lyrics.value == null ||
      lyrics.value == L10n.current.lyricsNotAvailable) {
    lyrics.value = null;
    var _lyrics = await LyricsManager().fetchLyrics(song);
    if (_lyrics != null) {
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{2}'), '\n');
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{4}'), '\n\n');
      lyrics.value = _lyrics;
    } else {
      lyrics.value = L10n.current.lyricsNotAvailable;
    }

    lastFetchedLyrics = '$artist - $title';
    return _lyrics;
  }

  return lyrics.value;
}

bool isSongAlreadyOffline(songToCheck) =>
    isSongAppOfflineOnly(songToCheck) || isSongInDeviceLibrary(songToCheck);

bool isSongAppOfflineOnly(songToCheck) => userOfflineSongs.any((song) {
  if (songToCheck is String) return checkEntityId(songToCheck, song);
  if (songToCheck is Map) return checkEntityId(songToCheck['id'], song);
  return false;
});

bool isSongInDeviceLibrary(songToCheck) => userDeviceSongs.any((song) {
  if (songToCheck is String) return checkEntityId(songToCheck, song);
  if (songToCheck is Map &&
      song['id'] != null &&
      songToCheck['id'] != null &&
      song['id'].isNotEmpty &&
      songToCheck['id'].isNotEmpty)
    return checkEntityId(songToCheck, song);
  if (songToCheck is Map) return checkTitleAndArtist(songToCheck, song);
  return false;
});

Future<int> moveAllSongToDeviceLibrary() async {
  int count = 0;
  final destination =
      Platform.isWindows ? await FilePicker.platform.getDirectoryPath() : null;
  try {
    if (Platform.isWindows && (destination == null || destination.isEmpty))
      throw PathException('Invalid destination directory selected');
    await getUserOfflineSongs();
    final moved = [];
    for (final song in userOfflineSongs) {
      try {
        final _song = await queueSongInfoRequest(song).completerFuture;
        count += await moveSongToDeviceLibrary(_song, destination: destination);
        moved.add(song);
      } catch (_) {}
    }
    for (final song in moved)
      userOfflineSongs.removeWhere((e) => checkEntityId(song, e));
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return count;
}

Future<int> moveSongToDeviceLibrary(dynamic song, {String? destination}) async {
  int count = 0;
  try {
    if (!(await checkAllPermissions())) return count;
    if (song is String) song = await queueSongInfoRequest(song).completerFuture;
    if (isSongAppOfflineOnly(song) && !isSongInDeviceLibrary(song)) {
      final _dir = Directory(offlineDirectory.value!);
      final _audioDirPath = join(_dir.path, 'tracks');
      final files = await _getRelatedFiles(_audioDirPath, song);
      String? dest = Platform.isWindows ? destination : null;
      for (final file in files) {
        if (songArtist(song).isNotEmpty && songTitle(song).isNotEmpty) {
          final newName =
              '${songArtist(song)} - ${songTitle(song)}${extension(file.path)}'
                  .replaceAll(RegExp('[\\/:*?"<>|]'), '');
          String? copyPath;
          if (Platform.isAndroid) {
            final copy = file.copySync(
              file.path.replaceAll(basename(file.path), newName),
            );
            copyPath =
                dest = await MediaUtils.instance.copyMediaFileToRelative(
                  copy.path,
                  newName,
                );
            copy.deleteSync();
          } else if (dest != null && dest.isNotEmpty) {
            copyPath = join(dest, newName);
            file.copySync(copyPath);
          }
          if (dest != null && dest.isNotEmpty) {
            song['devicePath'] = copyPath;
            file.deleteSync();
            count++;
          }
        }
      }
      if (count > 0) {
        userDeviceSongs.addOrUpdate(song, checkSong);
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return count;
}

Future<void> tagAllOfflineFiles() async {
  final offlineSongs = await getUserOfflineSongs();
  final ValueNotifier<int> progress = ValueNotifier(0);
  showToast(
    'Tagging offline songs with metadata...',
    id: 'tagOffline',
    data: progress,
  );
  final fileTagger = FileTagger();
  for (int i = 0; i < offlineSongs.length; i++) {
    final song =
        await queueSongInfoRequest(copyMap(offlineSongs[i])).completerFuture;
    await fileTagger.tagOfflineFile(song, id: parseEntityId(song));
    final num = (i + 1) / offlineSongs.length;
    progress.value = (num * 100).toInt();
  }
  showToast('Finished tagging offline songs with metadata.', id: 'tagOffline');
}

Future<void> makeSongOffline(dynamic song) async {
  try {
    await getUserOfflineSongs();
    if (isSongAlreadyOffline(song)) return;
    final _dir = Directory(offlineDirectory.value!);
    final _audioDirPath = join(_dir.path, 'tracks');
    final _artworkDirPath = join(_dir.path, 'artworks');
    await Directory(_audioDirPath).create(recursive: true);
    await Directory(_artworkDirPath).create(recursive: true);

    if (!isMusicbrainzSongValid(song)) {
      final songInfo = (await queueSongInfoRequest(song).completerFuture) ?? {};
      song.addAll(Map<String, dynamic>.from(songInfo));
    }
    if (!isYouTubeSongValid(song)) await findYTSong(song);
    final id = song['id'] = parseEntityId(song);
    final _audioFile = join(_audioDirPath, id);
    final _artworkFile = File(join(_artworkDirPath, id));

    try {
      final context = NavigationManager().context;
      song = await getSongUrl(song, skipDownload: true);
      if (song['songUrl'] == null)
        throw Exception('Could not find a download source.');
      final songUrl = song['songUrl'];
      final mime = await getMimeTypeFromUrl(songUrl);
      final ext = getExtensionFromMime(mime);
      final task = DownloadTask(
        taskId: id,
        url: songUrl,
        filename: '$id$ext',
        directory: 'tracks',
        baseDirectory: BaseDirectory.applicationSupport,
        updates: Updates.statusAndProgress,
        displayName: '${songTitle(song)} - ${songArtist(song)}',
        metaData: jsonEncode({
          'id': song['id'],
          'title': songTitle(song),
          'artist': songArtist(song),
        }),
      );
      final result = await FileDownloader().enqueue(task);
      if (!result)
        showToast(
          '${context.l10n!.unableToDownload}: ${songTitle(song)} - ${songArtist(song)}',
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
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<List<dynamic>> getUserOfflineSongs() async {
  if (!(await checkOfflineFiles())) {
    await getExistingOfflineSongs();
  }
  final offline =
      userOfflineSongs.map((e) {
        final cached = getCachedSong(e);
        if (isSongValid(cached)) return cached;
        return <String, dynamic>{'id': e, 'title': null, 'artist': null};
      }).toList();
  return offline;
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
  final _dir = Directory(offlineDirectory.value!);
  final _audioDirPath = join(_dir.path, 'tracks');
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

Future<void> getUserDeviceSongs() async {
  try {
    if (await checkAllPermissions()) {
      final fileScanner = FileScanner(
        directories: additionalDirectories.toList(),
      );
      final _userDeviceSongs = await fileScanner.getUserDeviceSongs(
        additionalDirectories,
      );
      for (dynamic _song in _userDeviceSongs) {
        _song = await queueSongInfoRequest(_song).completerFuture;
      }
      userDeviceSongs
        ..removeWhere(
          (e) =>
              e['id'] == null ||
              e['id'].isEmpty ||
              !_userDeviceSongs.any(
                (s) =>
                    checkSong(e, s) ||
                    e['devicePath'] == s['devicePath'] ||
                    e['fileName'] == s['fileName'],
              ),
        )
        ..addOrUpdateAllWhere(checkSong, _userDeviceSongs);
      unawaited(_getUserDeviceSongMetadata());
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<void> _getUserDeviceSongMetadata() async {
  final fileTagger = FileTagger();
  for (dynamic song in userDeviceSongs) {
    if (!(songTitle(song).isUnknown && songArtist(song).isUnknown)) {
      await queueSongInfoRequest(song).completerFuture?.then((value) {
        song = Map<String, dynamic>.from(song);
        if (value != null) song.addAll(value);
        fileTagger.tagOfflineFile(
          song,
          id: song['id'],
          filePath: song['devicePath'],
          rename: false,
        );
      });
    }
  }
  userDeviceSongs.writeToCache();
}

Future<void> getExistingOfflineSongs() async {
  final _dir = Directory(offlineDirectory.value!);
  final _audioDirPath = join(_dir.path, 'tracks');
  final List<String> _userOfflineSongs = [];
  await Directory(_audioDirPath).create(recursive: true);
  try {
    final fileList = Directory(_audioDirPath).listSync();
    for (final file in fileList) {
      try {
        final filename = basenameWithoutExtension(file.path);
        final mime = getMimeTypeFromFile(file.path);
        final ext = getExtensionFromMime(mime);
        final newPath = ensureCorrectExtension(file.path, extension: ext);
        File(file.path).renameSync(newPath);
        if (isAudio(newPath)) {
          final ids = filename.toIds;
          if (ids.isNotEmpty)
            _userOfflineSongs.addOrUpdateWhere(checkEntityId, filename);
        } else {
          final fileTagger = FileTagger();
          final song =
              await queueSongInfoRequest({'id': filename}).completerFuture;
          await fileTagger.tagOfflineFile(song, id: parseEntityId(song));
        }
      } catch (_) {}
    }
    userOfflineSongs.removeWhere((e) => !_userOfflineSongs.contains(e));
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  userOfflineSongs.writeToCache();
}

Future<void> _matchFileToSongInfo(File file) async {
  try {
    final _dir = Directory(offlineDirectory.value!);
    final _artworkDirPath = join(_dir.path, 'artworks');
    await Directory(_artworkDirPath).create(recursive: true);
    final filename = basenameWithoutExtension(file.path);
    final song = await queueSongInfoRequest(filename).completerFuture;
    final imageFiles = await _getRelatedFiles(_artworkDirPath, song);
    if (imageFiles.isNotEmpty) {
      song?['offlineArtworkPath'] = imageFiles.first.path;
    }
    song?['offlineAudioPath'] = file.path;
    userOfflineSongs.addOrUpdate(song?['id'], checkEntityId);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<String?> getOfflinePath(dynamic song) async {
  try {
    String? offlinePath =
        (song['devicePath'] ?? song['offlineAudioPath']) as String?;
    if (offlinePath != null) {
      if (offlinePath.startsWith('content') && Platform.isAndroid)
        offlinePath = await MediaUtils.instance.uriToPath(offlinePath);
      if (offlinePath != null &&
          isFilePath(offlinePath) &&
          doesFileExist(offlinePath))
        return offlinePath;
    }
    final _dir = Directory(offlineDirectory.value!);
    final _audioDirPath = join(_dir.path, 'tracks');
    final _artworkDirPath = join(_dir.path, 'artworks');
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
  final files = <File>{};
  try {
    final ids = parseEntityId(entity).toIds;
    await for (final file in Directory(directory).list()) {
      for (final songId in ids.values) {
        if (file is File &&
            checkEntityId(songId, basenameWithoutExtension(file.path))) {
          files.add(file);
        }
      }
    }
    for (final file in userDeviceSongs) {
      if (checkSong(file, entity) &&
          file['devicePath'] != null &&
          file['devicePath'].isNotEmpty) {
        if (File(file['devicePath']).existsSync() &&
            !files.any((e) => checkSong(entity, e)))
          files.add(File(file['devicePath']));
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return files.toList();
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
  final _dir = Directory(offlineDirectory.value!);
  final _audioDirPath = join(_dir.path, 'tracks');
  final _artworkDirPath = join(_dir.path, 'artworks');
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
  showToast(context.l10n!.songRemovedFromOffline);
}

Future<File?> _downloadAndSaveArtworkFile(Uri uri, String filePath) async {
  try {
    if (uri.isScheme('file') && doesFileExist(uri.toFilePath())) {
      final file = File(uri.toFilePath());
      // For local files, detect MIME type from content
      final mimeType = getMimeTypeFromFile(uri.toFilePath());
      final extension = getExtensionFromMime(mimeType);
      final newFilePath = ensureCorrectExtension(
        filePath,
        extension: extension,
      );
      await File(newFilePath).writeAsBytes(file.readAsBytesSync());
      return File(newFilePath);
    } else {
      final response = await http.get(uri);
      if (response.statusCode < 300) {
        // Get MIME type from headers or detect from content
        String? mimeType = response.headers['content-type']?.split(';').first;

        // If no MIME type in headers, detect from content
        if (mimeType == null ||
            mimeType.isEmpty ||
            mimeType == 'application/octet-stream') {
          mimeType = lookupMimeType('', headerBytes: response.bodyBytes);
        }

        // Get file extension from MIME type
        final extension = getExtensionFromMime(mimeType);
        final newFilePath = ensureCorrectExtension(
          filePath,
          extension: extension,
        );

        final file = File(newFilePath);
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
    userRecentlyPlayed
      ..removeWhere((s) => checkSong(s, song))
      ..insert(0, song);
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
      songA['id'].isEmpty ||
      songB['id'].isEmpty)
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
  final title = songTitle(song).nullIfEmpty;
  final artist = songArtist(song).nullIfEmpty;
  return title!.cleansed.toLowerCase().hashCode ^
      artist!.cleansed.toLowerCase().hashCode;
}

bool checkTitleAndArtist(dynamic songA, dynamic songB) {
  String artistA =
      songA['artist'] = songA['artist'] ?? combineArtists(songA) ?? '';
  artistA = artistA.isUnknown ? '' : artistA;
  final titleA = songTitle(songA).isUnknown ? '' : songTitle(songA);
  String artistB =
      songB['artist'] = songB['artist'] ?? combineArtists(songB) ?? '';
  artistB = artistB.isUnknown ? '' : artistA;
  final titleB = songTitle(songB).isUnknown ? '' : songTitle(songB);
  if (titleA.isNotEmpty &&
      titleB.isNotEmpty &&
      ((artistA.isEmpty && artistB.isEmpty) ||
          artistA.toLowerCase() == artistB.toLowerCase()) &&
      titleB.toLowerCase() == titleA.toLowerCase())
    return true;
  if (!isSongTitleValid(songA) ||
      !isSongTitleValid(songB) ||
      !isSongArtistValid(songA) ||
      !isSongArtistValid(songB))
    return false;
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
        ..addAll(splitArtists(artistA))
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
        ..addAll(splitArtists(artistB))
        ..removeWhere((e) => e.isEmpty);
  if (artistListA.containsAll(artistListB) &&
      titleB.toLowerCase() == titleA.toLowerCase())
    return true;
  final artistInATitleReplaced =
      ((songB['artist-credit'] ?? []) as List)
          .map(
            (e) =>
                e['name'] ?? (e['artist'] is String ? e['artist'] : null) ?? '',
          )
          .fold(
            titleA
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
            titleB
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
      artistInATitleReplaced.isNotEmpty ? artistInATitleReplaced : titleA,
    ).toLowerCase(),
  );
  final aArtist = removeDuplicates(
    [artistA, ...artistListA].join(', ').toLowerCase(),
  );
  final bTitle = removeDuplicates(
    sanitizeSongTitle(
      artistInBTitleReplaced.isNotEmpty ? artistInBTitleReplaced : titleB,
    ).toLowerCase(),
  );
  final bArtist = removeDuplicates(
    [artistB, ...artistListB].join(', ').toLowerCase(),
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
      boundExtrasRegex.firstMatch(titleA)?[0]?.sanitized.toLowerCase();
  final bExtras =
      boundExtrasRegex.firstMatch(titleB)?[0]?.sanitized.toLowerCase();
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
