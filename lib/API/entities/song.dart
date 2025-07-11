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
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/lyrics_manager.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

List globalSongs = [];
List userLikedSongsList = Hive.box('user').get('likedSongs', defaultValue: []);
List userOfflineSongs = Hive.box(
  'userNoBackup',
).get('offlineSongs', defaultValue: []);

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
    if (defaultRecommendations.value && userRecentlyPlayed.isNotEmpty) {
      final recent = userRecentlyPlayed.take(3).toList();
      /*
      final recoms = yt.search.searchContent(
        'searchQuery',
        filter: TypeFilters.channel,
      );
      */
      final futures =
          recent.map((songData) async {
            final song = await yt.videos.get(songData['ytid']);
            final relatedSongs = await yt.videos.getRelatedVideos(song) ?? [];
            return relatedSongs
                .take(3)
                .map((s) => returnYtSongLayout(0, s))
                .toList();
          }).toList();

      final results = await Future.wait(futures);
      final playlistSongs = results.expand((list) => list).toList()..shuffle();
      return playlistSongs;
    } else {
      final playlistSongs = [...userLikedSongsList, ...userRecentlyPlayed];
      if (globalSongs.isEmpty) {
        const playlistId = 'yt=PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx';
        globalSongs = await getSongsFromPlaylist(playlistId);
      }
      playlistSongs.addAll(globalSongs.take(10));

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
    }
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
      currentLikedSongsLength.value++;
      song['song'] = song['title'];
      PM.onEntityLiked(song);
    } else {
      userLikedSongsList.removeWhere((s) => checkSong(s, song));
      currentLikedSongsLength.value--;
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
    final specialRegex = RegExp(r'''[+\-\—\–&|!(){}[\]^"~*?:\\']''');
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

Future<dynamic> getSongByReleaseId(String releaseId) async {
  Map release = {};
  release['id'] = parseEntityId(releaseId);
  try {
    release = await mb.releases.get(
      releaseId,
      inc: [
        'artists',
        'collections',
        'labels',
        'recordings',
        'release-groups',
        'artist-credits',
        'media',
        'discids',
        'isrcs',
        'annotation',
        'tags',
        'genres',
        'artist-rels',
        'label-rels',
        'recording-rels',
        'release-group-rels',
        'url-rels',
      ],
    );
    release['artist'] = combineArtists(release);
    final tracklist = LinkedHashSet<String>();
    release['list'] = [];
    var i = 0;
    for (final media in (release['media'] ?? [])) {
      for (final track in (media['tracks'] ?? [])) {
        if (tracklist.add(track['title'])) {
          final artist = combineArtists(track);
          release['list'].add({
            'index': i++,
            'id': 'mb=${track['id']}',
            'mbid': track['id'],
            'mbidType': 'track',
            'ytid': null,
            'title': track['title'],
            'source': null,
            'artist': artist,
            'artist-credit': track['artist-credit'],
            'duration': (track['length'] ?? 0) ~/ 1000,
            'isLive': false,
            'primary-type': 'song',
          });
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return release;
}

Future<dynamic> findMBSong(dynamic song) async {
  try {
    final countryCode =
        (userGeolocation['countryCode'] ??
                (await getIPGeolocation())['countryCode'] ??
                '')
            .toString()
            .toLowerCase();
    song['id'] = parseEntityId(song);
    final ids = Uri.parse('?${song['id']}').queryParameters;
    if (ids['mb'] != null) {
      song.addAll(await getSongByReleaseId(ids['mb']!));
      return song;
    }
    final artist = song['artist'].toString();
    final title = song['title'].toString().replaceAll(
      RegExp('(official)|(visualizer)|(visualiser)', caseSensitive: false),
      '',
    );
    final regex = RegExp(r'''[+\-\—\–&|!(){}[\]^"~*?:\\']''');
    final artists = splitArtists(artist);
    Map artistInfo = {};
    String artistId = '';
    List releases = [];
    String artistQry = '';
    if (artists.length == 1) {
      artistInfo = Map.from(
        await searchArtistDetails(
          artist
              .trim()
              .replaceAll(regex, ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
        ),
      );
      if (artistInfo.isNotEmpty)
        artistId =
            Uri.parse('?${artistInfo['id']}').queryParameters['mb'] ?? '';
    } else {
      for (final artsts in artists) {
        artistQry =
            artistQry.isNotEmpty
                ? '$artistQry OR artist:\'${artsts.replaceAll(regex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim()}\''
                : 'artist:\'${artsts.replaceAll(regex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim()}\'';
      }
      artistQry = '($artistQry)';
    }
    final sTitle =
        title.replaceAll(regex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final sArtist =
        artist.replaceAll(regex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final similar =
        sTitle.toLowerCase().contains(sArtist.toLowerCase()) ||
        sArtist.toLowerCase().contains(sTitle.toLowerCase());
    final exact = sTitle.toLowerCase() == sArtist.toLowerCase();
    final rA =
        sTitle.toLowerCase() != sArtist.toLowerCase() &&
                sTitle.toLowerCase().contains(sArtist.toLowerCase())
            ? sTitle.toLowerCase().replaceAll(sArtist.toLowerCase(), '')
            : sTitle.toLowerCase();
    final rB =
        sTitle.toLowerCase() != sArtist.toLowerCase() &&
                sArtist.toLowerCase().contains(sTitle.toLowerCase())
            ? sArtist.toLowerCase().replaceAll(sTitle.toLowerCase(), '')
            : sArtist.toLowerCase();
    final qry =
        (artistId.isNotEmpty
            ? (exact
                ? '\'${sTitle.replaceAll(' ', '|')}\''
                : '\'${sTitle.replaceAll(' ', '|')}\' AND arid:$artistId')
            : exact
            ? '\'${sTitle.replaceAll(' ', '|')}\''
            : (similar
                ? '(\'$rA\' AND artist:\'$rB\') OR (\'$rB\' AND artist:\'$rA\')'
                : (artistQry.isNotEmpty
                    ? '\'${sTitle.replaceAll(' ', '|')}\' AND (artist:\'${artists.join('\' & \'')}\' OR $artistQry)'
                    : '((\'${sTitle.replaceAll(' ', '|')}\' AND artist:\'${sArtist.replaceAll(' ', '|')}\') OR (\'${sArtist.replaceAll(' ', '|')}\' AND artist:\'${sTitle.replaceAll(' ', '|')}\'))')));
    final releaseQry = await mb.releases.search(qry, limit: 100);
    final filtered =
        List<Map<String, dynamic>>.from((releaseQry ?? {})['releases'] ?? [])
            .where(
              (r) => [countryCode, 'xw'].contains(r['country']?.toLowerCase()),
            )
            .toList();
    releases =
        filtered.isEmpty
            ? [
              List<Map<String, dynamic>>.from(
                (releaseQry ?? {})['releases'] ?? [],
              ).first,
            ]
            : filtered;
    for (final release in releases) {
      release.addAll(
        await mb.releases.get(
          release['id'],
          inc: [
            'artists',
            'collections',
            'labels',
            'recordings',
            'release-groups',
            'artist-credits',
            'media',
            'discids',
            'isrcs',
            'annotation',
            'tags',
            'genres',
            'artist-rels',
            'label-rels',
            'recording-rels',
            'release-group-rels',
            'url-rels',
          ],
        ),
      );
      release['artist'] = combineArtists(release);
      final tracklist = LinkedHashSet<String>();
      release['list'] = [];
      for (final media in (release['media'] ?? [])) {
        for (final track in (media['tracks'] ?? [])) {
          if (tracklist.add(track['title'])) {
            release['list'].add({
              'id': 'mb=${track['id']}',
              'mbid': track['id'],
              'mbidType': 'track',
              'artist': release['artist'],
              'duration': (track['length'] ?? 0) ~/ 1000,
              'primary-type': 'song',
              'artist-credit':
                  track['artist-credit'] ??
                  media['artist-credit'] ??
                  release['artist-credit'],
            });
            release.addAll({
              'id': 'mb=${release['id']}',
              'mbid': release['id'],
              'mbidType': 'release',
              'artist': release['artist'],
              'duration': (track['length'] ?? 0) ~/ 1000,
              'primary-type': 'song',
            });
            final titleCheck =
                (song['title']?.length >= track['title']?.length
                    ? song['title']?.contains(track['title'])
                    : track['title']?.contains(song['title'])) ??
                false;
            final artistCheck =
                (song['artist']?.length >= release['artist']?.length
                    ? song['artist']?.contains(release['artist'])
                    : release['artist']?.contains(song['artist'])) ??
                false;
            if ((titleCheck && artistCheck) ||
                ratio(song['title'], track['title']) >= 90 &&
                    ratio(song['artist'], release['artist']) >= 90) {
              song.addAll(release);
              return song;
            }
          }
        }
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
        await pxm.getSongManifest(songId) ??
        await yt.videos.streams.getManifest(
          songId,
          ytClients: userChosenClients,
        );
    return manifest;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow; // Rethrow the exception to allow the caller to handle it
  }
}

const Duration _cacheDuration = Duration(hours: 3);

Future<void> getSongUrl(dynamic song) async {
  final offlinePath = await getOfflinePath(song);
  if (song['musicbrainz'] == null) await findMBSong(song);
  if (offlinePath != null) {
    song['songUrl'] = offlinePath;
    return;
  }
  await PM.getSongUrl(song, getSongYoutubeUrl);
}

Future<String> getSongYoutubeUrl(dynamic song, {bool waitForMb = false}) async {
  try {
    if (song == null) return '';
    if (song['musicbrainz'] == null) await findMBSong(song);
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
      song['error'] = 'Could not find YoutTube stream for this song.';
      song['isError'] = true;
      return '';
    }
    //check if url resolves
    if (await checkUrl(song['songUrl']) >= 400) {
      song['error'] = 'Song url could not be resolved.';
      song['isError'] = true;
      return '';
    }
    return song['songUrl'];
  } catch (e, stackTrace) {
    song['error'] = 'Song url could not be resolved.';
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
      final artworkFile = await _downloadAndSaveArtworkFile(
        song['highResImage'],
        _artworkFile.path,
      );

      if (artworkFile != null) {
        song['artworkPath'] = artworkFile.path;
        song['highResImage'] = artworkFile.path;
        song['lowResImage'] = artworkFile.path;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }

    song['audioPath'] = _audioFile.path;
    userOfflineSongs.add(song);
    addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
    currentOfflineSongsLength.value = userOfflineSongs.length;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
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
  if (audioFiles.isNotEmpty) song['audioPath'] = audioFiles.first.path;
  if (artworkFiles.isNotEmpty) song['image'] = artworkFiles.first.path;
  return song['audioPath'];
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
  userOfflineSongs.removeWhere((s) => checkSong(song, s));
  currentOfflineSongsLength.value = userOfflineSongs.length;
  addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
}

Future<File?> _downloadAndSaveArtworkFile(String url, String filePath) async {
  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
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
  final specialRegex = RegExp(r'''[+\-\—\–&|!(){}[\]^"~*?:\\']''');
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
  final specialRegex = RegExp(r'''[+\-\—\–&|!(){}[\]^"~*?:\\']''');
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
    r'(\bversion\b|\bacoustic\b|\binstrumental\b|\bre\s?mix(?:\b|es\b|ed\b)|\bcover(?:\b|s\b|ed\b)|\bperform(?:ance\b|ed\b)|\bmashup\b|\bparod(?:y\b|ies\b|ied\b)|\bedit(?:\b|s\b|ed\b))',
    caseSensitive: false,
  );

  return regex.hasMatch(replaced);
}

bool checkSong(dynamic song, dynamic otherSong) {
  song['id'] = parseEntityId(song);
  otherSong['id'] = parseEntityId(otherSong);
  if (song is String && otherSong is String)
    return checkEntityId(song, otherSong) || checkEntityId(otherSong, song);
  if (song is String && !(otherSong is String))
    return checkEntityId(song, otherSong['id']) ||
        checkEntityId(otherSong['id'], song);
  if (otherSong is String && !(song is String))
    return checkEntityId(otherSong, song['id']) ||
        checkEntityId(song['id'], otherSong);
  return checkEntityId(song['id'], otherSong['id']) ||
      checkEntityId(otherSong['id'], song['id']) ||
      (getSongHashCode(song) == getSongHashCode(otherSong));
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
