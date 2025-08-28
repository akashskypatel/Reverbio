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
import 'package:reverbio/services/proxy_manager.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final pxm = ProxyManager(); // ProxyManager for manifest
final pxd = ProxyManager(); // ProxyManager for data
// YouTube client for Data
YoutubeExplode yt = YoutubeExplode(
  YoutubeHttpClient(useProxies.value ? pxd.randomProxyClient() : null),
);
// YouTube client for Manifest
YoutubeExplode ytm = YoutubeExplode(
  YoutubeHttpClient(useProxies.value ? pxm.randomProxyClient() : null),
);
DiscogsApiClient dc = DiscogsApiClient(
  httpClient: useProxies.value ? pxd.randomProxyClient() : null,
);
MusicBrainzApiClient mb = MusicBrainzApiClient(
  httpClient: useProxies.value ? pxd.randomProxyClient() : null,
);
/*
List<YoutubeApiClient> userChosenClients = [
  YoutubeApiClient.tv,
  YoutubeApiClient.androidVr,
  YoutubeApiClient.safari,
];
*/
final List<dynamic> notificationLog = [];

bool youtubePlaylistValidate(String url) {
  final regExp = RegExp(
    r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/.*(list=([a-zA-Z0-9_-]+)).*$',
  );
  return regExp.hasMatch(url);
}

bool youtubeValidate(String url) {
  final regExp = RegExp(
    r'^(?:https?:\/\/)?(?:www\.)?(youtube\.com|youtu\.be)\/(?:watch\?)(.*)$',
  );
  return regExp.hasMatch(url);
}

String? getCombinedId(dynamic entity) {
  if (entity is String) return entity;
  String? combinedId;
  if (entity is Map) {
    final ids = Uri.parse('?${entity['id']}').queryParameters;
    if ((entity['ytid'] != null && entity['ytid'].isNotEmpty) ||
        (ids['yt'] != null && ids['yt']!.isNotEmpty)) {
      final ytid = ((entity['ytid'] ?? ids['yt'] ?? '') as String).replaceAll(
        RegExp('yt=|yt%3d', caseSensitive: false),
        '',
      );
      combinedId = 'yt=$ytid';
    }
    if ((entity['mbid'] != null && entity['mbid'].isNotEmpty) ||
        (ids['mb'] != null && ids['mb']!.isNotEmpty)) {
      final mbid = ((entity['mbid'] ?? ids['mb'] ?? '') as String).replaceAll(
        RegExp('mb=|mb%3d', caseSensitive: false),
        '',
      );
      combinedId =
          combinedId == null || combinedId.isEmpty
              ? 'mb=$mbid'
              : joinIfNotEmpty([combinedId, 'mb=$mbid'], '&');
    }
    if ((entity['dcid'] != null && entity['dcid'].isNotEmpty) ||
        (ids['dc'] != null && ids['dc']!.isNotEmpty)) {
      final dcid = ((entity['dcid'] ?? ids['dc'] ?? '') as String).replaceAll(
        RegExp('dc=|dc%3d', caseSensitive: false),
        '',
      );
      combinedId =
          combinedId == null || combinedId.isEmpty
              ? 'dc=$dcid'
              : joinIfNotEmpty([combinedId, 'dc=$dcid'], '&');
    }
    if ((entity['ucid'] != null && entity['ucid'].isNotEmpty) ||
        (ids['uc'] != null && ids['uc']!.isNotEmpty)) {
      final ucid = ((entity['ucid'] ?? ids['uc'] ?? '') as String).replaceAll(
        RegExp('uc=|uc%3d', caseSensitive: false),
        '',
      );
      combinedId =
          combinedId == null || combinedId.isEmpty
              ? 'uc=$ucid'
              : joinIfNotEmpty([combinedId, 'uc=$ucid'], '&');
    }
    if ((entity['isrc'] != null && entity['isrc'].isNotEmpty) ||
        (ids['is'] != null && ids['is']!.isNotEmpty)) {
      final isrc = ((entity['isrc'] ?? ids['is'] ?? '') as String).replaceAll(
        RegExp('is=|is%3d', caseSensitive: false),
        '',
      );
      combinedId =
          combinedId == null || combinedId.isEmpty
              ? 'is=$isrc'
              : joinIfNotEmpty([combinedId, 'is=$isrc'], '&');
    }
  }
  return combinedId;
}

String parseEntityId(dynamic entity) {
  if (entity == null || entity.isEmpty) return getCombinedId(entity) ?? '';
  dynamic ids;
  String entityId =
      entity is String ? entity : entity['id'] ?? getCombinedId(entity) ?? '';
  final mbRx = RegExp(
    r'^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$',
    caseSensitive: false,
  );
  final isRx = RegExp(
    r'^([A-Z]{2}-?[A-Z0-9]{3}-?\d{2}-?\d{5})$',
    caseSensitive: false,
  );
  if (entityId.contains(RegExp(r'=|(\%3d)', caseSensitive: false))) {
    ids = Uri.parse('?$entityId').queryParameters;
    entityId = Uri(
      host: '',
      queryParameters: ids,
    ).toString().replaceAll(RegExp(r'\?|\/'), '');
  } else if (mbRx.hasMatch(entityId)) {
    entityId = 'mb=${mbRx.firstMatch(entityId)!.group(1)}';
  } else if (isRx.hasMatch(entityId)) {
    entityId = 'is=${isRx.firstMatch(entityId)!.group(1)}';
  } else if (int.tryParse(entityId) != null) {
    entityId = 'dc=$entityId';
  } else if (entityId.startsWith('UC-')) {
    entityId = 'uc=$entityId';
  } else if (entityId.isNotEmpty) {
    entityId = 'yt=$entityId';
  }
  ids = Uri.parse('?$entityId').queryParameters;
  if (entity is Map) {
    entity['id'] = entityId = getCombinedId(entity) ?? entityId;
    if (ids['yt'] != null && ids['yt'].isNotEmpty) entity['ytid'] = ids['yt'];
    if (ids['mb'] != null && ids['mb'].isNotEmpty) entity['mbid'] = ids['mb'];
    if (ids['is'] != null && ids['is'].isNotEmpty) entity['isrc'] = ids['is'];
    if (ids['dc'] != null && ids['dc'].isNotEmpty) entity['dcid'] = ids['dc'];
    if (ids['uc'] != null && ids['uc'].isNotEmpty) entity['ucid'] = ids['uc'];
  }
  entityId = getCombinedId(entity is Map ? entity : entityId) ?? entityId;
  return entityId;
}

String? combineArtists(dynamic value) {
  if (value == null) return null;
  final artistList =
      ((value['artist-credit'] ?? []) as List)
          .map(
            (e) => ((e['name'] ??
                        (e['artist'] is Map
                            ? e['artist']['name']
                            : e['artist'] is String
                            ? e['artist']
                            : ''))
                    as String)
                .replaceAll(',', ' '),
          )
          .toSet();
  if (value['channelName'] is String && value['mbid'] == null)
    artistList.addAll(splitArtists(value['channelName']));
  if (value['artist'] is String && value['mbid'] == null)
    artistList.addAll(splitArtists(value['artist']));
  final artists = artistList.toList()..sort((a, b) => a.compareTo(b));
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
  query = query.collapsed.replaceAll(' ', '|');
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
            'id': '${e['id']}',
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
            return <String, dynamic>{
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
      return List<Map<String, dynamic>>.from(segments);
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
  if (id.isEmpty || otherId.isEmpty) return false;
  id = parseEntityId(id);
  otherId = parseEntityId(otherId);
  var result = false;
  if ((otherId.contains('=') || otherId.contains('&')) &&
      !(id.contains('=') || id.contains('&'))) {
    final ids = otherId.split('&');
    result = ids.any((i) => i.contains(id));
    if (result) return result;
  }
  if (!(otherId.contains('=') || otherId.contains('&')) &&
      (id.contains('=') || id.contains('&'))) {
    final ids = id.split('&');
    result = ids.any((i) => i.contains(otherId));
    if (result) return result;
  }
  if (id.contains('=') ||
      id.contains('&') && (otherId.contains('=') || otherId.contains('&'))) {
    final ids = id.split('&');
    final otherIds = otherId.split('&');
    result = ids.any((i) => otherIds.any((e) => i == e));
    if (result) return result;
  }
  result = id == otherId;
  return result;
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
