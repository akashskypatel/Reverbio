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

import 'package:flutter/material.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:hive/hive.dart';
import 'package:reverbio/API/Reverbio.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';

List userLikedArtistsList = Hive.box(
  'user',
).get('likedArtists', defaultValue: []);

List cachedArtistsList = Hive.box(
  'cache',
).get('cachedArtists', defaultValue: []);

late final ValueNotifier<int> currentLikedArtistsLength;

/// Returns current liked status if successful.
Future<bool> updateArtistLikeStatus(dynamic artist, bool add) async {
  try {
    if (add) {
      userLikedArtistsList.addOrUpdate('id', artist['id'], {
        'id': artist['id'],
        'name': artist['artist'],
      });
      currentLikedArtistsLength.value++;
    } else {
      userLikedArtistsList.removeWhere((value) => value['id'] == artist['id']);
      currentLikedArtistsLength.value--;
    }
    addOrUpdateData('user', 'likedArtists', userLikedArtistsList);
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

bool isArtistAlreadyLiked(artistIdToCheck) =>
    userLikedArtistsList.any((artist) => artist['id'] == artistIdToCheck);

dynamic getArtistDetailsById(String id) async {
  try {
    final cached = _getCachedArtist(id);
    if (cached != null) return cached;
    final ids = Uri.parse('?$id').queryParameters;
    if (ids['mb'] == null) return null;
    final mbRes = await mb.artists.get(
      id,
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
    final urls =
        List.from(
          mbRes['relations'] ?? [],
        ).where((e) => e['type'] == 'discogs').toList();
    if (urls.isNotEmpty) {
      final discogsUrl = urls[0]['url']['resource'];
      final regex = RegExp(r'/artist/(\d+)');
      final match = regex.firstMatch(discogsUrl)?.group(1) ?? '';
      final dcRes = await _getArtistDetailsDC(match);
      return await _combineResults({'mbRes': mbRes, 'dcRes': dcRes});
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

Future<dynamic> searchArtistDetails(String query, {bool exact = true}) async {
  try {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    final cached = _searchCachedArtists(q, exact: exact);
    if (cached != null && cached.isNotEmpty) return cached.first;
    final res = await _callApis(q, exact: exact);
    return res;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

Future<dynamic> getArtistsDetails(
  List<String> query, {
  bool exact = true,
  int limit = 100,
  int offset = 0,
  bool paginated = false,
}) async {
  try {
    final queries =
        query.map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim()).toList();
    final result = [];
    final uncached = <String>[];
    for (final q in queries) {
      final cached = _searchCachedArtists(q, exact: exact);
      if (cached != null && cached.isNotEmpty && exact) {
        result.add(cached.first);
      } else
        uncached.add(q);
    }
    for (final q in uncached) {
      final res = await _callApis(
        q,
        exact: exact,
        limit: limit,
        offset: offset,
        paginated: paginated,
      );
      if (res.isNotEmpty) result.addAll(res);
    }

    return result;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
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
          final urls =
              List.from(
                artist['relations'] ?? [],
              ).where((e) => e['type'] == 'discogs').toList();
          if (urls.isNotEmpty) {
            final discogsUrl = urls[0]['url']['resource'];
            final regex = RegExp(r'/artist/(\d+)');
            final match = regex.firstMatch(discogsUrl)?.group(1) ?? '';
            final dcRes = await _getArtistDetailsDC(match);
            final combined = await _combineResults({
              'mbRes': artist,
              'dcRes': dcRes,
            });
            results.add(combined);
          }
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

Future<Map<String, dynamic>> _combineResults(Map<String, dynamic> data) async {
  try {
    await Hive.openBox('cache').whenComplete(
      () =>
          cachedArtistsList = Hive.box(
            'cache',
          ).get('cachedArtists', defaultValue: []),
    );
    final mbRes = data['mbRes'];
    final dcRes = data['dcRes'];

    final id = 'mb=${mbRes['id']}&dc=${dcRes['id']}';
    final res = {
      'id': id,
      'artist': mbRes['name'],
      'musicbrainzName': mbRes['name'],
      'discogsName': dcRes['name'],
      'musicbrainz': mbRes,
      'discogs': dcRes,
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
    return cachedArtistsList.firstWhere((e) => e['id'] == id);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

/// Score is automatically 0 if exact = true
dynamic _searchCachedArtists(
  String query, {
  bool exact = true,
  double score = 0.1,
}) {
  try {
    if (exact) score = 0.0;
    final names =
        cachedArtistsList
            .map(
              (e) => {
                'id': e['id'],
                'musicbrainzName': e['musicbrainzName'],
                'discogsName': e['discogsName'],
              },
            )
            .toList();
    final List<WeightedKey<Map<String, dynamic>>> keys = [
      WeightedKey(
        name: 'musicbrainzName',
        getter: (e) => e['musicbrainzName'],
        weight: 1,
      ),
      WeightedKey(
        name: 'discogsName',
        getter: (e) => e['discogsName'],
        weight: 1,
      ),
    ];
    final fuzzy = Fuzzy(names, options: FuzzyOptions(threshold: 1, keys: keys));
    final sorted =
        fuzzy.search(query)
          ..where((e) => e.score <= 0.2)
          ..sort((a, b) {
            final scorecomp = a.score.compareTo(b.score);
            if (scorecomp != 0) {
              return scorecomp;
            }
            for (var i = 0; i < a.matches.length; i++) {
              final indexcomp = a.matches[i].arrayIndex.compareTo(
                b.matches[i].arrayIndex,
              );
              if (indexcomp != 0) {
                return indexcomp;
              }
            }
            return 0;
          });
    if (exact) {
      final filtered =
          sorted.where((e) => e.score.isNearlyZero(tolerance: 0.0001)).toList();
      if (filtered.isEmpty) {
        return null;
      }
      final id = filtered.first.item['id'];
      final result = cachedArtistsList.where((e) => e['id'] == id);
      if (result.isEmpty) {
        return null;
      }
      return [result.first];
    } else {
      final filtered = sorted.where((e) => e.score <= score);
      final idSet = filtered.map((map) => map.item['id']).toSet();
      final result = List<dynamic>.from(
        cachedArtistsList.where((e) {
          final id = e['id'];
          return idSet.contains(id);
        }).toList(),
      );
      return result;
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
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
    final res = await mb.artists.search(
      query,
      limit: limit,
      offset: offset,
      paginated: paginated,
    );

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
      if (result.isNotEmpty)
        if (exact) {
          final artistId =
              _results.firstWhere(
                (e) => e['id'] == result.first.item['id'],
              )['id'];
          final finalResult = await mb.artists.get(artistId, inc: inc);
          return [finalResult];
        } else {
          final finalResult = [];
          for (final artist in result) {
            finalResult.add(await mb.artists.get(artist.item['id'], inc: inc));
          }
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
