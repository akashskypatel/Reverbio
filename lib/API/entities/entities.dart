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

import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/DB/albums.db.dart';
import 'package:reverbio/DB/playlists.db.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/utilities/notifiable_list.dart';

// A2 fix: Moved from playlist.dart to break song.dart <-> playlist.dart cycle
List dbPlaylists = [...playlistsDB, ...albumsDB];
dynamic nextRecommendedSong;

Future<void> initializeData() async {
  // R7 fix: Use Future.wait for parallel initialization of independent lists
  await Future.wait([
    userLikedSongsList.ensureInitialized(),
    cachedSongsList.ensureInitialized(),
    userOfflineSongs.ensureInitialized(),
    userLikedAlbumsList.ensureInitialized(),
    cachedAlbumsList.ensureInitialized(),
    userLikedArtistsList.ensureInitialized(),
    cachedArtistsList.ensureInitialized(),
    userPlaylists.ensureInitialized(),
    userCustomPlaylists.ensureInitialized(),
    userOfflinePlaylists.ensureInitialized(),
    userLikedPlaylists.ensureInitialized(),
    userRecentlyPlayed.ensureInitialized(),
    searchHistory.ensureInitialized(),
    userDeviceSongs.ensureInitialized(),
  ]);
  
  // R4 fix: Evict cached items older than 30 days
  evictOldCachedItems();
}

// R4 fix: Evict cached items older than 30 days
void evictOldCachedItems() {
  const cacheTTL = Duration(days: 30);
  cachedSongsList.evictOlderThan(cacheTTL);
  cachedAlbumsList.evictOlderThan(cacheTTL);
  cachedArtistsList.evictOlderThan(cacheTTL);
}

void disposeData() {
  userLikedSongsList.dispose();
  cachedSongsList.dispose();
  userOfflineSongs.dispose();
  userLikedAlbumsList.dispose();
  cachedAlbumsList.dispose();
  userLikedArtistsList.dispose();
  cachedArtistsList.dispose();
  userPlaylists.dispose();
  userCustomPlaylists.dispose();
  userOfflinePlaylists.dispose();
  userLikedPlaylists.dispose();
  userRecentlyPlayed.dispose();
  searchHistory.dispose();
  userDeviceSongs.dispose();
}

// R5/R6 fix: Minimize function for playlists - strips 'list' field to save space
Map<String, dynamic> _minimizePlaylistData(dynamic playlist) {
  return {
    'id': playlist['id'],
    'primary-type': playlist['primary-type'] ?? 'playlist',
    'title': playlist['title'] ?? playlist['name'],
    'artist': playlist['artist'],
    'source': playlist['source'],
    'entity': playlist['entity'],
    'videoCount': playlist['videoCount'],
    'cachedAt': DateTime.now().toString(),
    'image': playlist['image'] ?? playlist['thumbnail'],
  };
}

final NotifiableList<Map<String, dynamic>> userLikedSongsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.user,
      'likedSongs',
      minimizeFunction: minimizeSongData,
    );
final NotifiableList<Map<String, dynamic>> cachedSongsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.cache,
      'cachedSongs',
      minimizeFunction: minimizeSongData,
    );
final NotifiableList<String> userOfflineSongs = NotifiableList<String>.fromHive(
  HiveBoxNames.userNoBackup,
  'offlineSongs',
);
final NotifiableList<Map<String, dynamic>> userLikedAlbumsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.user,
      'likedAlbums',
      minimizeFunction: minimizeAlbumData,
    );
final NotifiableList<Map<String, dynamic>> cachedAlbumsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.cache,
      'cachedAlbums',
      minimizeFunction: minimizeAlbumData,
    );
final NotifiableList<Map<String, dynamic>> userLikedArtistsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.user,
      'likedArtists',
      minimizeFunction: minimizeArtistData,
    );
final NotifiableList<Map<String, dynamic>> cachedArtistsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.cache,
      'cachedArtists',
      minimizeFunction: minimizeArtistData,
    );
final NotifiableList<String> userPlaylists = NotifiableList<String>.fromHive(
  HiveBoxNames.user,
  'playlists',
);
final NotifiableList<Map<String, dynamic>> userCustomPlaylists =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.user,
      'customPlaylists',
      minimizeFunction: _minimizePlaylistData,
    );
final NotifiableList<Map<String, dynamic>> userOfflinePlaylists =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.user,
      'offlinePlaylists',
      minimizeFunction: _minimizePlaylistData,
    );
final NotifiableList<Map<String, dynamic>> userLikedPlaylists =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.user,
      'likedPlaylists',
      minimizeFunction: _minimizePlaylistData,
    );
final NotifiableList<Map<String, dynamic>> userRecentlyPlayed =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.user,
      'recentlyPlayedSongs',
      minimizeFunction: minimizeSongData,
    );
final NotifiableList<String> searchHistory = NotifiableList<String>.fromHive(
  HiveBoxNames.user,
  'searchHistory',
);
final NotifiableList<Map<String, dynamic>> userDeviceSongs =
    NotifiableList<Map<String, dynamic>>.fromHive(
      HiveBoxNames.userNoBackup,
      'userDeviceSongs',
      minimizeFunction: minimizeSongData,
    );
