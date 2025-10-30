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

import 'dart:convert';

import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/utilities/utils.dart';

class LyricsManager {
  Future<String?> fetchLyrics(dynamic song) async {
    String? lyrics;
    try {
      if (song == null) return lyrics;
      final artistList =
          (song['artist-credit'] ?? []).isNotEmpty
              ? song['artist-credit'].map((e) => e['name'])
              : splitArtists(songArtist(song['artist']));
      final title = songTitle(song);
      if (artistList.isNotEmpty) {
        final futures = <Future<String?>>[];
        for (final artistName in artistList) {
          futures
            ..add(_fetchLyricsFromGoogle(artistName, title))
            ..add(_fetchLyricsFromParolesNet(artistName, title))
            ..add(_fetchLyricsFromLyricsMania1(artistName, title))
            ..add(_fetchLyricsFromLrclibGet(artistName, title))
            ..add(_fetchLyricsFromLrclibSearch(artistName, title));
        }
        lyrics = await futures.firstSuccessful();
      }
    } catch (_) {}
    return lyrics;
  }

  Future<String> _fetchLyricsFromGoogle(String artistName, String title) async {
    const url =
        'https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q=';
    String? lyricsRes;
    try {
      final res = await http
          .get(Uri.parse(Uri.encodeFull('$url$artistName - $title lyrics')))
          .timeout(const Duration(seconds: 10));
      final body = res.body;
      final document = parser.parse(body);

      if (body.contains('<meta charset="UTF-8">') ||
          body.contains('please enable javascript on your web browser') ||
          body.contains('Error 500 (Server Error)') ||
          body.contains(
            'systems have detected unusual traffic from your computer network',
          ) ||
          body.contains('if you are not redirected within a few seconds.'))
        throw Exception('Could not fetch lyrics from Google.');
      if (body.contains('data-attrid="kc:/music/recording_cluster:lyrics"')) {
        const selector =
            'div[data-attrid="kc:/music/recording_cluster:lyrics"]';
        final lyricsDiv = document.querySelector(selector);
        if (lyricsDiv != null) {
          lyricsRes = lyricsDiv.text;
        }
      }
      if (lyricsRes != null) return lyricsRes;
      throw Exception('Could not fetch lyrics from Google.');
    } catch (_) {
      throw Exception('Could not fetch lyrics from Google.');
    }
  }

  Future<String> _fetchLyricsFromParolesNet(
    String artistName,
    String title,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.paroles.net/${_lyricsUrl(artistName)}/paroles-${_lyricsUrl(title)}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final songTextElements = document.querySelectorAll('.song-text');

        if (songTextElements.isNotEmpty) {
          final lyricsLines = songTextElements.first.text.split('\n');
          if (lyricsLines.length > 1) {
            lyricsLines.removeAt(0);

            final finalLyrics = addCopyright(
              lyricsLines.join('\n'),
              'www.paroles.net',
            );
            return _removeSpaces(finalLyrics);
          }
        }
      }
      throw Exception('Could not fetch lyrics from Paroles.');
    } catch (_) {
      throw Exception('Could not fetch lyrics from Paroles.');
    }
  }

  Future<String> _fetchLyricsFromLyricsMania1(
    String artistName,
    String title,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.lyricsmania.com/${_lyricsManiaUrl(title)}_lyrics_${_lyricsManiaUrl(artistName)}.html',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final lyricsBodyElements = document.querySelectorAll('.lyrics-body');

        if (lyricsBodyElements.isNotEmpty) {
          return addCopyright(
            lyricsBodyElements.first.text,
            'www.lyricsmania.com',
          );
        }
      }
      throw Exception('Could not fetch lyrics from Lyricsmania.');
    } catch (_) {
      throw Exception('Could not fetch lyrics from Lyricsmania.');
    }
  }

  Future<String> _fetchLyricsFromLrclibGet(
    String artistName,
    String title,
  ) async {
    try {
      String? lyrics;
      final uri = Uri.parse(
        'https://lrclib.net/api/get?artist_name=$artistName&track_name=$title',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['plainLyrics'] != null) {
          lyrics = data['plainLyrics'];
          return addCopyright(lyrics!, 'www.lrclib.net');
        }
      }
      throw Exception('Could not fetch lyrics from Lrclib.');
    } catch (_) {
      throw Exception('Could not fetch lyrics from Lrclib.');
    }
  }

  Future<String> _fetchLyricsFromLrclibSearch(
    String artistName,
    String title,
  ) async {
    try {
      String? lyrics;
      final uri = Uri.parse(
        'https://lrclib.net/api/search?artist_name=$artistName&track_name=$title',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          for (final item in data) {
            if (checkTitleAndArtist(
              {'title': title, 'artist': artistName},
              {'title': item['title'], 'artist': item['artistName']},
            )) {
              if (item['plainLyrics'] != null) {
                lyrics = item['plainLyrics'];
                return addCopyright(lyrics!, 'www.lrclib.net');
              }
            }
          }
        }
      }
      throw Exception('Could not fetch lyrics from Lrclib.');
    } catch (_) {
      throw Exception('Could not fetch lyrics from Lrclib.');
    }
  }

  String _lyricsUrl(String input) {
    var result = input.replaceAll(' ', '-').toLowerCase();
    if (result.isNotEmpty && result.endsWith('-')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  String _lyricsManiaUrl(String input) {
    var result = input.replaceAll(' ', '_').toLowerCase();
    if (result.isNotEmpty && result.startsWith('_')) {
      result = result.substring(1);
    }
    if (result.isNotEmpty && result.endsWith('_')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  String _removeSpaces(String input) {
    return input.replaceAll('  ', '');
  }

  String addCopyright(String input, String copyright) {
    return '$input\n\n© $copyright';
  }
}
