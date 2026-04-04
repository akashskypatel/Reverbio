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

import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song_cache.dart';
import 'package:reverbio/API/entities/song_metadata.dart';
import 'package:reverbio/API/entities/song_offline.dart';
import 'package:reverbio/API/entities/song_state.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// H.4 fix: Extract YouTube functions from song.dart
/// Handles YouTube song search, details, and URL fetching.

/// Search for songs on YouTube by query.
Future<List> getSongsList(String searchQuery) async {
  try {
    final List<Video> searchResults = await yt.search.search(searchQuery);
    return searchResults.map(returnYtSongLayout).toList();
  } catch (e, stackTrace) {
    logger.log('Error in getSongsList:', e, stackTrace);
    return [];
  }
}

/// Get recommended songs from global playlist.
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
    logger.log('Error in getRecommendedSongs:', e, stackTrace);
    return [];
  }
}

/// Get similar song based on YouTube video ID.
Future<void> getSimilarSong(String songYtId) async {
  try {
    final song = await yt.videos.get(songYtId);
    final relatedSongs = await yt.videos.getRelatedVideos(song) ?? [];

    if (relatedSongs.isNotEmpty) {
      nextRecommendedSong = returnYtSongLayout(relatedSongs[0]);
    }
  } catch (e, stackTrace) {
    logger.log('Error in getSimilarSong:', e, stackTrace);
  }
}

/// Find a YouTube song by searching or using existing ytid.
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
    addSongToCache(song as Map<String, dynamic>);
    if (getSongInfoQueue.isEmpty) cachedSongsList.writeToCache();
  } catch (e, stackTrace) {
    logger.log('Error in findYTSong:', e, stackTrace);
  }
  return song;
}

/// Find YouTube song by searching title and artist.
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
    logger.log('Error in _findYTSong:', e, stackTrace);
  }
  return [];
}

/// Get YouTube song details by video ID.
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
    logger.log('Error in _getYTSongDetails:', e, stackTrace);
  }
  return ytSong;
}

/// Get YouTube audio URL for a song.
Future<String> getSongYoutubeUrl(dynamic song, {bool waitForMb = false}) async {
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
      bool cachedUrlValid = false;

      // Validate cached URL if it exists
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        final uri = Uri.parse(cachedUrl);
        final expires = int.tryParse(uri.queryParameters['expire'] ?? '0') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        // Add 5 second grace period
        if (expires > (now + 5)) {
          if (await checkUrl(cachedUrl) < 400) {
            cachedUrlValid = true;
            songUrl = cachedUrl;
          }
        }
      }

      // R5 fix: Return early if cached URL is valid (skip redundant checkUrl call)
      if (cachedUrlValid) return songUrl;

      // Fetch fresh URL if no valid cache
      if (!cachedUrlValid) {
        songUrl =
            song['songUrl'] = await px.getYouTubeAudioUrl(
              song['ytid'],
              streamRequestTimeout.value,
              audioQualitySetting.value,
              useProxies.value,
            );
      }
      if (songUrl.isEmpty) {
        logger.log(
          'Could not find YouTube stream for this song. ${song['artist']} - ${song['title']}',
          null,
          null,
        );
        song['songUrl'] = null;
        song['error'] = L10n.current.errorCouldNotFindAStream;
        song['isError'] = true;
      }
      //check if url resolves (R5 fix: only check non-empty URLs)
      if (songUrl.isNotEmpty && await checkUrl(songUrl) >= 400) {
        logger.log('Song url could not be resolved. $songUrl', null, null);
        song['songUrl'] = null;
        song['error'] = L10n.current.urlError;
        song['isError'] = true;
        return '';
      }
      // Fix: Cache URL only after validation passes
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
  } catch (e, stackTrace) {
    song['songUrl'] = null;
    song['error'] = L10n.current.urlError;
    song['isError'] = true;
    logger.log('Error in getSongYoutubeUrl:', e, stackTrace);
  }
  return songUrl;
}
