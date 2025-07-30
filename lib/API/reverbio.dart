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
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:discogs_api_client/discogs_api_client.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:musicbrainz_api_client/musicbrainz_api_client.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final yt = YoutubeExplode();
final DiscogsApiClient dc = DiscogsApiClient();
final mb = MusicBrainzApiClient();

List<YoutubeApiClient> userChosenClients = [
  YoutubeApiClient.tv,
  YoutubeApiClient.androidVr,
  YoutubeApiClient.safari,
];

bool youtubeValidate(String url) {
  final regExp = RegExp(
    r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/.*(list=([a-zA-Z0-9_-]+)).*$',
  );
  return regExp.hasMatch(url);
}

String parseEntityId(dynamic entity) {
  dynamic ids;
  String songId =
      entity is String
          ? entity
          : entity['id'] ??
              entity['mbid'] ??
              entity['ytid'] ??
              entity['dcid'] ??
              '';
  final mbRx = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  if (songId.contains('=')) {
    ids = Uri.parse('?$songId').queryParameters;
    songId = Uri(
      host: '',
      queryParameters: ids,
    ).toString().replaceAll('?', '').replaceAll('//', '');
  } else if (mbRx.hasMatch(songId)) {
    songId = 'mb=$songId';
  } else if (int.tryParse(songId) != null) {
    songId = 'dc=$songId';
  } else if (songId.isNotEmpty) {
    songId = 'yt=$songId';
  }
  ids = Uri.parse('?$songId').queryParameters;
  if (entity is Map) {
    entity =
        Map<String, dynamic>.from(entity)
          ..addAll(<String, dynamic>{'id': songId})
          ..addAll(<String, dynamic>{'ytid': ids['yt']})
          ..addAll(<String, dynamic>{'mbid': ids['mb']})
          ..addAll(<String, dynamic>{'dcid': ids['dc']});
  }
  return songId;
}

String? combineArtists(dynamic value) {
  if (value == null) return null;
  final artists =
      ((value['artist-credit'] ?? []) as List)
          .map((e) => e['name'] as String)
          .toList();
  final result = artists
      .fold<Set<String>>(<String>{}, (result, str) {
        final names = str.split(RegExp(r'\s*[&,]\s*')).map((n) => n.trim());
        return result..addAll(names);
      })
      .toList()
      .join(', ');
  return result.isEmpty ? null : result;
}

Future<Map<String, Map<String, dynamic>>> getMBSearchSuggestions(
  String query,
  String entity, {
  int limit = 5,
  int offset = 0,
  int maxScore = 0,
  bool minimal = true,
}) async {
  entity = entity.trim().toLowerCase();
  query = query.replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(' ', '|');
  final entityName = <String, dynamic>{
    'artist': {'function': mb.artists.search, 'name': 'artists', 'type': null},
    'artists': {'function': mb.artists.search, 'name': 'artists', 'type': null},
    'album': {
      'function': mb.releaseGroups.search,
      'name': 'release-groups',
      'type': 'album',
    },
    'albums': {
      'function': mb.releaseGroups.search,
      'name': 'release-groups',
      'type': 'album',
    },
    'release-group': {
      'function': mb.releaseGroups.search,
      'name': 'release-groups',
      'type': 'album',
    },
    'release-groups': {
      'function': mb.releaseGroups.search,
      'name': 'release-groups',
      'type': 'album',
    },
    'song': {
      'function': mb.recordings.search,
      'name': 'recordings',
      'type': 'song',
    },
    'songs': {
      'function': mb.recordings.search,
      'name': 'recordings',
      'type': 'song',
    },
    'recording': {
      'function': mb.recordings.search,
      'name': 'recordings',
      'type': 'song',
    },
    'recordings': {
      'function': mb.recordings.search,
      'name': 'recordings',
      'type': 'song',
    },
  };
  int hashCode(Map<String, dynamic> e) {
    if (['artist', 'artists'].contains(e['entity']))
      return e['value']!.toLowerCase().hashCode;
    else
      return e['value']!.toLowerCase().hashCode ^
          e['artist']!.toLowerCase().hashCode;
  }

  final exclude = ['various artists'];
  bool isEqual(Map<String, dynamic> e1, Map<String, dynamic> e2) {
    return hashCode(e1) == hashCode(e2);
  }

  if (entityName[entity]?['function'] == null)
    throw Exception('MusicBrainz returned no results.');
  try {
    final params = Map<String, String>.from(
      entityName[entity]?['type'] != null
          ? {'primarytype': entityName[entity]?['type'] ?? ''}
          : {},
    );
    final fn = (entityName[entity]?['function'] as Function?) ?? () {};
    final result = await fn(
      '$query OR artist:$query OR artistname:$query',
      limit: minimal ? 25 : 100,
      params: params,
      offset: offset,
    );
    if (result == null || result[entityName[entity]?['name']] == null)
      throw Exception('MusicBrainz search failed.');
    if (result[entityName[entity]?['name']].isNotEmpty) {
      final uniqueList = LinkedHashSet<Map<String, dynamic>>(
        equals: isEqual,
        hashCode: hashCode,
      )..addAll(
        (result[entityName[entity]?['name']] as List).map(
          (e) => {
            'entity': entityName[entity]?['name'],
            'value': (e['title'] ?? e['name']) as String,
            'title': e['title'],
            'artist-credit': e['artist-credit'],
            'artist': combineArtists(e),
            'id': 'mb=${e['id']}',
            'rid': e['id'],
            'duration': (e['length'] ?? 0) ~/ 1000,
            'mbidType': 'recording',
            'releases': e['releases'],
            'score': e['score'],
          },
        ),
      );
      final list =
          uniqueList
              .where(
                (e) =>
                    (e['score'] as int) >= maxScore &&
                    !exclude.contains(e['value'].toLowerCase()),
              )
              .take(limit)
              .toList();
      return <String, Map<String, dynamic>>{
        entity: {
          'count': result['count'],
          'offset': result['offset'],
          'data': list,
        },
      };
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return {
    entity: {'count': 0, 'offset': 0, 'data': []},
  };
}

Future<Map<String, Map<String, dynamic>>> getYTSearchSuggestions(
  String query, {
  int limit = 10,
}) async {
  try {
    final results = await yt.search.getQuerySuggestions(query);
    return {
      'youtube': {
        'count': results.length,
        'offset': 0,
        'data':
            results
                .map((e) => {'value': e, 'entity': 'youtube'})
                .toList()
                .take(limit)
                .toList(),
      },
    };
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return {
    'youtube': {'count': 0, 'offset': 0, 'data': []},
  };
}

Future<Map<String, Map<String, dynamic>>> getYTPlaylistSuggestions(
  String query, {
  int offset = 0,
  List<SearchList> resultList = const [],
}) async {
  try {
    final index = resultList.isNotEmpty ? (offset ~/ 20) : 0;
    final results =
        offset != 0 && offset >= (20 * resultList.length)
            ? await resultList.last
                .nextPage() //if offset is greater than list length * 20 get next page from last item
            : resultList.isNotEmpty
            ? resultList[index] //if offset is negative and list is not empty get either the last item or get one before last (i.e. previous results)
            : await yt.search.searchContent(
              query,
              filter: TypeFilters.playlist,
            ); //if result list is empty then make a new search
    if ((offset == 0 || offset >= (20 * resultList.length)) && results != null)
      resultList.add(results);
    return {
      'playlist': {
        'count': results?.length ?? 0,
        'offset': offset,
        'resultList': resultList,
        'data':
            results
                ?.whereType<SearchPlaylist>()
                .map(
                  (e) => Map<String, dynamic>.from({
                    'id': 'yt=${e.id}',
                    'value': e.title,
                    'title': e.title,
                    'videoCount': e.videoCount,
                    'source': 'youtube',
                    'entity': 'playlist',
                    'primary-type': 'playlist',
                  }),
                )
                .toList() ??
            [],
      },
    };
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return {
    'playlist': {'count': 0, 'offset': 0, 'data': []},
  };
}

Future<Map<String, Map<String, dynamic>>> getAllSearchSuggestions(
  String query, {
  int? limit,
  int offset = 0,
  int maxScore = 0,
  bool minimal = true,
  String? entity,
  List<SearchList>? resultList,
}) async {
  final futures = <Future>[];
  if (entity != null && ['artist', 'song', 'album'].contains(entity)) {
    futures.add(
      getMBSearchSuggestions(
        query,
        entity,
        limit: limit ?? 5,
        minimal: minimal,
        maxScore: maxScore,
        offset: offset,
      ),
    );
  } else if (entity == 'playlist') {
    futures.add(
      getYTPlaylistSuggestions(
        query,
        offset: offset,
        resultList: resultList ?? [],
      ),
    );
  } else if (!minimal) {
    futures
      ..add(
        getMBSearchSuggestions(
          query,
          'artist',
          limit: limit ?? 5,
          minimal: minimal,
          maxScore: maxScore,
          offset: offset,
        ),
      )
      ..add(
        getMBSearchSuggestions(
          query,
          'album',
          limit: limit ?? 5,
          minimal: minimal,
          maxScore: maxScore,
          offset: offset,
        ),
      )
      ..add(
        getMBSearchSuggestions(
          query,
          'song',
          limit: limit ?? 5,
          minimal: minimal,
          maxScore: maxScore,
          offset: offset,
        ),
      )
      ..add(
        getYTPlaylistSuggestions(
          query,
          offset: offset,
          resultList: resultList ?? [],
        ),
      );
  } else {
    futures.add(getYTSearchSuggestions(query));
  }
  final results = <String, Map<String, dynamic>>{};
  final fetchingList = await Future.wait(futures);
  for (final message in fetchingList) {
    results.addAll(message);
  }
  return results;
}

Future<List<Map<String, dynamic>>> getSkipSegments(String id) async {
  try {
    final res = await http.get(
      Uri(
        scheme: 'https',
        host: 'sponsor.ajay.app',
        path: '/api/skipSegments',
        queryParameters: {
          'videoID': id,
          'category': [
            'sponsor',
            'selfpromo',
            'interaction',
            'intro',
            'outro',
            'music_offtopic',
          ],
          'actionType': 'skip',
        },
      ),
    );
    if (res.body != 'Not Found') {
      final data = List.from(jsonDecode(res.body));
      final segments =
          data.map((obj) {
            return {
              'category': obj['category'],
              'start':
                  ((double.tryParse(
                                (obj['segment'] as List).first.toString(),
                              ) ??
                              0) *
                          1e+6)
                      .toInt(),

              'end':
                  ((double.tryParse((obj['segment'] as List).last.toString()) ??
                              0) *
                          1e+6)
                      .toInt(),
            };
          }).toList();
      return List.from(segments);
    } else {
      return [];
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return [];
  }
}

final clients = {
  'tv': YoutubeApiClient.tv,
  'androidVr': YoutubeApiClient.androidVr,
  'safari': YoutubeApiClient.safari,
  'ios': YoutubeApiClient.ios,
  'android': YoutubeApiClient.android,
  'androidMusic': YoutubeApiClient.androidMusic,
  'mediaConnect': YoutubeApiClient.mediaConnect,
  'web': YoutubeApiClient.mweb,
};

Future<String> getLiveStreamUrl(String songId) async {
  final streamInfo = await yt.videos.streamsClient.getHttpLiveStreamUrl(
    VideoId(songId),
  );
  return streamInfo;
}

AudioStreamInfo selectAudioQuality(List<AudioStreamInfo> availableSources) {
  final qualitySetting = audioQualitySetting.value;

  if (qualitySetting == 'low') {
    return availableSources.last;
  } else if (qualitySetting == 'medium') {
    return availableSources[availableSources.length ~/ 2];
  } else if (qualitySetting == 'high') {
    return availableSources.first;
  } else {
    return availableSources.withHighestBitrate();
  }
}

Future<Map<String, dynamic>> getIPGeolocation() async {
  try {
    final uri = Uri.http('ip-api.com', 'json');
    final response = await http.get(uri);
    return Map<String, dynamic>.from(jsonDecode(response.body));
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return {};
  }
}

bool checkEntityId(String id, String otherId) {
  if (id.contains('=') || id.contains('&')) {
    final ids = Uri.parse('?$id').queryParameters;
    return ids.values.any((i) => otherId.contains(i));
  }
  return id.contains(otherId) || otherId.contains(id);
}

Future<void> clearFilePickerTempFiles() async {
  try {
    await FilePicker.platform.clearTemporaryFiles();
  } catch (_) {}
}

String incrementFileName(String input) {
  try {
    final regex = RegExp(r'\((\d+)\)$');
    final match = regex.firstMatch(input);

    if (match != null) {
      final number = int.parse(match.group(1)!);
      final incremented = number + 1;
      return input.replaceRange(match.start, match.end, '($incremented)');
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return '$input (1)';
}

Future<File> copyFileToDir(
  String path,
  String dir, {
  int maxAttempts = 100,
}) async {
  try {
    await Directory(dir).create(recursive: true);

    final ext = extension(path);
    String fileName = basenameWithoutExtension(path);
    File targetFile = File('$dir/$fileName$ext');

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!await targetFile.exists()) {
        return await File(path).copy(targetFile.path);
      }
      // Increment filename and update target path
      fileName = incrementFileName(fileName);
      targetFile = File('$dir/$fileName$ext');
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  return File(path);
}

Future<String?> pickImageFile({int maxAttempts = 100}) async {
  final _dir = await getApplicationSupportDirectory();
  final _artworkDirPath = '${_dir.path}/artworks';
  await Directory(_artworkDirPath).create(recursive: true);

  final file =
      (await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpeg', 'jpg', 'png', 'gif', 'webp', 'bmp'],
      ))?.files.first;
  if (file == null || file.path == null) return null;

  final copy = await copyFileToDir(file.path!, _artworkDirPath);

  return copy.path;
}
