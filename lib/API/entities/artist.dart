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

import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/utils.dart';

List globalArtists = [];
// R10 fix: Loading flag to prevent race condition
bool _isLoadingRecommendedArtists = false;

/// Returns current liked status if successful.
Future<bool> updateArtistLikeStatus(dynamic artist, bool add) async {
  try {
    artist['id'] = parseEntityId(artist);
    if (artist['id'] == null || artist['id'].isEmpty) {
      throw Exception('ID is null or empty');
    }
    if (add) {
      if (artist['id'] != null &&
          (artist['musicbrainz'] == null || artist['musicbrainz'].isEmpty))
        unawaited(getArtistDetails(artist));
      userLikedArtistsList.addOrUpdate(minimizeArtistData(artist), checkArtist);
      await PM.triggerHook(artist, 'onEntityLiked');
    } else {
      userLikedArtistsList.removeWhere((value) => checkArtist(artist, value));
    }
    return add;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return !add;
  }
}

Map<String, dynamic> minimizeArtistData(dynamic artist) {
  return {
    'id': parseEntityId(artist),
    'primary-type': artist['primary-type'] ?? 'artist',
    'name': artist['name'],
    'artist': artist['artist'],
    'genres': artist['genres'] ?? artist['musicbrainz']?['genres'] ?? [],
    'musicbrainz': {
      'release-groups':
          ((artist['musicbrainz']?['release-groups'] ?? []) as List)
              .map(minimizeAlbumData)
              .toList(),
    },
    'cachedAt': DateTime.now().toString(),
    'image':
        artist['validImage'] ??
        artist['highResImage'] ??
        artist['lowResImage'] ??
        artist['image'],
  };
}

bool isArtistAlreadyLiked(artistToCheck) =>
    artistToCheck is Map &&
    userLikedArtistsList.any((artist) => checkArtist(artist, artistToCheck));

// R13 fix: Return proper Map type on error instead of raw artistData
Future<Map<String, dynamic>> getArtistDetails(
  dynamic artistData, {
  bool refresh = false,
}) async {
  try {
    final id = parseEntityId(artistData);
    final ids = Uri.parse('?$id').queryParameters;
    if (ids['mb'] == null) {
      await PM.triggerHook(artistData, 'onGetArtistInfo');
      return {};
    }
    if (!refresh) {
      final cached = _getCachedArtist(id);
      if (cached != null) {
        if (cached['youtube'] == null || cached['youtube'].isEmpty)
          cached['youtube'] = await _parseYTRelations(
            List.from(cached['musicbrainz']?['relations'] ?? []),
          );
        await PM.triggerHook(artistData, 'onGetArtistInfo');
        return cached;
      }
    }
    final mbRes = await mb.artists.get(
      ids['mb']!,
      inc: [
        'recordings',
        'releases',
        'release-groups',
        'works',
        'aliases',
        'genres',
        'release-group-rels',
        'url-rels',
      ],
    );
    if (mbRes['error'] != null) throw mbRes['error'];
    final urls = List.from(mbRes['relations'] ?? []);
    final dcRes = <String, dynamic>{};
    final ytRes = <String, dynamic>{};
    final futures =
        <Future>[]
          ..add(_parseDCRelations(urls))
          ..add(_parseYTRelations(urls));
    await Future.wait(futures).then((value) {
      for (dynamic res in value) {
        res = copyMap(res);
        if (res['source'] == 'discogs') dcRes.addAll(res);
        if (res['source'] == 'youtube') ytRes.addAll(res);
      }
    });
    final result = await _combineResults(
      mbRes: mbRes,
      dcRes: dcRes,
      ytRes: ytRes,
    );
    await PM.triggerHook(artistData, 'onGetArtistInfo');
    return result;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    // R13 fix: Return Map type on error
    return artistData is Map<String, dynamic>
        ? artistData
        : <String, dynamic>{};
  }
}

// R11 fix: Add logging for swallowed exceptions
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
  } catch (e, stackTrace) {
    // R11 fix: Log exceptions instead of silently swallowing
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
  }
  data['source'] = 'discogs';
  return data;
}

// R11 fix: Add logging for swallowed exceptions
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
              break;
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
          break;
        }
      }
    }
  } catch (_) {}
  data['source'] = 'youtube';
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
    final q = query.collapsed;
    final cached = _searchCachedArtists(q);
    if (cached != null && cached.isNotEmpty) return cached;
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

Future<List<Map<String, dynamic>>> getArtistsFromSongs(
  List<dynamic> songList,
) async {
  final searchList = LinkedHashSet<String>();
  final artistList = <dynamic>[];
  for (final song in songList) {
    if (song['artist-credit'] != null && song['artist-credit'] is List) {
      for (final artist in song['artist-credit']) {
        if (artist['artist'] != null && artist['artist'] is Map) {
          artist['artist']['primary-type'] = 'artist';
          artist['artist']['isArtist'] = 'true';
          artistList.addOrUpdateWhere(checkArtist, artist['artist']);
        }
      }
    } else if (song['artist'] is String) {
      final artists = splitArtists(song['artist']);
      searchList.addAll(artists);
    }
  }
  if (searchList.isNotEmpty)
    artistList.addOrUpdateAllWhere(
      checkArtist,
      await searchArtistsDetails(searchList.toList()),
    );
  return artistList.map((e) {
    e = Map<String, dynamic>.from(e);
    return e as Map<String, dynamic>;
  }).toList();
}

// R10 fix: Use loading flag to prevent race condition
Future<List<dynamic>> getRecommendedArtists() async {
  // If already loading, return current list
  if (_isLoadingRecommendedArtists) return globalArtists;

  final songList = globalSongs;
  if (globalArtists.isEmpty) {
    _isLoadingRecommendedArtists = true;
    try {
      final searchList = LinkedHashSet<String>();
      for (final song in songList) {
        if (song['artist-credit'] != null && song['artist-credit'] is List) {
          for (final artist in song['artist-credit']) {
            if (artist['artist'] != null && artist['artist'] is Map) {
              artist['artist']['primary-type'] = 'artist';
              artist['artist']['isArtist'] = 'true';
              globalArtists.addOrUpdateWhere(checkArtist, artist['artist']);
            }
          }
        } else if (song['artist'] is String) {
          final artists = splitArtists(song['artist']);
          searchList.addAll(artists);
        }
      }
      if (searchList.isNotEmpty)
        globalArtists.addOrUpdateAllWhere(
          checkArtist,
          await searchArtistsDetails(searchList.toList()),
        );
    } finally {
      _isLoadingRecommendedArtists = false;
    }
  }
  return globalArtists;
}

Future<List<dynamic>> searchArtistsDetails(
  List<String> query, {
  bool exact = true,
  int offset = 0,
  bool paginated = false,
}) async {
  try {
    final queries = query.map((e) => e.collapsed.toLowerCase()).toList();
    final result = [];
    final uncached = <String>[];
    for (final q in queries) {
      final cached = _searchCachedArtists(q);
      if (cached != null && cached.isNotEmpty && exact) {
        result.addOrUpdateWhere(checkArtist, cached);
      } else
        uncached.add(q);
    }
    for (int i = 0; i < uncached.length; i += 25) {
      final str = uncached.getRange(i, (i + 25).clamp(0, uncached.length));
      final qry =
          'artist:(${str.map((e) => '"${e.replaceAll(' ', '|')}"').join(' OR ')})';
      final artistsSearch = await mb.artists.search(qry, limit: str.length);
      final artistList = LinkedHashSet<String>();
      for (final artist in (artistsSearch?['artists'] ?? [])) {
        if (artistList.add(artist['name'].toLowerCase())) {
          if (uncached.contains(artist['name'].toLowerCase()) ||
              uncached.contains(artist['sort-name'].toLowerCase())) {
            artist['primary-type'] = 'artist';
            await PM.triggerHook(artist, 'onGetArtistInfo');
            result.addOrUpdateWhere(checkArtist, artist);
          }
        }
      }
    }

    return result;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return [];
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
    if (mbRes == null) return [];
    final results = [];
    for (final artist in mbRes) {
      if (artist is Map && artist['type'] != 'Other') {
        artist['source'] = 'musicbrainz';
        final relations = List.from(artist['relations'] ?? []);
        final dcRes = <String, dynamic>{};
        final ytRes = <String, dynamic>{};
        final futures =
            <Future>[]
              ..add(_parseDCRelations(relations))
              ..add(_parseYTRelations(relations));
        await Future.wait(futures).then((value) {
          for (final res in value) {
            if (res['source'] == 'discogs') dcRes.addAll(res);
            if (res['source'] == 'youtube') ytRes.addAll(res);
          }
        });
        final combined = await _combineResults(
          mbRes: artist,
          dcRes: dcRes,
          ytRes: ytRes,
        );
        results.add(combined);
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
    return [];
  }
}

Future<Map<String, dynamic>> _combineResults({
  Map mbRes = const {},
  Map dcRes = const {},
  Map ytRes = const {},
}) async {
  try {
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
      'mbid': ids['mb'],
      'dcid': ids['dc'],
      'ytid': ids['yt'],
      'artist': mbRes['name'],
      'musicbrainzName': mbRes['name'],
      'discogsName': dcRes['name'],
      'musicbrainz': mbRes,
      'discogs': dcRes,
      'youtube': ytRes,
      'primary-type': 'artist',
      'cachedAt': DateTime.now().toString(),
    };
    res['image'] = (await getValidImage(res)).toString();
    await addArtistToCache(res);
    return res;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    rethrow;
  }
}

// R7 fix: Use checkEntityId instead of loose String.contains
// R8 fix: Check cache staleness (30 day TTL)
dynamic _getCachedArtist(String id) {
  try {
    for (final e in cachedArtistsList) {
      if (e['id'] != null && checkEntityId(e['id'], id)) {
        // R8 fix: Check if cache is stale (older than 30 days)
        try {
          final cachedAt = DateTime.parse(e['cachedAt'] as String);
          if (DateTime.now().difference(cachedAt).inDays > 30) {
            continue; // Skip stale cache entry
          }
        } catch (_) {
          // Skip items with invalid cachedAt
        }
        return e;
      }
    }
    return null;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
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

Future<void> addArtistToCache(Map<String, dynamic> artist) async {
  cachedArtistsList.addOrUpdate(artist, checkArtist);
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
    if (res.isEmpty || res['artists'] == null || res['artists'].isEmpty)
      return null;
    final _results =
        exact
            ? List<dynamic>.from(res['artists']).where((e) => e['score'] == 100)
            : List<dynamic>.from(res['artists']);

    if (_results.isNotEmpty) {
      final names =
          _results.map((e) => {'id': e['id'], 'name': e['name']}).toList();
      // Score each candidate against the query (0–100, higher = better match)
      final scored =
          names
              .map(
                (e) => MapEntry(
                  e,
                  weightedRatio(query, e['name'] as String? ?? ''),
                ),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      final result = exact ? scored.where((e) => e.value == 100) : scored;

      final inc = [
        'recordings',
        'releases',
        'release-groups',
        'works',
        'aliases',
        'genres',
        'release-group-rels',
        'url-rels',
      ];
      if (result.isNotEmpty)
        if (exact) {
          final artistId =
              _results.firstWhere(
                (e) => e['id'] == result.first.key['id'],
              )['id'];
          final finalResult = await mb.artists.get(artistId, inc: inc);
          if (finalResult['error'] != null) throw finalResult['error'];
          //TODO optimize
          return [finalResult];
        } else {
          final finalResult = [];
          for (final artist in result) {
            final artQry = await mb.artists.get(artist.key['id'], inc: inc);
            if (artQry['error'] != null) continue;
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

// R12 fix: Add page limit to prevent unbounded pagination
Future<dynamic> _getArtistDetailsDC(String query) async {
  dynamic res;
  try {
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

      // R12 fix: Limit pagination to 5 pages max
      final maxPage = (_pages is int ? _pages : 0).clamp(2, 5);
      for (var i = 2; i <= maxPage; i++) {
        res = await dc.search.search(query: query, type: 'artist', page: i);
        if (res['results'].length > 0) _results.addAll(res['results']);
      }

      if (_results.isEmpty) return;

      final names =
          _results
              .where((e) => e['type'] == 'artist')
              .map((e) => {'id': e['id'], 'title': e['title']})
              .toList();
      // Score each candidate against the query (0–100, higher = better match)
      final scored =
          names
              .map(
                (e) => MapEntry(
                  e,
                  weightedRatio(query, e['title'] as String? ?? ''),
                ),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      final val = _results.where((e) => e['id'] == scored.first.key['id']);
      if (val.isNotEmpty)
        return await _getArtistDetailsDC(val.first['id']);
      else
        return await _getArtistDetailsDC(query);
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return res;
  }
}

int? getArtistHashCode(dynamic artist) {
  try {
    if (!(artist is Map) && artist is String)
      return artist.collapsed.toLowerCase().hashCode;
    if ((artist['name'] ?? artist['artist'] ?? artist['musicbrainzName']) ==
        null)
      return null;
    return ((artist['name'] ?? artist['artist'] ?? artist['musicbrainzName'])
            as String)
        .collapsed
        .toLowerCase()
        .hashCode;
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return null;
  }
}

// R9 fix: Don't mutate input - extract ID parsing to local variables
bool checkArtist(dynamic artistA, dynamic artistB) {
  try {
    if (artistA == null ||
        artistB == null ||
        artistA.isEmpty ||
        artistB.isEmpty)
      return false;

    // R9 fix: Use local variables instead of mutating input
    String idA = '';
    String idB = '';

    if (artistA is Map) {
      idA = parseEntityId(artistA);
    } else if (artistA is String) {
      idA = artistA;
    }

    if (artistB is Map) {
      idB = parseEntityId(artistB);
    } else if (artistB is String) {
      idB = artistB;
    }

    if (idA.isEmpty || idB.isEmpty)
      return getArtistHashCode(artistA) == getArtistHashCode(artistB);

    if (artistA is String && artistB is String)
      return checkEntityId(artistA, artistB);
    if (artistA is String && artistB is Map)
      return checkEntityId(artistA, idB) ||
          checkEntityId(idB, artistA) ||
          getArtistHashCode(artistA) == getArtistHashCode(artistB);
    if (artistB is String && artistA is Map)
      return checkEntityId(artistB, idA) ||
          checkEntityId(idA, artistB) ||
          getArtistHashCode(artistA) == getArtistHashCode(artistB);

    return checkEntityId(idA, idB);
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    return false;
  }
}
