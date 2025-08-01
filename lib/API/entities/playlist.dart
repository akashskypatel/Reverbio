import 'dart:async';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/DB/albums.db.dart';
import 'package:reverbio/DB/playlists.db.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

List dbPlaylists = [...playlistsDB, ...albumsDB];
final userPlaylists = ValueNotifier<List>(
  Hive.box('user').get('playlists', defaultValue: []),
);
final userCustomPlaylists = ValueNotifier<List>(
  Hive.box('user').get('customPlaylists', defaultValue: []),
);
List userLikedPlaylists = Hive.box(
  'user',
).get('likedPlaylists', defaultValue: []);
List userRecentlyPlayed = Hive.box(
  'user',
).get('recentlyPlayedSongs', defaultValue: []);
List suggestedPlaylists = [];
List onlinePlaylists = [];

dynamic nextRecommendedSong;

final ValueNotifier<int> currentLikedPlaylistsLength = ValueNotifier(
  userLikedPlaylists.length,
);

/* Future<void> playPlaylistSong({
  Map<dynamic, dynamic>? playlist,
  required int songIndex,
}) async {
  if (playlist != null && playlist['list'] != activeQueue['list'])
    setQueueToPlaylist(playlist);
  if (activeQueue['list'].isNotEmpty) {
    activeSongId = songIndex;
    await audioHandler.queueSong(activeQueue['list'][activeSongId], play: true);
  }
} */

Future<List<dynamic>> getUserYTPlaylists() async {
  final playlistsByUser = [];
  for (final playlistID in userPlaylists.value) {
    try {
      final plist = await yt.playlists.get(playlistID);
      playlistsByUser.add({
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
      playlistsByUser.add({
        'id': 'yt=$playlistID',
        'ytid': playlistID.toString(),
        'title': 'Failed playlist',
        'image': null,
        'source': 'user-youtube',
        'primary-type': 'playlist',
        'list': [],
      });
      logger.log('Error occurred while fetching the playlist:', e, stackTrace);
    }
  }
  return playlistsByUser;
}

String? youtubePlaylistParser(String url) {
  if (!youtubeValidate(url)) {
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

    if (userPlaylists.value.contains(playlistId)) {
      return '${context.l10n!.playlistAlreadyExists}!';
    }

    if (_playlist.title.isEmpty &&
        _playlist.author.isEmpty &&
        _playlist.videoCount == null) {
      return '${context.l10n!.invalidYouTubePlaylist}!';
    }
    PM.triggerHook(returnYTPlaylistLayout(_playlist), 'onPlaylistAdd');
    userPlaylists.value = [...userPlaylists.value, playlistId];
    addOrUpdateData('user', 'playlists', userPlaylists.value);
    return '${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return '${context.l10n!.error}: $e';
  }
}

dynamic findPlaylistByName(String playlistName) {
  final existing = userCustomPlaylists.value.where(
    (value) => value['title'] == playlistName,
  );
  return existing.isNotEmpty ? existing.first : null;
}

List<String> getPlaylistNames() {
  return userCustomPlaylists.value.map((e) {
    return e['title'] as String;
  }).toList();
}

String createCustomPlaylist(
  String playlistName,
  BuildContext context, {
  String? image,
  List<dynamic>? songList,
}) {
  final customPlaylist = {
    'id': 'uc=${playlistName.replaceAll(r'\s+', '_')}',
    'title': playlistName,
    'source': 'user-created',
    'primary-type': 'playlist',
    if (image != null) 'image': image,
    'list': songList ?? [],
  };
  final existing = findPlaylistByName(playlistName);
  if (existing != null) {
    if (image != null) existing['image'] = image;
    existing['list'] = songList ?? [];
    addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
    return '${context.l10n!.addedSuccess}!';
  }
  userCustomPlaylists.value = [...userCustomPlaylists.value, customPlaylist];
  addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
  return '${context.l10n!.addedSuccess}!';
}

String addSongsToPlaylist(
  BuildContext context,
  String playlistName,
  List<dynamic> songList,
) {
  for (final song in songList) {
    addSongInCustomPlaylist(context, playlistName, song);
  }
  return context.l10n!.addedSuccess;
}

String addSongInCustomPlaylist(
  BuildContext context,
  String playlistName,
  Map song, {
  int? indexToInsert,
}) {
  final customPlaylist = userCustomPlaylists.value.firstWhere(
    (playlist) => playlist['title'] == playlistName,
    orElse: () => null,
  );

  if (customPlaylist != null) {
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
    addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
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

    if (playlist['source'] == 'user-created') {
      addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
    } else {
      addOrUpdateData('user', 'playlists', userPlaylists.value);
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return false;
  }
}

void removeUserPlaylist(String playlistId) {
  final updatedPlaylists = List.from(userPlaylists.value)..remove(playlistId);
  userPlaylists.value = updatedPlaylists;
  addOrUpdateData('user', 'playlists', userPlaylists.value);
}

void removeUserCustomPlaylist(dynamic playlist) {
  final updatedPlaylists = List.from(userCustomPlaylists.value)
    ..remove(playlist);
  userCustomPlaylists.value = updatedPlaylists;
  addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
}

Future<bool> updatePlaylistLikeStatus(dynamic playlist, bool add) async {
  try {
    final playlistId = parseEntityId(playlist);
    if (playlist is Map) playlist['id'] = playlistId;
    if (playlist is String)
      playlist = await getPlaylistInfoForWidget(playlistId);
    final ytid = Uri.parse('?$playlistId').queryParameters['yt'];
    if (ytid == null || ytid.isEmpty) return !add;
    if (add) {
      userLikedPlaylists.addOrUpdate('id', playlistId, playlist);
      currentLikedPlaylistsLength.value = userLikedPlaylists.length;
      PM.triggerHook(playlist, 'onEntityLiked');
    } else {
      userLikedPlaylists.removeWhere((value) => checkPlaylist(playlist, value));
      currentLikedPlaylistsLength.value--;
    }
    addOrUpdateData('user', 'likedPlaylists', userLikedPlaylists);
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return !add;
  }
}

bool isPlaylistAlreadyLiked(playlistToCheck) =>
    playlistToCheck is Map &&
    userLikedPlaylists.any(
      (playlist) => playlist is Map && checkPlaylist(playlist, playlistToCheck),
    );

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
          return value;
        })
        .toList();
  }

  // Default to returning all playlists.
  return dbPlaylists;
}

Future<List<SongBar>> getSongBarsFromPlaylist(dynamic playlistData) async {
  if (playlistData is String ||
      playlistData['list'] == null ||
      playlistData['list'].isEmpty)
    playlistData = await getPlaylistInfoForWidget(playlistData);
  if (playlistData['list'] == null || playlistData['list'].isEmpty) return [];
  int index = 0;
  final totalLength = (playlistData['list'] as List).length;
  return (playlistData['list'] as List).map((e) {
    final bar = SongBar(
      e,
      borderRadius: getItemBorderRadius(index, totalLength),
      showMusicDuration: true,
    );
    index++;
    return bar;
  }).toList();
}

Future<List> getSongsFromPlaylist(dynamic playlistId) async {
  final songList = await getData('cache', 'playlistSongs$playlistId') ?? [];
  String id;
  if (playlistId.toString().contains('yt=')) {
    id = Uri.parse('?$playlistId').queryParameters['yt'] ?? '';
  } else {
    id = playlistId;
  }

  if (songList.isEmpty) {
    await for (final song in yt.playlists.getVideos(id)) {
      songList.add(returnYtSongLayout(songList.length, song));
    }
    addOrUpdateData('cache', 'playlistSongs$playlistId', songList);
  }

  return songList;
}

Future updatePlaylistList(BuildContext context, String playlistId) async {
  final index = findPlaylistIndexByYtId(playlistId);
  if (index != -1) {
    final songList = [];
    await for (final song in yt.playlists.getVideos(playlistId)) {
      songList.add(returnYtSongLayout(songList.length, song));
    }

    dbPlaylists[index]['list'] = songList;
    addOrUpdateData('cache', 'playlistSongs$playlistId', songList);
    showToast(context.l10n!.playlistUpdated);
    return dbPlaylists[index];
  }
}

int findPlaylistIndexByYtId(String ytid) {
  return dbPlaylists.indexWhere((playlist) => playlist['ytid'] == ytid);
}

/* Future<void> setActivePlaylist(Map info) async {
  activeQueue = info;
  activeSongId = 0;

  await audioHandler.playSong(activeQueue['list'][activeSongId]);
} */

Future<Map> getPlaylistInfoForWidget(
  dynamic playlistData, {
  bool isArtist = false,
}) async {
  final id =
      playlistData is String
          ? Uri.parse('?${parseEntityId(playlistData)}').queryParameters['yt']
          : playlistData['ytid'] as String? ?? playlistData['id'] as String?;
  if (id == null || id.isEmpty) return {};
  if (isArtist) {
    return {'title': id, 'list': await getSongsList(id)};
  }
  if (playlistData is String) playlistData = {'id': 'yt=$id', 'ytid': id};
  Map? playlist;

  // Check in local playlists.
  playlist = dbPlaylists.firstWhere((p) => p['ytid'] == id, orElse: () => null);

  // Check in user playlists if not found.
  if (playlist == null) {
    final userPl = await getUserYTPlaylists();
    playlist = userPl.firstWhere((p) => p['ytid'] == id, orElse: () => null);
  }

  // Check in cached online playlists if still not found.
  playlist ??= onlinePlaylists.firstWhere(
    (p) => p['ytid'] == id,
    orElse: () => null,
  );

  // If still not found, attempt to fetch playlist info.
  if (playlist == null) {
    try {
      final ytPlaylist = await yt.playlists.get(id);
      playlist = {
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
      return {};
    }
  }
  // If the playlist exists but its song list is empty, fetch and cache the songs.
  if (playlist['list'] == null ||
      (playlist['list'] is List && (playlist['list'] as List).isEmpty)) {
    playlist['list'] = await getSongsFromPlaylist(playlist['id']);
    if (playlistData['isAlbum'] != null &&
        playlistData['isAlbum'] &&
        (playlistData['artist'].toString() == 'null' ||
            playlistData['artist'].toString().isEmpty)) {
      final strings = playlistData['title'].toString().split('-');
      final albumInfo = Map<String, dynamic>.from(
        await findMBAlbum(strings.first.trim(), artist: strings.last.trim()),
      );
      if (albumInfo.isNotEmpty) {
        playlist = Map<String, dynamic>.from(playlist)..addAll(albumInfo);
        for (final song in playlist['list']) {
          song['artist-details'] = albumInfo['artist-details'];
          song['artist'] = albumInfo['artist'];
        }
      }
    } else {
      playlist['artists'] =
          playlist['list']
              .map((song) => (song['artist'] as String).trim())
              .toSet()
              .toList();
      if (playlist['artists'].length == 1)
        playlist['artist'] = playlist['artists'].first;
    }
    if (!dbPlaylists.contains(playlist)) {
      dbPlaylists.add(playlist);
    }
  }
  if (playlistData['isAlbum'] != null && playlistData['isAlbum'])
    playlist['album'] = playlist['title'];
  return playlist;
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
  final lowerName = originalName
      .toLowerCase()
      .trim()
      .replaceAll(r'\s+', ' ')
      .trim()
      .replaceAll(' ', '_');

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
    final _dir = await getApplicationSupportDirectory();
    final _importsDirPath = '${_dir.path}/imports';
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
