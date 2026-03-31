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

import 'package:audio_service/audio_service.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/utils.dart';

// R4 fix: Extract shared image resolution helper to avoid divergence
String _resolveImagePath(Map song) {
  final _imagePath =
      song['validImage'] ??
      (song['image'] is String ? song['image'] : null) ??
      song['highResImage'] ??
      song['lowResImage'] ??
      song['offlineArtworkPath'];
  return (_imagePath != null && _imagePath is String)
      ? _imagePath
      : parseImage(song)?.first ?? '';
}

// R4 fix: Extract shared URI builder to avoid divergence
Uri? _buildArtUri(String imagePath) {
  if (imagePath.isEmpty) return null;
  if (isFilePath(imagePath) && doesFileExist(imagePath)) {
    return Uri.file(imagePath);
  }
  if (isUrl(imagePath)) {
    return Uri.parse(imagePath);
  }
  // R7 fix: Log unrecognized artUri strings for debugging
  logger.log('Unrecognized artUri format (not file or URL): $imagePath', null, null);
  return null;
}

// R4 fix: Extract shared extras builder
Map<String, dynamic> _buildMediaExtras(Map song, String imagePath) {
  return {
    'android.media.metadata.DURATION': (song['duration'] ?? 0) * 1000,
    'android.media.metadata.ART_URI': imagePath,
    'android.media.metadata.ALBUM_ART_URI': imagePath,
    'artistId': song['artistId'] ?? '',
    'lowResImage': song['lowResImage'] ?? '',
    'ytid': song['ytid'] ?? '',
    'isLive': song['isLive'] ?? false,
    'isOffline': song['isOffline'] ?? false,
    'artWorkPath': song['highResImage'] ?? '',
  };
}

// R5 fix: Mark as deprecated - only used for debugging, not in production flow
// R9 fix: Type return value as Map<String, dynamic>
@Deprecated('Only used for debugging. Will be removed in next release.')
Map<String, dynamic> mediaItemToMap(MediaItem mediaItem) => {
  'id': mediaItem.id,
  // R1 fix: Use null-aware operators with fallback defaults
  'ytid': mediaItem.extras?['ytid'] ?? '',
  'album': mediaItem.album?.toString() ?? '',
  'artist': mediaItem.artist?.toString() ?? '',
  'title': mediaItem.title,
  // R2 fix: Use null-safe optional chaining to prevent "null" string
  'highResImage': mediaItem.artUri?.toString() ?? '',
  'lowResImage': mediaItem.extras?['lowResImage'] ?? '',
  'isLive': mediaItem.extras?['isLive'] ?? false,
};

// R6 fix: Cache resolved image path and URI to avoid repeated I/O
MediaItem mapToMediaItem(Map song) {
  // Cache image resolution (R6 fix: eager caching)
  final imagePath = _resolveImagePath(song);
  final artUri = _buildArtUri(imagePath);
  
  return MediaItem(
    id: song['id'] ?? '',
    album: song['album'] ?? '',
    artist: song['artist'] ?? '',
    title: song['title'] ?? '',
    duration: Duration(seconds: song['duration'] ?? 0),
    artUri: artUri,
    // R4 fix: Use shared extras builder
    extras: _buildMediaExtras(song, imagePath),
  );
}

// R4/R6 fix: Use shared helpers for consistency
Map<String, dynamic> songToMediaExtras(Map song) {
  final imagePath = _resolveImagePath(song);
  return _buildMediaExtras(song, imagePath);
}
