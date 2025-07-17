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

import 'package:flutter/material.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:hive/hive.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/utils.dart';

List userLikedArtistsList = Hive.box(
  'user',
).get('likedArtists', defaultValue: []);

List cachedArtistsList = Hive.box(
  'cache',
).get('cachedArtists', defaultValue: []);

final ValueNotifier<int> currentLikedArtistsLength = ValueNotifier<int>(
  userLikedArtistsList.length,
);

/// Returns current liked status if successful.
Future<bool> updateArtistLikeStatus(dynamic artist, bool add) async {
  try {
    artist['id'] = parseEntityId(artist);
    if (artist['id']?.isEmpty) throw Exception('ID is null or empty');
    if (add) {
      if (artist['id'] != null &&
          (artist['musicbrainz'] == null || artist['musicbrainz'].isEmpty))
        unawaited(getArtistDetails(artist));
      userLikedArtistsList.addOrUpdate('id', artist['id'], {
        'id': artist['id'],
        'name': artist['artist'],
        'image': artist['image'],
        'genres': artist['genres'] ?? artist['musicbrainz']?['genres'] ?? [],
        'primary-type': 'artist',
      });
      currentLikedArtistsLength.value++;
      PM.onEntityLiked(artist);
    } else {
      userLikedArtistsList.removeWhere((value) => checkArtist(artist, value));
      currentLikedArtistsLength.value--;
    }
    addOrUpdateData('user', 'likedArtists', userLikedArtistsList);
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return !add;
  }
}

bool isArtistAlreadyLiked(artistToCheck) =>
    artistToCheck is Map &&
    userLikedArtistsList.any(
      (artist) => artist is Map && checkArtist(artist, artistToCheck),
    );

Future<Map> getArtistDetails(dynamic artistData, {bool refresh = false}) async {
  try {
    final id = parseEntityId(artistData);
    final ids = Uri.parse('?$id').queryParameters;
    if (ids['mb'] == null) return {};
    if (!refresh) {
      final cached = _getCachedArtist(id);
      if (cached != null) {
        if (cached?['youtube'] == null || cached?['youtube'].isEmpty)
          cached['youtube'] = await _parseYTRelations(
            List.from(cached['musicbrainz']?['relations'] ?? []),
          );
        return cached;
      }
    }
    final mbRes = await mb.artists.get(
      ids['mb']!,
      inc: [
        'release-groups',
        'aliases',
        'tags',
        'genres',
        'ratings',
        'release-group-rels',
        'url-rels',
      ],
    );
    final urls = List.from(mbRes['relations'] ?? []);
    final dcRes = await _parseDCRelations(List.from(urls));
    final ytRes = await _parseYTRelations(List.from(urls));
    final result = await _combineResults(
      mbRes: mbRes,
      dcRes: dcRes,
      ytRes: ytRes,
    );
    return result;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<dynamic> _parseDCRelations(List relations) async {
  final urls = relations.where((e) => e['type'] == 'discogs').toList();
  dynamic data = {};
  try {
    if (urls.isNotEmpty) {
      for (final u in urls) {
        final discogsUrl = u['url']['resource'];
        final regex = RegExp(r'.+\/artist\/(\d+)');
        final match = regex.firstMatch(discogsUrl)?.group(1) ?? '';
        data = await _getArtistDetailsDC(match);
        if (data != null && data.isNotEmpty) return data;
      }
    }
  } catch (_) {}
  return data;
}

Future<dynamic> _parseYTRelations(List relations) async {
  dynamic data = {};
  try {
    final urls = relations.where((e) => e['type'] == 'youtube').toList();
    if (urls.isNotEmpty) {
      for (final u in urls) {
        final url = u['url']['resource'];
        final chrx = RegExp(r'(?:.+\/channel\/)(.*)').firstMatch(url);
        final usrx = RegExp(r'(?:.+\/user\/)(.*)').firstMatch(url);
        final match = chrx?.group(1) ?? usrx?.group(1);
        if (chrx?.group(1) == null && usrx?.group(1) != null) {
          final userSearch = await yt.search.search(match!);
          for (final res in userSearch) {
            if (res.author == match) {
              final channel = await yt.channels.get(res.channelId);
              data = {
                'url': channel.url,
                'bannerUrl': channel.bannerUrl,
                'id': channel.id.value,
                'logoUrl': channel.logoUrl,
                'subscribersCount': channel.subscribersCount,
                'title': channel.title,
              };
              return data;
            }
          }
        } else if (chrx?.group(1) != null) {
          final channel = await yt.channels.get(match);
          data = {
            'url': channel.url,
            'bannerUrl': channel.bannerUrl,
            'id': channel.id.value,
            'logoUrl': channel.logoUrl,
            'subscribersCount': channel.subscribersCount,
            'title': channel.title,
          };
          return data;
        }
      }
    }
  } catch (_) {}
  return data;
}

Future<dynamic> searchArtistDetails(
  String query, {
  bool exact = true,
  int limit = 100,
  int offset = 0,
  bool paginated = false,
}) async {
  try {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    final cached = _searchCachedArtists(q);
    if (cached != null && cached.isNotEmpty) return cached.first;
    final res = await _callApis(
      q,
      exact: exact,
      limit: limit,
      offset: offset,
      paginated: true,
    );
    if (res.isNotEmpty) return res.first;
    return {};
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return {};
  }
}

Future<dynamic> getRecommendedArtists(
  List<String> query,
  int itemsNumber,
) async {
  return pickRandomItems(await searchArtistsDetails(query), itemsNumber);
}

Future<dynamic> searchArtistsDetails(
  List<String> query, {
  bool exact = true,
  int limit = 100,
  int offset = 0,
  bool paginated = false,
}) async {
  try {
    final queries =
        query
            .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase())
            .toList();
    final result = [];
    final uncached = <String>[];
    for (final q in queries) {
      final cached = _searchCachedArtists(q);
      if (cached != null && cached.isNotEmpty && exact) {
        result.add(cached);
      } else
        uncached.add(q);
    }
    final qry = uncached.map((e) => '"${e.replaceAll(' ', '|')}"').join(' OR ');
    final artistsSearch = await mb.artists.search(qry, limit: limit);
    final artistList = LinkedHashSet<String>();
    for (final artist in (artistsSearch?['artists'] ?? [])) {
      if (artistList.add(artist['name'].toLowerCase())) {
        if (uncached.contains(artist['name'].toLowerCase()) ||
            uncached.contains(artist['sort-name'].toLowerCase())) {
          artist['primary-type'] = 'artist';
          result.add(artist);
        }
      }
    }
    return result;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return {};
  }
}

Future<List<dynamic>> _callApis(
  String query, {
  bool exact = true,
  int limit = 100,
  int offset = 0,
  bool paginated = false,
}) async {
  try {
    final mbRes = await _getArtistDetailsMB(
      query,
      exact: exact,
      limit: limit,
      offset: offset,
      paginated: paginated,
    );
    final results = [];
    if (mbRes != null) {
      for (final artist in mbRes) {
        if (artist['type'] != 'Other') {
          final relations = List.from(artist['relations'] ?? []);
          final dcRes = await _parseDCRelations(relations);
          final ytRes = await _parseYTRelations(relations);
          final combined = await _combineResults(
            mbRes: artist,
            dcRes: dcRes,
            ytRes: ytRes,
          );
          results.add(combined);
        }
      }
    }
    if (exact) {
      if (results.isEmpty) return [];
      if (results.length == 1)
        return results;
      else {
        final res = results.first;
        return [res];
      }
    }
    return results;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<Map<String, dynamic>> _combineResults({
  Map mbRes = const {},
  Map dcRes = const {},
  Map ytRes = const {},
}) async {
  try {
    await Hive.openBox('cache').whenComplete(
      () =>
          cachedArtistsList = Hive.box(
            'cache',
          ).get('cachedArtists', defaultValue: []),
    );
    final ids = <String, String>{};
    if (mbRes['id'] != null) ids['mb'] = mbRes['id'].toString();
    if (dcRes['id'] != null) ids['dc'] = dcRes['id'].toString();
    if (ytRes['id'] != null) ids['yt'] = ytRes['id'].toString();
    final id = Uri(
      host: '',
      queryParameters: ids,
    ).toString().replaceAll('//?', '');
    final res = {
      'id': id,
      'artist': mbRes['name'],
      'musicbrainzName': mbRes['name'],
      'discogsName': dcRes['name'],
      'musicbrainz': mbRes,
      'discogs': dcRes,
      'youtube': ytRes,
      'primary-type': 'artist',
      'cachedAt': DateTime.now().toString(),
    };
    cachedArtistsList.addOrUpdate('id', id, res);
    addOrUpdateData('cache', 'cachedArtists', cachedArtistsList);
    return res;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

dynamic _getCachedArtist(String id) {
  try {
    final cached =
        cachedArtistsList.where((e) => e['id'].contains(id)).toList();
    if (cached.isNotEmpty)
      return cached.first;
    else
      return null;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

/// Score is automatically 0 if exact = true
dynamic _searchCachedArtists(String query) {
  try {
    final cached = cachedArtistsList.where((e) => checkArtist(e, query));
    if (cached.isEmpty) return null;
    return cached.first;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

Future<dynamic> _getArtistDetailsMB(
  String query, {
  bool exact = true,
  int limit = 100,
  int offset = 0,
  bool paginated = false,
}) async {
  try {
    final stopwatch = Stopwatch()..start();
    final res = await mb.artists.search(
      query,
      limit: limit,
      offset: offset,
      paginated: paginated,
    );
    stopwatch.stop();
    if (res.isEmpty || res['artists'] == null || res['artists'].isEmpty)
      return null;
    final _results =
        exact
            ? List<dynamic>.from(res['artists']).where((e) => e['score'] == 100)
            : List<dynamic>.from(res['artists']);

    if (_results.isNotEmpty) {
      final names =
          _results.map((e) => {'id': e['id'], 'name': e['name']}).toList();
      final WeightedKey<Map<String, dynamic>> keys = WeightedKey(
        name: 'name',
        getter: (e) => e['name'],
        weight: 1,
      );
      final fuzzy = Fuzzy(
        names,
        options: FuzzyOptions(threshold: 1, keys: [keys]),
      );
      final sorted = fuzzy.search(query)..sort((a, b) {
        final comp = a.score.compareTo(b.score);
        if (comp != 0) {
          return comp;
        }
        return a.matches.first.arrayIndex.compareTo(b.matches.first.arrayIndex);
      });
      final result =
          exact ? sorted.where((e) => e.score.isNearlyZero()) : sorted;

      final inc = [
        'release-groups',
        'aliases',
        'tags',
        'genres',
        'ratings',
        'release-group-rels',
        'url-rels',
      ];
      stopwatch
        ..reset()
        ..start();
      if (result.isNotEmpty)
        if (exact) {
          final artistId =
              _results.firstWhere(
                (e) => e['id'] == result.first.item['id'],
              )['id'];
          final finalResult = await mb.artists.get(artistId, inc: inc);
          //TODO optimize
          return [finalResult];
        } else {
          final finalResult = [];
          for (final artist in result) {
            final artQry = await mb.artists.get(artist.item['id'], inc: inc);
            finalResult.add(artQry ?? {});
          }
          //TODO optimize
          return finalResult;
        }
    }
    return null;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<dynamic> _getArtistDetailsDC(String query) async {
  try {
    dynamic res;

    if (query == '') return;

    if (int.tryParse(query) != null) {
      try {
        final discogsId = int.parse(query);
        res = await dc.artists.artists(discogsId);
        return res;
      } catch (e) {
        return;
      }
    } else {
      res = await dc.search.search(query: query, type: 'artist');
      final _pages = res['pagination']['pages'];
      final _results = [];

      if (res['results'].length > 0) _results.addAll(res['results']);

      for (var i = 2; i <= _pages; i++) {
        res = await dc.search.search(query: query, type: 'artist', page: i);
        if (res['results'].length > 0) _results.addAll(res['results']);
      }

      if (_results.isEmpty) return;

      final names =
          _results
              .where((e) => e['type'] == 'artist')
              .map((e) => {'id': e['id'], 'title': e['title']})
              .toList();
      final WeightedKey<Map<String, dynamic>> keys = WeightedKey(
        name: 'title',
        getter: (e) => e['title'],
        weight: 1,
      );
      final fuzzy = Fuzzy(
        names,
        options: FuzzyOptions(threshold: 1, keys: [keys]),
      );
      final result = fuzzy.search(query)
        ..sort((a, b) => a.score.compareTo(b.score));
      final val = _results.where((e) => e['id'] == result.first.item['id']);
      if (val.isNotEmpty)
        await _getArtistDetailsDC(val.first['id']);
      else
        return;
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

int? getArtistHashCode(dynamic artist) {
  try {
    if (!(artist is Map)) return null;
    if ((artist['name'] ?? artist['artist'] ?? artist['musicbrainzName']) ==
        null)
      return null;
    return (artist['name'] ?? artist['artist'] ?? artist['musicbrainzName'])
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase()
        .hashCode;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

bool checkArtist(dynamic artistA, dynamic artistB) {
  try {
    if (artistA == null || artistB == null) return false;
    if (artistA is String ||
        artistB is String ||
        (artistA is Map &&
            artistB is Map &&
            (artistA['id'] == null || artistB['id'] == null)))
      return getArtistHashCode(artistA) == getArtistHashCode(artistB) &&
          getArtistHashCode(artistA) != null &&
          getArtistHashCode(artistB) != null;
    parseEntityId(artistA);
    parseEntityId(artistB);
    return checkEntityId(artistA['id'], artistB['id']);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return false;
  }
}
