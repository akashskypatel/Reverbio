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

import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Map<String, dynamic> returnYtSongLayout(Video song) {
  final songInfo = tryParseVideoTitleAndArtist(song);
  // R6 fix: Add 'album' key with empty fallback
  final album = songInfo['album'] ?? '';
  return {
    'id': 'yt=${song.id}',
    'ytid': song.id.toString(),
    'title': songInfo['title'],
    'artist': songInfo['artist'],
    'album': album,  // R6 fix: Add album key
    'ytTitle': song.title,
    'ytArtist': song.author,
    'source': 'youtube',
    'image': song.thumbnails.standardResUrl,
    'lowResImage': song.thumbnails.lowResUrl,
    'highResImage': song.thumbnails.maxResUrl,
    'duration': song.duration?.inSeconds,
    'isLive': song.isLive,
    'primary-type': 'song',
    'channelName': song.author,
    'channelId': song.channelId.value,
    'views': song.engagement.viewCount,
    'isError': false,
    // R1 fix: Pass album from songInfo (may be empty, but at least it's the correct field)
    'isDerivative': isSongDerivativeFromTitle(
      songInfo['artist'],
      album,  // R1 fix: Use album from songInfo
      songInfo['title'],
      song.title,
    ),
  };
}

// R7 fix: Consistent naming - returnYtPlaylistLayout (lowercase 't')
Map<String, dynamic> returnYtPlaylistLayout(Playlist playlist) {
  // R4 fix: Add 'primary-type' key to match codebase convention
  return {
    'id': 'yt=${playlist.id.value}',
    'ytid': playlist.id.value,
    'url': playlist.url,
    'author': playlist.author,
    'description': playlist.description,
    'title': playlist.title,
    'videoCount': playlist.videoCount,
    'primary-type': 'playlist',  // R4 fix: Add primary-type
    'engagement': {
      'avgRating': playlist.engagement.avgRating,
      'dislikeCount': playlist.engagement.dislikeCount,
      'likeCount': playlist.engagement.likeCount,
      'viewCount': playlist.engagement.viewCount,
    },
    'images': {
      'highResUrl': playlist.thumbnails.highResUrl,
      'lowResUrl': playlist.thumbnails.lowResUrl,
      'maxResUrl': playlist.thumbnails.maxResUrl,
      'mediumResUrl': playlist.thumbnails.mediumResUrl,
      'standardResUrl': playlist.thumbnails.standardResUrl,
      'videoId': playlist.thumbnails.videoId,
    },
  };
}

// R5 fix: Handle negative input by clamping to zero
// R2 fix: Changed parameter to int (non-nullable) - callers must ensure non-null
String formatDuration(int audioDurationInSeconds) {
  // R5 fix: Clamp to zero for negative input
  final clampedDuration = audioDurationInSeconds < 0 ? 0 : audioDurationInSeconds;
  final duration = Duration(seconds: clampedDuration);

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return [
    if (hours > 0) hours.toString().padLeft(2, '0'),
    minutes.toString().padLeft(2, '0'),
    seconds.toString().padLeft(2, '0'),
  ].join(':');
}
