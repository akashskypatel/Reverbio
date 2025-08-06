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

import 'package:flutter/widgets.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/API/entities/artist.dart';
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
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

List globalSongs = [];
List userLikedSongsList = Hive.box('user').get('likedSongs', defaultValue: []);
List userOfflineSongs = Hive.box(
  'userNoBackup',
).get('offlineSongs', defaultValue: []);

List cachedSongsList = Hive.box('cache').get('cachedSongs', defaultValue: []);

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

Future<List> getSongsList(String searchQuery) async {
  try {
    final List<Video> searchResults = await yt.search.search(searchQuery);

    return searchResults.map((video) => returnYtSongLayout(0, video)).toList();
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return [];
  }
}

Future<List> getRecommendedSongs() async {
  try {
    final playlistSongs = [...userLikedSongsList, ...userRecentlyPlayed];
    if (globalSongs.isEmpty) {
      const playlistId = 'yt=PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx';
      globalSongs = await getSongsFromPlaylist(playlistId);
    }
    playlistSongs.addAll(pickRandomItems(globalSongs, 10));

    if (userCustomPlaylists.value.isNotEmpty) {
      for (final userPlaylist in userCustomPlaylists.value) {
        final _list = (userPlaylist['list'] as List)..shuffle();
        playlistSongs.addAll(_list.take(5));
      }
    }
    playlistSongs.shuffle();
    final seenYtIds = <String>{};
    playlistSongs.removeWhere((song) {
      if (song['ytid'] != null) return !seenYtIds.add(song['ytid']);
      return false;
    });
    return playlistSongs.take(15).toList();
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
      userLikedSongsList.add(song);
      currentLikedSongsLength.value = userLikedSongsList.length;
      song['song'] = song['title'];
      PM.triggerHook(song, 'onEntityLiked');
    } else {
      userLikedSongsList.removeWhere((s) => checkSong(s, song));
      currentLikedSongsLength.value = userLikedSongsList.length;
    }
    addOrUpdateData('user', 'likedSongs', userLikedSongsList);
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
  addOrUpdateData('user', 'likedSongs', userLikedSongsList);
}

bool isSongAlreadyLiked(songToCheck) =>
    songToCheck is Map &&
    userLikedSongsList.any(
      (song) => song is Map && checkSong(song, songToCheck),
    );

bool isSongAlreadyOffline(songToCheck) => userOfflineSongs.any(
  (song) => song is Map && songToCheck is Map && checkSong(song, songToCheck),
);

void getSimilarSong(String songYtId) async {
  try {
    final song = await yt.videos.get(songYtId);
    final relatedSongs = await yt.videos.getRelatedVideos(song) ?? [];

    if (relatedSongs.isNotEmpty) {
      nextRecommendedSong = returnYtSongLayout(0, relatedSongs[0]);
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<dynamic> findYTSong(dynamic song) async {
  try {
    final lcSongName =
        (song['title'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(specialRegex, '')
            .trim();
    final lcArtist =
        (song['artist'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(specialRegex, '')
            .trim();
    final lcAlbum =
        (song['album'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(specialRegex, '')
            .trim();
    final results = await getSongsList(
      '\'$lcArtist\' \'$lcSongName\' \'$lcAlbum\'',
    );
    results.sort((a, b) => b['views'].compareTo(a['views']));
    final result =
        results.where((value) {
          final lcS =
              sanitizeSongTitle(value['title'] ?? '')
                  .toLowerCase()
                  .replaceAll(lcArtist, '')
                  .replaceAll(lcAlbum == lcSongName ? '' : lcAlbum, '')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .replaceAll(specialRegex, '')
                  .trim();
          final lcC =
              (value['channelName'] ?? '')
                  .toString()
                  .toLowerCase()
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .replaceAll(specialRegex, '')
                  .trim();
          final lcA =
              (value['artist'] ?? '')
                  .toString()
                  .toLowerCase()
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .replaceAll(specialRegex, '')
                  .trim();
          final isLive = isSongLive(lcArtist, lcAlbum, lcSongName, lcS);
          final isDerivative = isSongDerivative(
            lcArtist,
            lcAlbum,
            lcSongName,
            lcS,
          );
          final isMatch =
              (ratio(lcS, lcSongName) >= 90) &&
              (ratio(lcC, lcArtist) >= 90 ||
                  ratio(lcA, lcArtist) >= 90 ||
                  lcS.contains(lcArtist));
          return isMatch && !isLive && !isDerivative;
        }).toList();

    return result.isNotEmpty ? result.first : {};
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<dynamic> findWDSong(String title, String artist) async {
  try {
    final searchStr = '${title.trim()} ${artist.trim()}'
        .replaceAll(RegExp(r'\=|\&|\?'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    final uri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': searchStr,
      'format': 'json',
      'srprop': 'snippet|titlesnippet|categorysnippet',
    });
    final response = await http.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
      },
    );
    final result = jsonDecode(response.body);
    final search = result['query']['search'] as List;
    return search;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

dynamic _getCachedSong(dynamic song) {
  try {
    final cached = cachedSongsList.where((e) {
      return checkSong(song, e) ||
          (song is Map &&
                  (song['ytid'] != null &&
                      e['ytid'] != null &&
                      song['ytid'] == e['ytid']) ||
              (song['originalTitle'] != null &&
                  song['originalArtist'] != null &&
                  song['originalTitle'] == e['originalTitle'] &&
                  song['originalArtist'] == e['originalArtist']));
    });
    if (cached.isEmpty) return null;
    return cached.first;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

Future<dynamic> getSongByRecordingDetails(
  dynamic recording, {
  bool getImage = true,
}) async {
  final id = parseEntityId(recording);
  final ids = Uri.parse('?${parseEntityId(id)}').queryParameters;
  final rcdId = recording is Map ? (recording['rid'] ?? ids['mb']) : ids['mb'];
  if (rcdId == null) return recording;
  final cached = _getCachedSong(recording);
  if (cached != null) {
    recording.addAll(Map<String, dynamic>.from(cached));
    return recording;
  } else
    try {
      recording = await mb.recordings.get(
        rcdId,
        inc: [
          'artists',
          'releases',
          'release-groups',
          'isrcs',
          'url-rels',
          'artist-credits',
          'annotation',
          'tags',
          'genres',
          'ratings',
          'artist-rels',
          'release-rels',
          'release-group-rels',
        ],
      );
      recording['artist'] = combineArtists(recording);
      if (getImage)
        for (final release in recording['releases']) {
          final coverArt = await mb.coverArt.get(release['id'], 'release');
          if (coverArt['error'] == null) {
            //TODO: parse by image size
            recording['images'] = coverArt['images'];
            break;
          }
        }
      recording.addAll({
        'id': 'mb=${recording['id']}',
        'rid': recording['id'],
        'mbid': recording['id'],
        'mbidType': 'recording',
        'duration': (recording['length'] ?? 0) ~/ 1000,
        'primary-type': 'song',
        'cachedAt': DateTime.now().toString(),
      });
      cachedSongsList.addOrUpdate('id', recording['id'], recording);
      addOrUpdateData('cache', 'cachedSongs', cachedSongsList);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  return recording;
}

Future<dynamic> findSongByIsrc(dynamic song) async {
  final id = parseEntityId(song);
  final ids = Uri.parse('?${parseEntityId(id)}').queryParameters;
  final rcdId = song is Map ? (song['rid'] ?? ids['mb']) : ids['mb'];
  final isrc = song is Map ? song['isrc'] : null;
  if (isrc == null) return song;
  final cached = _getCachedSong(song);
  if (cached != null) {
    song.addAll(Map<String, dynamic>.from(cached));
    return song;
  } else if (rcdId != null)
    return getSongByRecordingDetails(song);
  else if (isrc == null)
    return findMBSong(song);
  else
    try {
      final qry = 'isrc:$isrc';
      final qryResult =
          (await mb.recordings.search(qry, limit: 100))?['recordings'] ?? [];
      final recordings = List<Map<String, dynamic>>.from(qryResult);
      for (dynamic recording in recordings) {
        recording['artist'] = combineArtists(recording);
        if ((recording['isrcs'] as List).contains(isrc)) {
          recording = await getSongByRecordingDetails(recording);
          song.addAll(recording);
          await PM.triggerHook(song, 'onGetSongInfo');
          return song;
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  return song;
}

Future<dynamic> findMBSong(dynamic song) async {
  try {
    song['originalTitle'] = song['title'];
    song['originalArtist'] = song['artist'];
    final cached = _getCachedSong(song);
    if (cached != null) {
      song.addAll(Map<String, dynamic>.from(cached));
      await PM.triggerHook(song, 'onGetSongInfo');
      return song;
    }
    song['id'] = parseEntityId(song);
    final ids = Uri.parse('?${song['id']}').queryParameters;
    if (ids['mb'] != null && song['mbidType'] == 'recording') {
      song.addAll(await getSongByRecordingDetails(song));
      await PM.triggerHook(song, 'onGetSongInfo');
      return song;
    } else if (song['isrc'] != null && song['isrc'].isNotEmpty) {
      return await findSongByIsrc(song);
    }
    final iArtist = song['artist'].toString();
    final iTitle = song['title'].toString().replaceAll(
      RegExp('(official)|(visualizer)|(visualiser)', caseSensitive: false),
      '',
    );
    final artists = splitArtists(iArtist);
    Map artistInfo = {};
    String artistId = '';
    String artistQry = '';
    if (artists.length == 1) {
      artistInfo = Map.from(
        await searchArtistDetails(
          iArtist
              .trim()
              .replaceAll(specialRegex, ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
        ),
      );
      if (artistInfo.isNotEmpty)
        artistId =
            Uri.parse('?${artistInfo['id']}').queryParameters['mb'] ?? '';
    } else {
      for (final artists in artists) {
        artistQry =
            artistQry.isNotEmpty
                ? '$artistQry OR artist:\'${artists.replaceAll(specialRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim()}\''
                : 'artist:\'${artists.replaceAll(specialRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim()}\'';
      }
      artistQry = '($artistQry)';
    }
    final sTitle = removeDuplicates(
      sanitizeSongTitle(iTitle)
          .replaceAll(specialRegex, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toLowerCase(),
    ).replaceAll(' ', '|');
    final sArtist = removeDuplicates(
      sanitizeSongTitle(iArtist)
          .replaceAll(specialRegex, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toLowerCase(),
    ).replaceAll(' ', '|').replaceAll(sTitle, '');
    final phrase = '$sTitle|$sArtist';
    final qry =
        artistId.isNotEmpty
            ? "('$sTitle' OR release:'$sTitle') AND arid:$artistId"
            : sArtist.isNotEmpty
            ? "('$sTitle' OR release:'$sTitle') AND (artist:'$sArtist' OR artistname:'$sArtist')"
            : "'$phrase' OR release:'$phrase' OR artist:'$phrase' OR artistname:'$phrase'";

    final qryResult =
        (await mb.recordings.search(qry, limit: 100))?['recordings'] ?? [];
    final recordings = List<Map<String, dynamic>>.from(qryResult);
    for (dynamic recording in recordings) {
      recording['artist'] = combineArtists(recording);
      if (checkTitleAndArtist(song, recording)) {
        recording = await getSongByRecordingDetails(recording);
        song.addAll(recording);
        await PM.triggerHook(song, 'onGetSongInfo');
        return song;
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return song;
}

Future<StreamManifest> getSongManifest(String songId) async {
  try {
    final manifest =
        useProxies.value
            ? await pxm.getSongManifest(songId, timeout: streamRequestTimeout.value) ??
                await yt.videos.streams.getManifest(
                  songId,
                  //ytClients: userChosenClients, //let yt-explode manage client for best experience
                )
            : await yt.videos.streams.getManifest(
              songId,
              //ytClients: userChosenClients, //let yt-explode manage client for best experience
            );
    return manifest;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

const Duration _cacheDuration = Duration(hours: 3);

Future<void> getSongUrl(dynamic song) async {
  song['isError'] = false;
  song?.remove('error');
  final offlinePath = await getOfflinePath(song);
  if (song['mbid'] == null) await findMBSong(song);
  if (offlinePath != null) {
    song['songUrl'] = offlinePath;
    return;
  }
  await PM.getSongUrl(song, getSongYoutubeUrl);
  if (autoCacheOffline.value || (song['autoCacheOffline'] ?? false))
    unawaited(makeSongOffline(song));
}

Future<String> getSongYoutubeUrl(dynamic song, {bool waitForMb = false}) async {
  final context = NavigationManager().context;
  try {
    if (song == null) return '';
    if (song['mbid'] == null) await findMBSong(song);
    if (song['ytid'] == null) {
      final sngQry = await findYTSong(song);
      song.addAll(Map<String, dynamic>.from(sngQry ?? {}));
    }
    if (song['ytid'] != null && song['ytid'].isNotEmpty) {
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
      song['error'] = context.l10n!.errorCouldNotFindAStream;
      song['isError'] = true;
      return '';
    }
    //check if url resolves
    if (await checkUrl(song['songUrl']) >= 400) {
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

    return audioUrl;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

Future<Map<String, dynamic>> getYTSongDetails(dynamic song) async {
  try {
    final songIndex = (song['index'] ?? 0) as int;
    String songId = parseEntityId(song);
    if (songId.contains('yt=') || song['ytid'] != null) {
      songId =
          Uri.parse('?$songId').queryParameters['yt'] ?? song['ytid'] ?? '';
    } else {
      song = await getSongYoutubeUrl(song);
      songId = song['ytid'];
    }
    final ytSong = await yt.videos.get(songId);
    return returnYtSongLayout(songIndex, ytSong);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return {};
  }
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

Future<void> makeSongOffline(dynamic song) async {
  //TODO: make available offline for other sources
  try {
    final _dir = await getApplicationSupportDirectory();
    final _audioDirPath = '${_dir.path}/tracks';
    final _artworkDirPath = '${_dir.path}/artworks';
    await Directory(_audioDirPath).create(recursive: true);
    await Directory(_artworkDirPath).create(recursive: true);

    final id = song['id'] = parseEntityId(song);
    if (song['ytid'] == null || song['ytid'].isEmpty)
      song.addAll(Map<String, dynamic>.from(await findYTSong(song) ?? {}));
    final _audioFile = File('$_audioDirPath/$id.m4a');
    final _artworkFile = File('$_artworkDirPath/$id.jpg');

    try {
      final audioManifest = await getSongManifest(song['ytid']);
      final stream = yt.videos.streamsClient.get(
        audioManifest.audioOnly.withHighestBitrate(),
      );
      final fileStream = _audioFile.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();
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

    song['offlineAudioPath'] = _audioFile.path;
    userOfflineSongs.add(song);
    addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
    currentOfflineSongsLength.value = userOfflineSongs.length;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<List<dynamic>> getUserOfflineSongs() async {
  await getExistingOfflineSongs();
  return userOfflineSongs;
}

Future<void> getExistingOfflineSongs() async {
  final _dir = await getApplicationSupportDirectory();
  final _audioDirPath = '${_dir.path}/tracks';
  final _artworkDirPath = '${_dir.path}/artworks';
  try {
    if (Directory(_audioDirPath).existsSync())
      await for (final file in Directory(_audioDirPath).list()) {
        if (file is File && isAudio(file.path)) {
          final filename = basenameWithoutExtension(file.path);
          final ids = Uri.parse('?$filename').queryParameters;
          if (ids['mb'] != null && ids['mb']!.isNotEmpty) {
            if (!userOfflineSongs.any((e) => e['id'].contains(ids['mb']))) {
              final song = await getSongByRecordingDetails(filename);
              final imageFiles = await _getRelatedFiles(_artworkDirPath, song);
              if (imageFiles.isNotEmpty) {
                song['offlineArtworkPath'] = imageFiles.first.path;
              }
              song['offlineAudioPath'] = file.path;
              userOfflineSongs.add(song);
              addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
              currentOfflineSongsLength.value = userOfflineSongs.length;
            }
          }
        }
      }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<String?> getOfflinePath(dynamic song) async {
  final _dir = await getApplicationSupportDirectory();
  final _audioDirPath = '${_dir.path}/tracks';
  final _artworkDirPath = '${_dir.path}/artworks';
  song['id'] = parseEntityId(song);
  final audioFiles = await _getRelatedFiles(_audioDirPath, song);
  final artworkFiles = await _getRelatedFiles(_artworkDirPath, song);
  //TODO: add quality check
  if (audioFiles.isNotEmpty) song['offlineAudioPath'] = audioFiles.first.path;
  if (artworkFiles.isNotEmpty)
    song['offlineArtworkPath'] = artworkFiles.first.path;
  return song['offlineAudioPath'];
}

Future<List<File>> _getRelatedFiles(String directory, dynamic entity) async {
  final files = <File>[];
  try {
    final ids = Uri.parse('?${entity['id']}').queryParameters;
    await for (final file in Directory(directory).list()) {
      for (final songId in ids.values) {
        if (file is File && basename(file.path).contains(songId)) {
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
        if (file is File && basename(file.path).contains(songId)) {
          await file.delete();
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
}

Future<void> removeSongFromOffline(dynamic song) async {
  final _dir = await getApplicationSupportDirectory();
  final _audioDirPath = '${_dir.path}/tracks';
  final _artworkDirPath = '${_dir.path}/artworks';
  song['id'] = parseEntityId(song);
  unawaited(_deleteRelatedFiles(_audioDirPath, song));
  unawaited(_deleteRelatedFiles(_artworkDirPath, song));
  song?.remove('offlineAudioPath');
  song?.remove('offlineArtworkPath');
  song?.remove('songUrl');
  song['isOffline'] = false;
  userOfflineSongs.removeWhere((s) => checkSong(song, s));
  currentOfflineSongsLength.value = userOfflineSongs.length;
  addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
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
    addOrUpdateData('user', 'recentlyPlayedSongs', userRecentlyPlayed);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<Map<String, String>?> getYtSongAndArtist(String ytid) async {
  String? songName;
  String? artistName;

  try {
    final response = await http.get(
      Uri.parse('https://www.youtube.com/watch?v=$ytid'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
      },
    );
    final htmlContent = response.body;

    final regex = RegExp(
      r'(\{"metadataRowRenderer":.*?\})(?=,{"metadataRowRenderer")',
    );
    final matches = regex.allMatches(htmlContent);

    final jsonObjects = [];
    for (final match in matches) {
      final jsonStr = match.group(1);
      if (jsonStr != null &&
          (jsonStr.contains('{"simpleText":"Song"}') ||
              jsonStr.contains('{"simpleText":"Artist"}'))) {
        try {
          jsonObjects.add(json.decode(jsonStr));
        } catch (e) {
          // Skip invalid JSON
        }
      }
    }

    if (jsonObjects.length == 2) {
      final songContents = jsonObjects[0]['metadataRowRenderer']['contents'][0];
      final artistContents =
          jsonObjects[1]['metadataRowRenderer']['contents'][0];

      songName =
          songContents.containsKey('runs')
              ? songContents['runs'][0]['text']
              : songContents['simpleText'];

      artistName =
          artistContents.containsKey('runs')
              ? artistContents['runs'][0]['text']
              : artistContents['simpleText'];
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
  if (songName != null && artistName != null)
    return {'title': songName, 'artist': artistName};

  return null;
}

bool isSongLive(String? artist, String? album, String? title, String value) {
  // Convert to lowercase and remove title/artist
  final replaced =
      value
          .toLowerCase()
          .replaceAll(title?.toLowerCase() ?? '', '')
          .replaceAll(album?.toLowerCase() ?? '', '')
          .replaceAll(artist?.toLowerCase() ?? '', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(specialRegex, '')
          .trim();

  // Live detection regex
  final liveRegex = RegExp(
    r'(\blive\b\s*(?:\bat\b|\@|\bfrom\b|\bin\b|\bon\b|\bperformance\b|\b))|(\bstage\b|\bshow\b|\bconcert\b|\btour\b|\bcover\b|\bperform(?:ance\b|ed\b))',
    caseSensitive: false,
  );

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
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(specialRegex, '')
          .trim();

  final regex = RegExp(
    r'(\bversion\b|\bacapella\b|\bacoustic\b|\binstrumental\b|\bre\s?mix(?:\b|es\b|ed\b)|\bcover(?:\b|s\b|ed\b)|\bperform(?:ance\b|ed\b)|\bmashup\b|\bparod(?:y\b|ies\b|ied\b)|\bedit(?:\b|s\b|ed\b))',
    caseSensitive: false,
  );

  return regex.hasMatch(replaced);
}

bool checkSong(dynamic songA, dynamic songB) {
  if (songA is Map) songA['id'] = parseEntityId(songA);
  if (songB is Map) songB['id'] = parseEntityId(songB);
  if (songA is String && songB is String)
    return checkEntityId(songA, songB) || checkEntityId(songB, songA);
  if (songA is String && !(songB is String))
    return checkEntityId(songA, songB['id']) ||
        checkEntityId(songB['id'], songA);
  if (songB is String && !(songA is String))
    return checkEntityId(songB, songA['id']) ||
        checkEntityId(songA['id'], songB);
  if (songA['id'] == null ||
      songB['id'] == null ||
      songA['id']?.isEmpty ||
      songB['id']?.isEmpty)
    return checkTitleAndArtist(songA, songB);
  return checkEntityId(songA['id'], songB['id']) ||
      checkEntityId(songB['id'], songA['id']) ||
      (getSongHashCode(songA) == getSongHashCode(songB));
}

int? getSongHashCode(dynamic song) {
  if (!(song is Map)) return null;
  if ((song['title'] ?? song['song']) == null || song['artist'] == null)
    return null;
  return sanitizeSongTitle(
        song['title'] ?? song['song'],
      ).toLowerCase().hashCode ^
      song['artist'].toLowerCase().hashCode;
}

bool checkTitleAndArtist(dynamic songA, dynamic songB) {
  final extrasRegex = RegExp(
    r'[\(\[\{\<](?:[^)\]\}\>]*\b(official|music|lyrics?|video|audio|vi[sz]uali[sz]er?|hd|4k|high|quality|version|acoustic|instrumental|acapella|remix|acoustic|re(?:\s?|-)mix(?:|es|ed)|cover(?:|s|ed)|perform(?:ance|ed)|mashup|parod(?:y|ies|ied)|edit(?:|s|ed)|(live\s*(?:at|\@|from|in|on|performance|))|(?:stage|show|concert|tour|cover|perform(?:ance|ed)))\b[^)\]\}\>]*)[\)\]\}\>]',
    caseSensitive: false,
  );
  songA['artist'] = songA['artist'] ?? combineArtists(songA) ?? '';
  songB['artist'] = songB['artist'] ?? combineArtists(songB) ?? '';
  final aTitle = removeDuplicates(
    sanitizeSongTitle(songA['title'])
        .replaceAll(specialRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase(),
  );
  final aArtist = removeDuplicates(
    sanitizeSongTitle(songA['artist'])
        .replaceAll(specialRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase(),
  );
  final bTitle = removeDuplicates(
    sanitizeSongTitle(songB['title'])
        .replaceAll(specialRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase(),
  );
  final bArtist = removeDuplicates(
    sanitizeSongTitle(songB['artist'])
        .replaceAll(specialRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase(),
  );
  final titleCheck =
      aTitle.length >= bTitle.length
          ? aTitle.contains(bTitle)
          : bTitle.contains(aTitle);
  final artistCheck =
      (aArtist.length >= bArtist.length
          ? aArtist.contains(bArtist)
          : bArtist.contains(aArtist)) ||
      aTitle == aArtist ||
      bTitle == bArtist;
  final aExtras =
      extrasRegex
          .firstMatch(songA['title'])?[0]
          ?.replaceAll(specialRegex, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toLowerCase();
  final bExtras =
      extrasRegex
          .firstMatch(songB['title'])?[0]
          ?.replaceAll(specialRegex, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toLowerCase();
  final extraCheck =
      (aExtras == null && bExtras == null) ||
      (aExtras != null &&
          bExtras != null &&
          weightedRatio(aExtras, bExtras) >= 90);
  final ratioCheck =
      aTitle != aArtist && bTitle != bArtist
          ? weightedRatio(
                removeDuplicates('$aTitle $aArtist'),
                removeDuplicates('$bTitle $bArtist'),
              ) >=
              90
          : weightedRatio(
                    removeDuplicates(aTitle),
                    removeDuplicates('$bTitle $bArtist'),
                  ) >=
                  90 ||
              weightedRatio(
                    removeDuplicates(bTitle),
                    removeDuplicates('$aTitle $aArtist'),
                  ) >=
                  90 ||
              weightedRatio(
                    removeDuplicates(bTitle),
                    removeDuplicates(aTitle),
                  ) >=
                  90;
  return ((titleCheck && artistCheck) || ratioCheck) && extraCheck;
}
