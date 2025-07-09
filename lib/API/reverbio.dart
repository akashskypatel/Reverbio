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

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:discogs_api_client/discogs_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:musicbrainz_api_client/musicbrainz_api_client.dart';
import 'package:reverbio/API/entities/playlist.dart';
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
  final entityFunction = {
    'artist': mb.artists.search,
    'artists': mb.artists.search,
    'album': mb.releaseGroups.search,
    'albums': mb.releaseGroups.search,
    'release-group': mb.releaseGroups.search,
    'release-groups': mb.releaseGroups.search,
    'song': mb.releases.search,
    'songs': mb.releases.search,
    'release': mb.releases.search,
    'releases': mb.releases.search,
  };
  final entityName = {
    'artist': {'name': 'artists', 'type': null},
    'artists': {'name': 'artists', 'type': null},
    'album': {'name': 'release-groups', 'type': 'album'},
    'albums': {'name': 'release-groups', 'type': 'album'},
    'release-group': {'name': 'release-groups', 'type': 'album'},
    'release-groups': {'name': 'release-groups', 'type': 'album'},
    'song': {'name': 'releases', 'type': 'song'},
    'songs': {'name': 'releases', 'type': 'song'},
    'release': {'name': 'releases', 'type': 'song'},
    'releases': {'name': 'releases', 'type': 'song'},
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

  if (entityFunction[entity] == null)
    throw Exception('MusicBrainz returned no results.');
  try {
    final params =
        entityName[entity]?['type'] != null
            ? {'primarytype': entityName[entity]?['type'] ?? ''}
            : null;
    final result = await entityFunction[entity]!(
      query,
      limit: minimal ? 25 : 100,
      params: params,
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
            'artist-credits': e['artist-credits'],
            'artist': combineArtists(e),
            'id': 'mb=${e['id']}',
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
  int limit = 3,
}) async {
  try {
    final results = await getPlaylists(query: query, type: 'playlist');
    return {
      'playlist': {
        'count': results.length,
        'offset': 0,
        'data':
            results
                .map(
                  (e) => Map<String, dynamic>.from({
                    ...e,
                    'value': e['title'],
                    'entity': 'playlist',
                  }),
                )
                .toList()
                .take(limit)
                .toList(),
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
}) async {
  final futures = <Future>[];
  if (!minimal) {
    futures
      ..add(
        getMBSearchSuggestions(
          query,
          'artist',
          limit: limit ?? 5,
          minimal: minimal,
          maxScore: maxScore,
        ),
      )
      ..add(
        getMBSearchSuggestions(
          query,
          'album',
          limit: limit ?? 5,
          minimal: minimal,
          maxScore: maxScore,
        ),
      )
      ..add(
        getMBSearchSuggestions(
          query,
          'song',
          limit: limit ?? 5,
          minimal: minimal,
          maxScore: maxScore,
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
