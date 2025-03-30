import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/DB/albums.db.dart';
import 'package:reverbio/DB/playlists.db.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
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

late final ValueNotifier<int> currentLikedPlaylistsLength;

void addSongsToQueue(List<dynamic> songs) {
  for (final song in songs) {
    addSongToQueue(song);
  }  
}

dynamic addSongToQueue(dynamic song) {
  if (!isSongInQueue(song)) {
    activeQueue['list'].add(song);
    activeQueueLength.value = activeQueue['list'].length;
  }
}

bool removeSongFromQueue(dynamic song) {
  final val = activeQueue['list'].remove(song);
  activeQueueLength.value = activeQueue['list'].length;
  return val;
}

bool isSongInQueue(dynamic song) {
  return activeQueue['list'].contains(song);
}

void setQueueToPlaylist(dynamic playlist) {
  activeQueue.addAll(playlist);
  activeQueueLength.value = activeQueue['list'].length;
}

void clearSongQueue() {
  activeQueue['id'] = '';
  activeQueue['ytid'] = '';
  activeQueue['title'] = 'No Songs in Queue';
  activeQueue['image'] = '';
  activeQueue['source'] = '';
  activeQueue['list'].clear();
  activeQueueLength.value = 0;
}

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

Future<List<dynamic>> getUserPlaylists() async {
  final playlistsByUser = [];
  for (final playlistID in userPlaylists.value) {
    try {
      final plist = await yt.playlists.get(playlistID);
      playlistsByUser.add({
        'id': 'yt=${plist.id}',
        'ytid': plist.id.toString(),
        'title': plist.title,
        'image': null,
        'source': 'user-youtube',
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

Future<String> addUserPlaylist(String input, BuildContext context) async {
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

    userPlaylists.value = [...userPlaylists.value, playlistId];
    addOrUpdateData('user', 'playlists', userPlaylists.value);
    return '${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return '${context.l10n!.error}: $e';
  }
}

String createCustomPlaylist(
  String playlistName,
  String? image,
  BuildContext context,
) {
  final customPlaylist = {
    'title': playlistName,
    'source': 'user-created',
    if (image != null) 'image': image,
    'list': [],
  };
  userCustomPlaylists.value = [...userCustomPlaylists.value, customPlaylist];
  addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
  return '${context.l10n!.addedSuccess}!';
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
      (playlistElement) => playlistElement['id'] == song['id'],
    )) {
      return context.l10n!.songAlreadyInPlaylist;
    }
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
      playlistSongs.removeWhere((song) => song['id'] == songToRemove['id']);
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
    if (add) {
      if (playlist.isNotEmpty) {
        userLikedPlaylists.addOrUpdate('id', playlist['id'], {
          'id': playlist['id'],
          'title': playlist['title'],
        });
      } else {
        final playlistInfo = await getPlaylistInfoForWidget(playlist['id']);
        if (playlistInfo != null) {
          userLikedPlaylists.add(playlistInfo);
        }
      }
      currentLikedPlaylistsLength.value++;
    } else {
      userLikedPlaylists.removeWhere((value) => value['id'] == playlist['id']);
      currentLikedPlaylistsLength.value--;
    }

    addOrUpdateData('user', 'likedPlaylists', userLikedPlaylists);
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

bool isPlaylistAlreadyLiked(playlistIdToCheck) =>
    userLikedPlaylists.any((playlist) => playlist['id'] == playlistIdToCheck);

Future<List> getPlaylists({
  String? query,
  int? playlistsNum,
  bool onlyLiked = false,
  String type = 'all',
}) async {
  // Early exit if there are no playlists to process.
  if (dbPlaylists.isEmpty ||
      (playlistsNum == null && query == null && suggestedPlaylists.isEmpty)) {
    return [];
  }

  // If a query is provided (without a limit), filter playlists based on the query and type,
  // and augment with online search results.
  if (query != null && playlistsNum == null) {
    final lowercaseQuery = query.toLowerCase();
    final filteredPlaylists =
        dbPlaylists.where((playlist) {
          final title = playlist['title'].toLowerCase();
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
    if (suggestedPlaylists.isEmpty) {
      suggestedPlaylists = List.from(dbPlaylists)..shuffle();
    }
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
    showToast(context, context.l10n!.playlistUpdated);
  }
  return dbPlaylists[index];
}

int findPlaylistIndexByYtId(String ytid) {
  return dbPlaylists.indexWhere((playlist) => playlist['id'] == ytid);
}

/* Future<void> setActivePlaylist(Map info) async {
  activeQueue = info;
  activeSongId = 0;

  await audioHandler.playSong(activeQueue['list'][activeSongId]);
} */

Future<Map?> getPlaylistInfoForWidget(
  dynamic id, {
  bool isArtist = false,
}) async {
  if (isArtist) {
    return {'title': id, 'list': await getSongsList(id)};
  }

  Map? playlist;

  // Check in local playlists.
  playlist = dbPlaylists.firstWhere((p) => p['ytid'] == id, orElse: () => null);

  // Check in user playlists if not found.
  if (playlist == null) {
    final userPl = await getUserPlaylists();
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
      return null;
    }
  }

  // If the playlist exists but its song list is empty, fetch and cache the songs.
  if (playlist['list'] == null ||
      (playlist['list'] is List && (playlist['list'] as List).isEmpty)) {
    playlist['list'] = await getSongsFromPlaylist(playlist['id']);
    if (!dbPlaylists.contains(playlist)) {
      dbPlaylists.add(playlist);
    }
  }

  return playlist;
}
