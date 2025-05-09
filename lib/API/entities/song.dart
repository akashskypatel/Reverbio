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
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/l10n.dart';
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

late final ValueNotifier<int> currentLikedSongsLength;
late final ValueNotifier<int> currentOfflineSongsLength;
late final ValueNotifier<int> currentRecentlyPlayedLength;
late final ValueNotifier<int> activeQueueLength;

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
      //final recoms = _yt.search.searchContent('searchQuery', filter:TypeFilters.channel)
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

Future<void> updateSongLikeStatus(dynamic songId, bool add) async {
  if (add && songId != null) {
    final song = await getSongDetails(userLikedSongsList.length, songId);
    userLikedSongsList.add(song);
    currentLikedSongsLength.value++;
  } else {
    userLikedSongsList.removeWhere((song) => song['id'] == songId);
    currentLikedSongsLength.value--;
  }
  addOrUpdateData('user', 'likedSongs', userLikedSongsList);
}

void moveLikedSong(int oldIndex, int newIndex) {
  final _song = userLikedSongsList[oldIndex];
  userLikedSongsList
    ..removeAt(oldIndex)
    ..insert(newIndex, _song);
  currentLikedSongsLength.value = userLikedSongsList.length;
  addOrUpdateData('user', 'likedSongs', userLikedSongsList);
}

bool isSongAlreadyLiked(songIdToCheck) =>
    userLikedSongsList.any((song) => song['id'] == songIdToCheck);

bool isSongAlreadyOffline(songIdToCheck) =>
    userOfflineSongs.any((song) => song['id'] == songIdToCheck);

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

Future<dynamic> findYTSong(String songName, String artist) async {
  try {
    final lcSongName = songName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final lcArtist = artist.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final results = await getSongsList('"$lcArtist" "$lcSongName"');
    results.sort((a, b) => b['views'].compareTo(a['views']));
    final result =
        results.where((value) {
          final lcS = value['title'].toString().trim().toLowerCase().replaceAll(
            RegExp(r'\s+'),
            ' ',
          );
          final lcC = value['channelName']
              .toString()
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ');
          final ex =
              (lcS.contains(lcSongName) && (lcC.contains(lcArtist))) ||
              (lcS.contains(lcSongName) && lcS.contains(lcArtist));
          return ex;
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
    final response = await http.get(uri);
    final result = jsonDecode(response.body);
    final search = result['query']['search'] as List;
    return search;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<dynamic> findMBSong(dynamic song) async {
  try {
    final artist = song['artist'].toString();
    final title = song['title'].toString().replaceAll(
      RegExp('(official)|(visualizer)|(visualiser)', caseSensitive: false),
      '',
    );
    final regex = RegExp(r'''[+\-&|!(){}[\]^"~*?:\\']''');
    final artists = splitArtists(artist);
    Map artistInfo = {};
    String artistId = '';
    List recordings = [];
    List works = [];
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
                ? '$artistQry OR artist:"${artsts.replaceAll(regex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim()}"'
                : 'artist:"${artsts.replaceAll(regex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim()}"';
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
            ? (exact ? '"$sTitle"~0.75' : '"$sTitle"~0.75 AND arid:"$artistId"')
            : exact
            ? '"$sTitle"~0.75'
            : (similar
                ? '("$rA" AND artist:"$rB") OR ("$rB" AND artist:"$rA")'
                : (artistQry.isNotEmpty
                    ? '"$sTitle"~0.75 AND (artist:"${artists.join('" & "')}" OR $artistQry)'
                    : '(("$sTitle"~0.75 AND artist:"$sArtist") OR ("$sArtist"~0.75 AND artist:"$sTitle"))')));
    works = List<Map<String, dynamic>>.from(
      (await mb.works.search(qry))['works'],
    );
    recordings = List<Map<String, dynamic>>.from(
      (await mb.recordings.search(qry))['recordings'],
    );
    if (recordings.isEmpty && works.isEmpty) return song;

    dynamic recording;
    if (works.length != 1) {
      recordings =
          recordings.where((rcd) {
            final acs =
                (rcd['artist-credit'] as List).where((value) {
                  for (final a in artists) {
                    if (value['name'].toLowerCase().contains(a.toLowerCase()))
                      return true;
                  }
                  return false;
                }).toList();
            return acs.isNotEmpty;
          }).toList();
      if (recordings.isEmpty) return song;
      if (recordings.length == 1) {
        recording = recordings.first;
      } else {
        final WeightedKey<Map<String, dynamic>> keys = WeightedKey(
          name: 'title',
          getter: (e) => e['title'],
          weight: 1,
        );
        final fuzzy = Fuzzy(
          recordings as List<Map<String, dynamic>>,
          options: FuzzyOptions(threshold: 1, keys: [keys]),
        );
        final result = fuzzy.search(title)
          ..sort((a, b) => a.score.compareTo(b.score));
        recording = result.first.item;
      }
      if (recording['artist-credit'] != null)
        artistInfo = {
          'artist': recording['artist-credit'].first['artist']['name'],
          'id': 'mb=${recording['artist-credit'].first['artist']['id']}',
        };
    } else {
      recording = works.first;
    }

    song.addAll({
      'id': 'mb=${recording['id']}',
      'mbid': recording['id'],
      'mbidType': works.length != 1 ? 'recording' : 'work',
      'title': recording['title'],
      'artist': artistInfo['artist'] ?? artists.join(' & '),
      'artistId': artistInfo['id'],
      'primary-type': 'song',
    });
    return song;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<AudioOnlyStreamInfo> getSongManifest(String songId) async {
  try {
    final manifest = await yt.videos.streams.getManifest(
      songId,
      ytClients: userChosenClients,
    );
    final audioStream = manifest.audioOnly.withHighestBitrate();
    return audioStream;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow; // Rethrow the exception to allow the caller to handle it
  }
}

const Duration _cacheDuration = Duration(hours: 3);

Future<String> getSongUrl(dynamic song) async {
  try {
    if (song == null) return '';
    if (song['mbid'] == null) unawaited(findMBSong(song));
    if (song['ytid'] == null)
      song.addAll(
        Map<String, dynamic>.from(
          await findYTSong(song['title'], song['artist']),
        ),
      );
    if (song['ytid'] != null && song['ytid'].isNotEmpty) {
      unawaited(updateRecentlyPlayed(song['ytid']));
      print('getYouTubeAudioUrl: ${getFormattedDateTimeNow()}');
      final songUrl = await getYouTubeAudioUrl(song['ytid']);
      print('getYouTubeAudioUrl: ${getFormattedDateTimeNow()}');
      final uri = Uri.parse(songUrl);
      final expires = int.tryParse(uri.queryParameters['expire'] ?? '0') ?? 0;
      song['songUrl'] = songUrl;
      song['songUrlExpire'] = expires;
      song['isError'] = false;
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
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<String> getYouTubeAudioUrl(String songId) async {
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

  final manifest = await yt.videos.streamsClient.getManifest(songId);
  final audioQuality = selectAudioQuality(manifest.audioOnly.sortByBitrate());
  final audioUrl = audioQuality.url.toString();

  return audioUrl;
}

Future<int> checkUrl(String url) async {
  try {
    final response = await http.head(Uri.parse(url));
    return response.statusCode;
  } catch (e) {
    rethrow;
  }
}

Future<Map<String, dynamic>> getSongDetails(
  int songIndex,
  String songId,
) async {
  try {
    String id;
    if (songId.contains('yt=')) {
      id = Uri.parse('?$songId').queryParameters['yt'] ?? '';
    } else {
      id = songId;
    }
    final song = await yt.videos.get(id);
    return returnYtSongLayout(songIndex, song);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
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
  try {
    final _dir = await getApplicationSupportDirectory();
    final _audioDirPath = '${_dir.path}/tracks';
    final _artworkDirPath = '${_dir.path}/artworks';
    final String id = song['id'];
    final _audioFile = File('$_audioDirPath/$id.m4a');
    final _artworkFile = File('$_artworkDirPath/$id.jpg');

    await Directory(_audioDirPath).create(recursive: true);
    await Directory(_artworkDirPath).create(recursive: true);

    try {
      final audioManifest = await getSongManifest(id);
      final stream = yt.videos.streamsClient.get(audioManifest);
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

Future<void> removeSongFromOffline(dynamic songId) async {
  final _dir = await getApplicationSupportDirectory();
  final _audioDirPath = '${_dir.path}/tracks';
  final _artworkDirPath = '${_dir.path}/artworks';
  final _audioFile = File('$_audioDirPath/$songId.m4a');
  final _artworkFile = File('$_artworkDirPath/$songId.jpg');

  if (await _audioFile.exists()) await _audioFile.delete(recursive: true);
  if (await _artworkFile.exists()) await _artworkFile.delete(recursive: true);

  userOfflineSongs.removeWhere((song) => song['id'] == songId);
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

Future<void> updateRecentlyPlayed(dynamic songId) async {
  try {
    if (userRecentlyPlayed.length == 1 && userRecentlyPlayed[0]['id'] == songId)
      return;
    if (userRecentlyPlayed.length >= recentlyPlayedSongsLimit) {
      userRecentlyPlayed.removeLast();
    }

    userRecentlyPlayed.removeWhere((song) => song['id'] == songId);
    currentRecentlyPlayedLength.value = userRecentlyPlayed.length;

    final newSongDetails = await getSongDetails(
      userRecentlyPlayed.length,
      songId,
    );

    userRecentlyPlayed.insert(0, newSongDetails);
    currentRecentlyPlayedLength.value = userRecentlyPlayed.length;
    addOrUpdateData('user', 'recentlyPlayedSongs', userRecentlyPlayed);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}
