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

import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song_cache.dart';
import 'package:reverbio/API/entities/song_metadata.dart';
import 'package:reverbio/API/entities/song_offline.dart';
import 'package:reverbio/API/entities/song_state.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/plugins_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/notifiable_future.dart';
import 'package:reverbio/utilities/utils.dart';

/// H.5 fix: Extract MusicBrainz functions from song.dart
/// Handles MusicBrainz metadata fetching and ISRC lookup.

/// Queue a song info request to avoid duplicate fetches.
NotifiableFuture<Map<String, dynamic>> queueSongInfoRequest(dynamic song) {
  // Fix: Return empty map instead of null to avoid CancelledException
  if (song == null) return NotifiableFuture.fromValue(<String, dynamic>{});
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
    logger.log('Error in queueSongInfoRequest:', e, stackTrace);
    return NotifiableFuture.fromValue(<String, dynamic>{});
  }
}

/// Get song info from MusicBrainz or other sources.
Future<Map<String, dynamic>> getSongInfo(dynamic song) async {
  await cachedSongsList.ensureInitialized();
  try {
    // R2 fix: Return empty map for null input
    if (song == null) return <String, dynamic>{};
    if (song is String) {
      song = <String, dynamic>{'id': song};
      song['id'] = parseEntityId(song);
    }
    // R2 fix: Return empty map for non-Map input
    if (song is! Map) return <String, dynamic>{};
    song['id'] = parseEntityId(song);
    final offlineId = getUserOfflineSong(song);
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
  } catch (e, stackTrace) {
    logger.log('Error in getSongInfo:', e, stackTrace);
    // R2 fix: Return empty map on error
    return <String, dynamic>{};
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

/// Find song by ISRC code.
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
      for (final rec in recordings) {
        rec['artist'] = combineArtists(rec);
        if (song['ytid'] != null && song['ytid'].isNotEmpty)
          rec['ytid'] = song['ytid'];
        if ((rec['isrcs'] as List).contains(isrc)) {
          recording = await _getSongByRecordingDetails(rec);
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
    logger.log('Error in _findSongByIsrc:', e, stackTrace);
  }
  recording = Map<String, dynamic>.from(recording);
  return recording;
}

/// 8.2-C: Select optimal image from cover art images based on quality and type.
/// Prioritizes front cover art, then falls back to other images.
/// Prefers larger images when available.
Map<String, dynamic>? _selectOptimalImage(List<dynamic> images) {
  if (images.isEmpty) return null;
  
  // Priority order for image types
  const typePriority = ['Front', 'Back', 'Medium', 'Track'];
  
  // Try each type in priority order
  for (final type in typePriority) {
    final matchingImages = images.where((img) {
      final types = img['types'] as List? ?? [];
      return types.contains(type);
    }).toList();
    
    if (matchingImages.isNotEmpty) {
      // Sort by size preference (prefer larger)
      matchingImages.sort((a, b) {
        final aApproved = a['approved'] == true ? 1 : 0;
        final bApproved = b['approved'] == true ? 1 : 0;
        return bApproved.compareTo(aApproved); // Prefer approved images
      });
      return matchingImages.first;
    }
  }
  
  // Fallback to first approved image
  final approvedImages = images.where((img) => img['approved'] == true).toList();
  if (approvedImages.isNotEmpty) return approvedImages.first;
  
  // Last resort: return first image
  return images.first;
}

/// Get song by recording details from MusicBrainz.
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
            // 8.2-C: Parse images by quality and size preference
            final images = coverArt['images'] as List? ?? [];
            recording['images'] = _selectOptimalImage(images);
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
    logger.log('Error in _getSongByRecordingDetails:', e, stackTrace);
  }
  recording = Map<String, dynamic>.from(recording);
  return recording;
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

/// Find song from MusicBrainz by mbid or isrc.
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
                  ? 'artist:"${artists.first}"'
                  : 'recording:"$iTitle"';
          final qryResult =
              (await mb.recordings.search(artistQry, limit: 10))?['recordings']
               ?? [];
          final recordings = List<Map<String, dynamic>>.from(qryResult);
          for (final rec in recordings) {
            rec['artist'] = combineArtists(rec);
            if (rec['artist']?.toLowerCase().contains(iArtist.toLowerCase()) ??
                false) {
              song = await _getSongByRecordingDetails(rec);
              break;
            }
          }
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in _findMBSong:', e, stackTrace);
  }
  return song;
}
