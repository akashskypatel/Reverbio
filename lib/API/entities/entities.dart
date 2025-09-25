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
import 'package:reverbio/utilities/notifiable_list.dart';

Future<void> initializeData() async {
  await userLikedSongsList.ensureInitialized();
  await cachedSongsList.ensureInitialized();
  await userOfflineSongs.ensureInitialized();
  await userLikedAlbumsList.ensureInitialized();
  await cachedAlbumsList.ensureInitialized();
  await userLikedArtistsList.ensureInitialized();
  await cachedArtistsList.ensureInitialized();
  await userPlaylists.ensureInitialized();
  await userCustomPlaylists.ensureInitialized();
  await userOfflinePlaylists.ensureInitialized();
  await userLikedPlaylists.ensureInitialized();
  await userRecentlyPlayed.ensureInitialized();
  await searchHistory.ensureInitialized();
  await userDeviceSongs.ensureInitialized();
}

final NotifiableList<Map<String, dynamic>> userLikedSongsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'user',
      'likedSongs',
      minimizeFunction: minimizeSongData,
    ); // convert to List<String>
final NotifiableList<Map<String, dynamic>> cachedSongsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'cache',
      'cachedSongs',
      minimizeFunction: minimizeSongData,
    );
final NotifiableList<String> userOfflineSongs = NotifiableList<String>.fromHive(
  'userNoBackup',
  'offlineSongs',
);
final NotifiableList<Map<String, dynamic>> userLikedAlbumsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'user',
      'likedAlbums',
      minimizeFunction: minimizeAlbumData,
    ); // convert to List<String>
final NotifiableList<Map<String, dynamic>> cachedAlbumsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'cache',
      'cachedAlbums',
      minimizeFunction: minimizeAlbumData,
    );
final NotifiableList<Map<String, dynamic>> userLikedArtistsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'user',
      'likedArtists',
      minimizeFunction: minimizeArtistData,
    ); // convert to List<String>
final NotifiableList<Map<String, dynamic>> cachedArtistsList =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'cache',
      'cachedArtists',
      minimizeFunction: minimizeArtistData,
    );
final NotifiableList<String> userPlaylists = NotifiableList<String>.fromHive(
  'user',
  'playlists',
);
final NotifiableList<Map<String, dynamic>> userCustomPlaylists =
    NotifiableList<Map<String, dynamic>>.fromHive('user', 'customPlaylists');
final NotifiableList<Map<String, dynamic>> userOfflinePlaylists =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'user',
      'offlinePlaylists',
    ); // convert to List<String>
final NotifiableList<Map<String, dynamic>> userLikedPlaylists =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'user',
      'likedPlaylists',
    ); // convert to List<String>
final NotifiableList<Map<String, dynamic>> userRecentlyPlayed =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'user',
      'recentlyPlayedSongs',
      minimizeFunction: minimizeSongData,
    ); // convert to List<String>
final NotifiableList<String> searchHistory = NotifiableList<String>.fromHive(
  'user',
  'searchHistory',
);
final NotifiableList<Map<String, dynamic>> userDeviceSongs =
    NotifiableList<Map<String, dynamic>>.fromHive(
      'userNoBackup',
      'userDeviceSongs',
      minimizeFunction: minimizeSongData,
    );
