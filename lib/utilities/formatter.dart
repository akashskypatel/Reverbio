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

import 'package:reverbio/utilities/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Map<String, dynamic> returnYtSongLayout(int index, Video song) {
  final songInfo = tryParseTitleAndArtist(song);
  return {
    'index': index,
    'id': 'yt=${song.id}',
    'ytid': song.id.toString(),
    'title': songInfo['title'],
    'source': 'youtube',
    'artist': songInfo['artist'],
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
  };
}

Map<String, dynamic> returnYTPlaylistLayout(Playlist playlist) {
  return {
    'id': 'yt=${playlist.id.value}',
    'ytid': playlist.id.value,
    'url': playlist.url,
    'author': playlist.author,
    'description': playlist.description,
    'title': playlist.title,
    'videoCount': playlist.videoCount,
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

String formatDuration(int audioDurationInSeconds) {
  final duration = Duration(seconds: audioDurationInSeconds);

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return [
    if (hours > 0) hours.toString().padLeft(2, '0'),
    minutes.toString().padLeft(2, '0'),
    seconds.toString().padLeft(2, '0'),
  ].join(':');
}
