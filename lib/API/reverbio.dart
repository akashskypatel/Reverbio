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
import 'dart:convert';

import 'package:discogs_api_client/discogs_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:musicbrainz_api_client/musicbrainz_api_client.dart';
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

Future<List<String>> getSearchSuggestions(String query) async {
  // Custom implementation:

  // const baseUrl = 'https://suggestqueries.google.com/complete/search';
  // final parameters = {
  //   'client': 'firefox',
  //   'ds': 'yt',
  //   'q': query,
  // };

  // final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);

  // try {
  //   final response = await http.get(
  //     uri,
  //     headers: {
  //       'User-Agent':
  //           'Mozilla/5.0 (Windows NT 10.0; rv:96.0) Gecko/20100101 Firefox/96.0',
  //     },
  //   );

  //   if (response.statusCode == 200) {
  //     final suggestions = jsonDecode(response.body)[1] as List<dynamic>;
  //     final suggestionStrings = suggestions.cast<String>().toList();
  //     return suggestionStrings;
  //   }
  // } catch (e, stackTrace) {
  //   logger.log('Error in getSearchSuggestions:$e\n$stackTrace');
  // }

  // Built-in implementation:
  
  final suggestions = await yt.search.getQuerySuggestions(query);

  return suggestions;
}

Future<List<Map<String, int>>> getSkipSegments(String id) async {
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
      final data = jsonDecode(res.body);
      final segments =
          data.map((obj) {
            return Map.castFrom<String, dynamic, String, int>({
              'start': obj['segment'].first.toInt(),
              'end': obj['segment'].last.toInt(),
            });
          }).toList();
      return List.castFrom<dynamic, Map<String, int>>(segments);
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
