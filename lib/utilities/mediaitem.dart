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

import 'package:audio_service/audio_service.dart';

Map mediaItemToMap(MediaItem mediaItem) => {
  'id': mediaItem.id,
  'ytid': mediaItem.extras!['ytid'],
  'album': mediaItem.album.toString(),
  'artist': mediaItem.artist.toString(),
  'title': mediaItem.title,
  'highResImage': mediaItem.artUri.toString(),
  'lowResImage': mediaItem.extras!['lowResImage'],
  'isLive': mediaItem.extras!['isLive'],
};

MediaItem mapToMediaItem(Map song) => MediaItem(
  id: song['id'].toString(),
  album: '',
  artist: song['artist'].toString().trim(),
  title: song['title'].toString(),
  artUri:
      song['isOffline'] ?? false
          ? Uri.file(song['highResImage'].toString())
          : Uri.parse(song['highResImage'].toString()),
  extras: {
    'artistId': song['artistId'],
    'lowResImage': song['lowResImage'],
    'ytid': song['ytid'],
    'isLive': song['isLive'],
    'isOffline': song['isOffline'],
    'artWorkPath': song['highResImage'].toString(),
  },
);

// Add this helper method to convert Media to MediaItem
Map<String, dynamic> songToMediaExtras(Map song) => {
  'id': song['id'].toString(),
  'album': '',
  'artist': song['artist'].toString().trim(),
  'title': song['title'].toString(),
  'artUri':
      song['isOffline'] ?? false
          ? Uri.file(song['highResImage'].toString())
          : Uri.parse(song['highResImage'].toString()),
  'extras': {
    'artistId': song['artistId'],
    'lowResImage': song['lowResImage'],
    'ytid': song['ytid'],
    'isLive': song['isLive'],
    'isOffline': song['isOffline'],
    'artWorkPath': song['highResImage'].toString(),
  },
};

MediaItem extrasToMediaItem(Map<String, dynamic> extras) => MediaItem(
  id: extras['id'],
  album: extras['album'],
  artist: extras['artist'],
  title: extras['title'],
  artUri: extras['artUri'],
  extras: {
    'artistId': extras['extras']['artistId'],
    'lowResImage': extras['extras']['lowResImage'],
    'ytid': extras['extras']['ytid'],
    'isLive': extras['extras']['isLive'],
    'isOffline': extras['extras']['isOffline'],
    'artWorkPath': extras['extras']['artWorkPath'],
  },
);
