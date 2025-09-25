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
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/DB/albums.db.dart';
import 'package:reverbio/DB/playlists.db.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

List dbPlaylists = [...playlistsDB, ...albumsDB];
List suggestedPlaylists = [];
List onlinePlaylists = [];
dynamic nextRecommendedSong;

bool isPlaylistAlreadyOffline(dynamic playlist) {
  final isOffline =
      userOfflinePlaylists.where((e) => e['id'] == playlist['id']).isNotEmpty;
  playlist['autoCacheOffline'] = isOffline;
  if (isOffline) {
    for (final song in (playlist['list'] ?? [])) {
      song['autoCacheOffline'] = playlist['autoCacheOffline'];
    }
  }
  return isOffline;
}

void updateOfflinePlaylist(dynamic playlist, bool add) {
  if (add)
    addOfflinePlaylist(playlist);
  else
    removeOfflinePlaylist(playlist);
}

Future<void> addOfflinePlaylist(dynamic playlist) async {
  final ids = Uri.parse('?${parseEntityId(playlist)}').queryParameters;
  if ((ids['yt'] ?? ids['mb'] ?? ids['uc']) != null) {
    userOfflinePlaylists.addOrUpdate(<String, dynamic>{
      'id': playlist['id'],
      'title': playlist['title'],
      'source': playlist['source'],
      'primary-type':
          ids['ytid'] != null ? 'playlist' : playlist['primary-type'],
    }, checkEntityId);
  }
}

Future<void> removeOfflinePlaylist(dynamic playlist) async {
  final ids = Uri.parse('?${parseEntityId(playlist)}').queryParameters;
  if ((ids['yt'] ?? ids['mb'] ?? ids['uc']) != null) {
    userOfflinePlaylists.removeWhere((e) => playlist['id'] == e['id']);
  }
}

Future<List<dynamic>> getUserYTPlaylists() async {
  final playlistsByUser = [];
  for (final playlistID in userPlaylists) {
    try {
      final plist = await yt.playlists.get(playlistID);
      playlistsByUser.add(<String, dynamic>{
        'id': 'yt=${plist.id}',
        'ytid': plist.id.toString(),
        'title': plist.title,
        'image': plist.thumbnails.standardResUrl,
        'lowResImage': plist.thumbnails.lowResUrl,
        'highResImage': plist.thumbnails.maxResUrl,
        'source': 'user-youtube',
        'primary-type': 'playlist',
        'list': [],
      });
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }
  return playlistsByUser;
}

String? youtubePlaylistParser(String url) {
  if (!youtubePlaylistValidate(url)) {
    return null;
  }

  final regExp = RegExp('[&?]list=([a-zA-Z0-9_-]+)');
  final match = regExp.firstMatch(url);

  return match?.group(1);
}

Future<String> addYTUserPlaylist(String input, BuildContext context) async {
  String? playlistId = input;

  if (input.startsWith('http://') || input.startsWith('https://')) {
    playlistId = youtubePlaylistParser(input);

    if (playlistId == null) {
      return '${context.l10n!.notYTlist}!';
    }
  }

  try {
    final _playlist = await yt.playlists.get(playlistId);

    if (userPlaylists.contains(playlistId)) {
      return '${context.l10n!.playlistAlreadyExists}!';
    }

    if (_playlist.title.isEmpty &&
        _playlist.author.isEmpty &&
        _playlist.videoCount == null) {
      return '${context.l10n!.invalidYouTubePlaylist}!';
    }
    await PM.triggerHook(returnYTPlaylistLayout(_playlist), 'onPlaylistAdd');
    userPlaylists.add(playlistId);
    return '${context.l10n!.playlist} ${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return '${context.l10n!.error}: $e';
  }
}

dynamic findPlaylistById(String playlistId) {
  dynamic existing = userCustomPlaylists.firstWhere(
    (value) => value['id'] == playlistId,
    orElse: () => {},
  );
  if (existing == null || existing.isEmpty) return null;
  existing = Map<String, dynamic>.from(existing);
  return existing;
}

dynamic findPlaylistByName(String playlistName) {
  dynamic existing = userCustomPlaylists.firstWhere(
    (value) => value['title'] == playlistName,
    orElse: () => {},
  );
  if (existing == null || existing.isEmpty) return null;
  existing = Map<String, dynamic>.from(existing);
  return existing;
}

List<String> getPlaylistNames() {
  return userCustomPlaylists.map((e) {
    return e['title'] as String;
  }).toList();
}

String sanitizePlaylistName(String playlistName) {
  final regExp = RegExp(r'[/\\:*?"<>|&=]');
  return playlistName.replaceAll(regExp, ' ').collapsed.replaceAll(' ', '_');
}

String generatePlaylistId(String playlistName) {
  return 'UC-${stableHash(sanitizePlaylistName(playlistName))}';
}

Future<void> updateCustomPlaylist(
  Map oldPlaylist,
  String playlistName, {
  String? imageUrl,
}) async {
  oldPlaylist.addAll({
    'title': playlistName,
    if (imageUrl != null) 'image': imageUrl,
  });
}

String createCustomPlaylist(
  String playlistName,
  BuildContext context, {
  String? image,
  List<dynamic>? songList,
}) {
  final id = generatePlaylistId(playlistName);
  final customPlaylist = <String, dynamic>{
    'id': 'uc=$id',
    'ucid': id,
    'title': playlistName,
    'source': 'user-created',
    'primary-type': 'playlist',
    if (image != null) 'image': image,
    'list': songList ?? [],
  };
  final existing = findPlaylistById(id);
  if (existing != null) {
    if (image != null) existing['image'] = image;
    existing['list'] = songList ?? [];
    return '${context.l10n!.playlist} ${context.l10n!.addedSuccess}!';
  }
  userCustomPlaylists.add(customPlaylist);
  return '${context.l10n!.playlist} ${context.l10n!.addedSuccess}!';
}

String addSongsToPlaylist(
  BuildContext context,
  String playlistName,
  List<dynamic> songList,
) {
  for (final song in songList) {
    addSongToCustomPlaylist(context, playlistName, song);
  }
  return context.l10n!.addedSuccess;
}

String addSongToCustomPlaylist(
  BuildContext context,
  String playlistName,
  Map song, {
  int? indexToInsert,
}) {
  final customPlaylist = userCustomPlaylists.firstWhere(
    (playlist) => playlist['title'] == playlistName,
    orElse: () => {},
  );

  if (customPlaylist.isNotEmpty) {
    final List<dynamic> playlistSongs = customPlaylist['list'];
    if (playlistSongs.any(
      (playlistElement) => checkSong(playlistElement, song),
    )) {
      return context.l10n!.songAlreadyInPlaylist;
    }
    PM.triggerHook(song, 'onPlaylistSongAdd');
    indexToInsert != null
        ? playlistSongs.insert(indexToInsert, song)
        : playlistSongs.add(song);
    return context.l10n!.songAdded;
  } else {
    logger.log('Custom playlist not found: $playlistName', null, null);
    return context.l10n!.error;
  }
}

bool removeSongFromPlaylist(
  Map playlist,
  Map songToRemove, {
  int? removeOneAtIndex,
}) {
  try {
    if (playlist['list'] == null) return false;

    final playlistSongs = List<dynamic>.from(playlist['list']);
    if (removeOneAtIndex != null) {
      if (removeOneAtIndex < 0 || removeOneAtIndex >= playlistSongs.length) {
        return false;
      }
      playlistSongs.removeAt(removeOneAtIndex);
    } else {
      final initialLength = playlistSongs.length;
      playlistSongs.removeWhere((s) => checkSong(s, songToRemove));
      if (playlistSongs.length == initialLength) return false;
    }

    playlist['list'] = playlistSongs;

    return true;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return false;
  }
}

void removeUserPlaylist(String playlistId) {
  userPlaylists.remove(playlistId);
}

void removeUserCustomPlaylist(dynamic playlist) {
  userCustomPlaylists.remove(playlist);
}

Future<bool> updatePlaylistLikeStatus(dynamic playlist, bool add) async {
  try {
    final playlistId = parseEntityId(playlist);
    if (playlist is Map) {
      playlist = Map<String, dynamic>.from(playlist);
      playlist['id'] = playlistId;
    }
    if (playlist is String)
      playlist = await getPlaylistInfoForWidget(playlistId);
    final ytid = Uri.parse('?$playlistId').queryParameters['yt'];
    if (ytid == null || ytid.isEmpty) return !add;
    if (add) {
      playlist['primary-type'] = playlist['primary-type'] ?? 'playlist';
      userLikedPlaylists.addOrUpdate(playlist, checkEntityId);
      await PM.triggerHook(playlist, 'onEntityLiked');
    } else {
      userLikedPlaylists.removeWhere((value) => checkPlaylist(playlist, value));
    }
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return !add;
  }
}

bool isPlaylistAlreadyLiked(playlistToCheck) {
  final liked =
      playlistToCheck is Map &&
      userLikedPlaylists.any(
        (playlist) => checkPlaylist(playlist, playlistToCheck),
      );
  return liked;
}

Future<List> getPlaylists({
  String? query,
  int? playlistsNum,
  bool onlyLiked = false,
  String type = 'all',
}) async {
  // Early exit if there are no playlists to process.
  if (dbPlaylists.isEmpty || (playlistsNum == null && query == null)) {
    return [];
  }

  // If a query is provided (without a limit), filter playlists based on the query and type,
  // and augment with online search results.
  if (query != null && playlistsNum == null) {
    final lowercaseQuery = query.toLowerCase();
    final filteredPlaylists =
        dbPlaylists.where((playlist) {
          final title = (playlist['title'] as String).toLowerCase();
          final matchesQuery = title.contains(lowercaseQuery);
          final matchesType =
              type == 'all' ||
              (type == 'album' && playlist['isAlbum'] == true) ||
              (type == 'playlist' && playlist['isAlbum'] != true);
          return matchesQuery && matchesType;
        }).toList();

    final searchTerm = type == 'album' ? '$query album' : query;
    final searchResults = await yt.search.searchContent(
      searchTerm,
      filter: TypeFilters.playlist,
    );

    // Avoid duplicate online playlists.
    final existingYtIds = onlinePlaylists.map((p) => p['id'] as String).toSet();

    final newPlaylists =
        searchResults
            .whereType<SearchPlaylist>()
            .map((playlist) {
              final playlistMap = {
                'id': 'yt=${playlist.id}',
                'ytid': playlist.id.toString(),
                'title': playlist.title,
                'source': 'youtube',
                'list': [],
                'primary-type': 'playlist',
              };
              if (!existingYtIds.contains(playlistMap['id'])) {
                existingYtIds.add(playlistMap['id'].toString());
                return playlistMap;
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
    onlinePlaylists.addAll(newPlaylists);

    // Merge online playlists that match the query.
    filteredPlaylists.addAll(
      onlinePlaylists
          .where((p) => p['title'].toLowerCase().contains(lowercaseQuery))
          .map((value) {
            value['primary-type'] = 'playlist';
            value = Map<String, dynamic>.from(value);
            return value;
          })
          .toList(),
    );
    return filteredPlaylists;
  }

  // If a specific number of playlists is requested (without a query),
  // return a shuffled subset of suggested playlists.
  if (playlistsNum != null && query == null) {
    suggestedPlaylists = List.from(dbPlaylists)..shuffle();
    return suggestedPlaylists.take(playlistsNum).map((value) {
      value['primary-type'] = 'playlist';
      value = Map<String, dynamic>.from(value);
      return value;
    }).toList();
  }

  // If only liked playlists should be returned, ignore other parameters.
  if (onlyLiked && playlistsNum == null && query == null) {
    return userLikedPlaylists;
  }

  // If a specific type is requested, filter accordingly.
  if (type != 'all') {
    return dbPlaylists
        .where((playlist) {
          return type == 'album'
              ? playlist['isAlbum'] == true
              : playlist['isAlbum'] != true;
        })
        .map((value) {
          value['primary-type'] = 'playlist';
          value = Map<String, dynamic>.from(value);
          return value;
        })
        .toList();
  }

  // Default to returning all playlists.
  return dbPlaylists;
}

Future<List> getSongsFromPlaylist(dynamic playlistId) async {
  final songList =
      ((await HiveService.getData<List<Map<String, dynamic>>>(
                'cache',
                'playlistSongs$playlistId',
              )) ??
              [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  String id;
  if (playlistId.toString().contains('yt=')) {
    id = Uri.parse('?$playlistId').queryParameters['yt'] ?? '';
  } else {
    id = playlistId;
  }

  if (songList.isEmpty) {
    await for (final song in yt.playlists.getVideos(id)) {
      songList.add(returnYtSongLayout(song));
    }
  }
  return songList;
}

Future updatePlaylistList(BuildContext context, String playlistId) async {
  final index = findPlaylistIndexByYtId(playlistId);
  if (index != -1) {
    final songList = [];
    await for (final song in yt.playlists.getVideos(playlistId)) {
      songList.add(returnYtSongLayout(song));
    }

    dbPlaylists[index]['list'] = songList;
    showToast(context.l10n!.playlistUpdated);
    return dbPlaylists[index];
  }
}

int findPlaylistIndexByYtId(String ytid) {
  return dbPlaylists.indexWhere((playlist) => playlist['ytid'] == ytid);
}

Future<Map?> getPlaylistInfo(Map playlist) async {
  dynamic data;
  final ids = Uri.parse('?${parseEntityId(playlist)}').queryParameters;
  if (playlist['source'] == 'user-created')
    data = findPlaylistById(playlist['id']);
  // ignore: unnecessary_null_comparison
  else if (data == null && (ids['yt'] != null || playlist['ytid'] != null))
    data = await getPlaylistInfoForWidget(Map<String, dynamic>.from(playlist));
  else if ([
    'artist',
    'album',
    'single',
    'ep',
    'broadcast',
    'other',
  ].contains(playlist['primary-type']?.toLowerCase()))
    data = await queueAlbumInfoRequest(playlist['id']).completerFuture;
  else
    data = playlist;
  return data;
}

Future<dynamic> getPlaylistInfoForWidget(
  dynamic playlistData, {
  bool isArtist = false,
}) async {
  final id = parseEntityId(playlistData);
  final ids = id.toIds;
  final ytid = (ids['yt'] ?? id).ytid;
  final mbid = (ids['mb'] ?? id).mbid;
  if (id.isEmpty) return {};
  if (playlistData is String)
    playlistData = <String, dynamic>{'id': id, 'ytid': ytid};
  if (mbid.isNotEmpty) {
    await queueAlbumInfoRequest(playlistData).completerFuture?.then((value) {
      if (value != null) playlistData.addAll(value);
    });
    return playlistData;
  }
  Map<String, dynamic> playlist;

  // Check in local playlists.
  playlist = Map<String, dynamic>.from(
    dbPlaylists.firstWhere((p) => checkEntityId(p['id'], id), orElse: () => {}),
  );

  // Check in user playlists if not found.
  if (playlist.isEmpty) {
    final userPl = await getUserYTPlaylists();
    playlist = Map<String, dynamic>.from(
      userPl.firstWhere((p) => checkEntityId(p['id'], id), orElse: () => {}),
    );
  }

  // Check in cached online playlists if still not found.
  if (playlist.isEmpty) {
    playlist = Map<String, dynamic>.from(
      onlinePlaylists.firstWhere(
        (p) => checkEntityId(p['id'], id),
        orElse: () => {},
      ),
    );
  }

  // If still not found, attempt to fetch playlist info.
  if (playlist.isEmpty && ytid.isNotEmpty) {
    try {
      final ytPlaylist = await yt.playlists.get(ytid);
      playlist = <String, dynamic>{
        'id': 'yt=${ytPlaylist.id}',
        'ytid': ytPlaylist.id.toString(),
        'title': ytPlaylist.title,
        'image': null,
        'source': 'user-youtube',
        'list': [],
      };
      onlinePlaylists.add(playlist);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return playlistData;
    }
  }
  // If the playlist exists but its song list is empty, fetch and cache the songs.
  if (playlist.isEmpty) return playlistData;
  if (playlistData['isAlbum'] != null && playlistData['isAlbum'])
    playlist['album'] = playlist['title'];
  if ((playlist['list'].isEmpty || playlist['list'] == null) &&
      ytid.isNotEmpty) {
    playlist['list'] = await getSongsFromPlaylist(playlist['id']);
    playlistData.addAll(Map<String, dynamic>.from(playlist));
  }
  return playlistData as Map<String, dynamic>;
}

int? getPlaylistHashCode(dynamic playlist) {
  if (!(playlist is Map)) return null;
  if (playlist['title'] == null) return null;
  if (playlist['artist'] == null)
    return playlist['title'].toLowerCase().hashCode;
  return playlist['title'].toLowerCase().hashCode ^
      playlist['artist'].toLowerCase().hashCode;
}

bool checkPlaylist(dynamic playlist, dynamic otherPlaylist) {
  if (playlist == null || otherPlaylist == null) return false;
  if (playlist['id'] == null || otherPlaylist['id'] == null)
    return getPlaylistHashCode(playlist) == getPlaylistHashCode(otherPlaylist);
  parseEntityId(playlist);
  parseEntityId(otherPlaylist);
  return checkEntityId(playlist['id'], otherPlaylist['id']);
}

String _standardizeFieldName(String originalName) {
  const _fieldMappings = {
    'Arist(s) Name': 'artist',
    'Track Name': 'title',
    'Album Name': 'album',
    'Spotify Track Id': 'spotifyId',
    'SpotifyID': 'spotifyId',
    'Track URI': 'spotifyId',
    'Artist Name(s)': 'artist',
    'artist': 'artist',
    'arist': 'artist',
    'song': 'title',
    'track': 'title',
    'album': 'album',
    'duration': 'duration',
    'length': 'duration',
    'time': 'duration',
  };
  final lowerName = originalName.toLowerCase().trim().collapsed.replaceAll(
    ' ',
    '_',
  );

  if (_fieldMappings.containsKey(originalName)) {
    return _fieldMappings[originalName] ?? originalName;
  }

  if (_fieldMappings.containsKey(lowerName)) {
    return _fieldMappings[lowerName] ?? lowerName;
  }

  return lowerName;
}

Future<bool> uploadCsvPlaylist(BuildContext context) async {
  int fileCount = 0;
  int count = 0;
  try {
    final _dir = Directory(offlineDirectory.value!);
    final _importsDirPath = '${_dir.path}${Platform.pathSeparator}imports';
    final files =
        (await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        ))?.files;
    if (files == null || files.isEmpty) return false;
    fileCount = files.length;
    for (final f in files) {
      if (f.path == null) continue;
      final file = await copyFileToDir(f.path!, _importsDirPath);
      final rows = const CsvToListConverter(eol: '\n').convert(
        (await file.readAsString())
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n'),
      );
      final headers =
          rows.first.map((e) => _standardizeFieldName(e.toString())).toList();
      if (!headers.contains('artist') || !headers.contains('title')) {
        logger.log(
          'File does not contain required fields Artist, Song Title, and ISRC (if possible): ${file.path} - $headers',
          null,
          null,
        );
        continue;
      }
      final list = [];
      for (final row in rows.skip(1)) {
        int i = 0;
        final map = row.fold(<String, dynamic>{}, (map, e) {
          if (headers[i] == 'duration')
            map[headers[i]] =
                parseTimeStringToSeconds(e.toString().trim()) ?? 0;
          else if (headers[i] == 'duration_(ms)')
            map[headers[i]] = (int.tryParse(e.toString().trim()) ?? 0) ~/ 1000;
          else
            map[headers[i]] = e.toString().trim();
          i++;
          return map;
        });
        list.add(map);
      }
      final baseFileName = basenameWithoutExtension(file.path);
      final playlistName =
          findPlaylistByName(baseFileName) == null
              ? baseFileName
              : incrementFileName(baseFileName);
      createCustomPlaylist(
        '$playlistName (${context.l10n!.imported})',
        context,
        songList: list,
      );
      unawaited(file.delete());
      count++;
    }
    showToast(
      '${context.l10n!.addedPlaylistFiles}: $count/$fileCount',
      context: context,
    );
    unawaited(clearFilePickerTempFiles());
  } catch (e, stackTrace) {
    showToast(
      '${context.l10n!.addedSomePlaylistFiles}: $count/$fileCount',
      context: context,
    );
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return false;
  }
  return true;
}
