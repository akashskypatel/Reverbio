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
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/lyrics_manager.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

List globalSongs = [];
List userLikedSongsList = Hive.box('user').get('likedSongs', defaultValue: []);
List userOfflineSongs = Hive.box(
  'userNoBackup',
).get('offlineSongs', defaultValue: []);

late final ValueNotifier<int> currentLikedSongsLength;
late final ValueNotifier<int> currentOfflineSongsLength;
late final ValueNotifier<int> currentRecentlyPlayedLength;

int activeSongId = 0;

final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;

Future<List> getSongsList(String searchQuery) async {
  try {
    final List<Video> searchResults = await yt.search.search(searchQuery);

    return searchResults.map((video) => returnSongLayout(0, video)).toList();
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsList', e, stackTrace);
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
                .map((s) => returnSongLayout(0, s))
                .toList();
          }).toList();

      final results = await Future.wait(futures);
      final playlistSongs = results.expand((list) => list).toList()..shuffle();
      return playlistSongs;
    } else {
      final playlistSongs = [...userLikedSongsList, ...userRecentlyPlayed];
      if (globalSongs.isEmpty) {
        const playlistId = 'PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx';
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
      playlistSongs.removeWhere((song) => !seenYtIds.add(song['ytid']));
      return playlistSongs.take(15).toList();
    }
  } catch (e, stackTrace) {
    logger.log('Error in getRecommendedSongs', e, stackTrace);
    return [];
  }
}

Future<void> updateSongLikeStatus(dynamic songId, bool add) async {
  if (add) {
    userLikedSongsList.add(
      await getSongDetails(userLikedSongsList.length, songId),
    );
    currentLikedSongsLength.value++;
  } else {
    userLikedSongsList.removeWhere((song) => song['ytid'] == songId);
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
    userLikedSongsList.any((song) => song['ytid'] == songIdToCheck);

bool isSongAlreadyOffline(songIdToCheck) =>
    userOfflineSongs.any((song) => song['ytid'] == songIdToCheck);

void getSimilarSong(String songYtId) async {
  try {
    final song = await yt.videos.get(songYtId);
    final relatedSongs = await yt.videos.getRelatedVideos(song) ?? [];

    if (relatedSongs.isNotEmpty) {
      nextRecommendedSong = returnSongLayout(0, relatedSongs[0]);
    }
  } catch (e, stackTrace) {
    logger.log('Error while fetching next similar song:', e, stackTrace);
  }
}

Future<dynamic> findSong(String songName, String artist) async {
  try {
    final lcSongName = songName.toLowerCase();
    final lcArtist = artist.toLowerCase();
    final results = await getSongsList('"$lcArtist" "$lcSongName"');
    results.sort((a, b) => b['views'].compareTo(a['views']));
    final result =
        results.where((value) {
          final lcS = value['title'].toString().trim().toLowerCase();
          final lcC = value['channelName'].toString().trim().toLowerCase();
          final ex = lcS.contains(lcSongName) && (lcC.contains(lcArtist));
          return ex;
        }).toList();

    return result.isNotEmpty ? result.first : {};
  } catch (e, stackTrace) {
    logger.log('Error while getting song streaming URL', e, stackTrace);
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
    logger.log('Error while getting song streaming manifest', e, stackTrace);
    rethrow; // Rethrow the exception to allow the caller to handle it
  }
}

const Duration _cacheDuration = Duration(hours: 3);

Future<String> getSong(String songId, bool isLive) async {
  try {
    final qualitySetting = audioQualitySetting.value;
    final cacheKey = 'song_${songId}_${qualitySetting}_url';

    final cachedUrl = await getData(
      'cache',
      cacheKey,
      cachingDuration: _cacheDuration,
    );

    unawaited(updateRecentlyPlayed(songId));

    if (cachedUrl != null) {
      return cachedUrl;
    }

    if (isLive) {
      return await getLiveStreamUrl(songId);
    }

    return await getAudioUrl(songId);
  } catch (e, stackTrace) {
    logger.log('Error while getting song streaming URL', e, stackTrace);
    rethrow;
  }
}

Future<String> getAudioUrl(String songId) async {
  final manifest = await yt.videos.streamsClient.getManifest(songId);
  final audioQuality = selectAudioQuality(manifest.audioOnly.sortByBitrate());
  final audioUrl = audioQuality.url.toString();

  return audioUrl;
}

Future<Map<String, dynamic>> getSongDetails(
  int songIndex,
  String songId,
) async {
  try {
    final song = await yt.videos.get(songId);
    return returnSongLayout(songIndex, song);
  } catch (e, stackTrace) {
    logger.log('Error while getting song details', e, stackTrace);
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
    final String ytid = song['ytid'];
    final _audioFile = File('$_audioDirPath/$ytid.m4a');
    final _artworkFile = File('$_artworkDirPath/$ytid.jpg');

    await Directory(_audioDirPath).create(recursive: true);
    await Directory(_artworkDirPath).create(recursive: true);

    try {
      final audioManifest = await getSongManifest(ytid);
      final stream = yt.videos.streamsClient.get(audioManifest);
      final fileStream = _audioFile.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();
    } catch (e, stackTrace) {
      logger.log('Error downloading audio file', e, stackTrace);
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
      logger.log('Error downloading artwork', e, stackTrace);
    }

    song['audioPath'] = _audioFile.path;
    userOfflineSongs.add(song);
    addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
    currentOfflineSongsLength.value = userOfflineSongs.length;
  } catch (e, stackTrace) {
    logger.log('Error making song offline', e, stackTrace);
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

  userOfflineSongs.removeWhere((song) => song['ytid'] == songId);
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
    logger.log('Error downloading and saving file', e, stackTrace);
  }

  return null;
}

const recentlyPlayedSongsLimit = 50;

Future<void> updateRecentlyPlayed(dynamic songId) async {
  if (userRecentlyPlayed.length == 1 && userRecentlyPlayed[0]['ytid'] == songId)
    return;
  if (userRecentlyPlayed.length >= recentlyPlayedSongsLimit) {
    userRecentlyPlayed.removeLast();
  }

  userRecentlyPlayed.removeWhere((song) => song['ytid'] == songId);
  currentRecentlyPlayedLength.value = userRecentlyPlayed.length;

  final newSongDetails = await getSongDetails(
    userRecentlyPlayed.length,
    songId,
  );

  userRecentlyPlayed.insert(0, newSongDetails);
  currentRecentlyPlayedLength.value = userRecentlyPlayed.length;
  addOrUpdateData('user', 'recentlyPlayedSongs', userRecentlyPlayed);
}
