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

import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';

/// H.1 fix: Extract pure metadata functions from song.dart
/// These are pure/near-pure functions with no async, no global-state mutation.

/// Get song title from song map with fallback hierarchy.
String songTitle(dynamic song) {
  if (song == null) return '';
  if (!(song is Map)) return '';
  return song['mbTitle'] ??
      song['title'] ??
      song['ytTitle'] ??
      song['song'] ??
      '';
}

/// Get song artist from song map with fallback hierarchy.
String songArtist(dynamic song) {
  if (song == null) return '';
  if (!(song is Map)) return '';
  return combineArtists(song) ??
      song['mbArtist'] ??
      song['artist'] ??
      song['ytArtist'] ??
      '';
}

/// Check if YouTube song is valid (has ytid, title, artist, and fetched flag).
bool isYouTubeSongValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final idValid = isSongIdKeyValid(song, idKey: 'yt');
  final titleValid = isSongTitleValid(song);
  final artistValid = isSongArtistValid(song);
  final isFetched = song['youtube'] != null && song['youtube'] == true;
  return idValid && titleValid && artistValid && isFetched;
}

/// Check if MusicBrainz song is valid (has mbid, title, artist, and fetched flag).
bool isMusicbrainzSongValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final idValid = isSongIdKeyValid(song, idKey: 'mb');
  final titleValid = isSongTitleValid(song);
  final artistValid = isSongArtistValid(song);
  final isFetched = song['musicbrainz'] != null && song['musicbrainz'] == true;
  return idValid && titleValid && artistValid && isFetched;
}

/// Check if song is valid (has id, title, and artist).
bool isSongValid(dynamic song) {
  final idValid = isSongIdValid(song);
  final titleValid = isSongTitleValid(song);
  final artistValid = isSongArtistValid(song);
  return idValid && titleValid && artistValid;
}

/// Check if song has valid id (non-empty id field).
bool isSongIdValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final isValid =
      song.isNotEmpty && song['id'] != null && song['id'].isNotEmpty;
  return isValid;
}

/// Check if song has valid id for specific key type (mbid, dcid, isrc, ucid, ytid, flnm).
bool isSongIdKeyValid(dynamic song, {String idKey = 'mbid'}) {
  if (song == null || !(song is Map)) return false;
  final id = parseEntityId(song);
  final ids = id.toIds;
  if (idKey == 'mbid' || idKey == 'mb')
    return song.isNotEmpty &&
        song['mbid'] != null &&
        song['mbid'].isNotEmpty &&
        (song['mbid'] as String).mbid.isNotEmpty &&
        ids['mb'] != null &&
        ids['mb']!.isNotEmpty &&
        (ids['mb'] as String).mbid.isNotEmpty;
  if (idKey == 'dcid' || idKey == 'dc')
    return song.isNotEmpty &&
        song['dcid'] != null &&
        song['dcid'].isNotEmpty &&
        (song['dcid'] as String).dcid.isNotEmpty &&
        ids['dc'] != null &&
        ids['dc']!.isNotEmpty &&
        (ids['dc'] as String).dcid.isNotEmpty;
  if (idKey == 'isrc' || idKey == 'is')
    return song.isNotEmpty &&
        song['isrc'] != null &&
        song['isrc'].isNotEmpty &&
        (song['isrc'] as String).isrc.isNotEmpty &&
        ids['is'] != null &&
        ids['is']!.isNotEmpty &&
        (ids['is'] as String).isrc.isNotEmpty;
  if (idKey == 'ucid' || idKey == 'uc')
    return song.isNotEmpty &&
        song['ucid'] != null &&
        song['ucid'].isNotEmpty &&
        (song['ucid'] as String).ucid.isNotEmpty &&
        ids['uc'] != null &&
        ids['uc']!.isNotEmpty &&
        (ids['uc'] as String).ucid.isNotEmpty;
  if (idKey == 'ytid' || idKey == 'yt')
    return song.isNotEmpty &&
        song['ytid'] != null &&
        song['ytid'].isNotEmpty &&
        (song['ytid'] as String).ytid.isNotEmpty &&
        ids['yt'] != null &&
        ids['yt']!.isNotEmpty &&
        (ids['yt'] as String).ytid.isNotEmpty;
  if (idKey == 'flnm' || idKey == 'fn')
    return song.isNotEmpty &&
        song['flnm'] != null &&
        song['flnm'].isNotEmpty &&
        (song['flnm'] as String).flnm.isNotEmpty &&
        ids['fn'] != null &&
        ids['fn']!.isNotEmpty &&
        (ids['fn'] as String).flnm.isNotEmpty;
  return false;
}

/// Check if song has valid title.
bool isSongTitleValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final title = songTitle(song);
  final isValid =
      song.isNotEmpty && (title.isNotEmpty && !title.toLowerCase().isUnknown);
  return isValid;
}

/// Check if song has valid artist.
bool isSongArtistValid(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final artist = songArtist(song).nullIfEmpty;
  final isValid =
      song.isNotEmpty &&
      (artist != null && artist.isNotEmpty && !artist.toLowerCase().isUnknown);
  return isValid;
}

/// Check if song is live recording.
bool isSongLive(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final relations = song['relations'] as List? ?? [];
  return relations.any((e) =>
      (e['type'] ?? '').toString().toLowerCase() == 'live' ||
      (e['type'] ?? '').toString().toLowerCase() == 'live recording');
}

/// Check if song is derivative (cover, remix, etc.).
bool isSongDerivative(dynamic song) {
  if (song == null || !(song is Map)) return false;
  final relations = song['relations'] as List? ?? [];
  final derivativeTypes = [
    'cover',
    'remix',
    'medley',
    'mashup',
    'sampling',
    'parody',
  ];
  for (final relation in relations) {
    final type = (relation['type'] ?? '').toString().toLowerCase();
    if (derivativeTypes.any(type.contains)) return true;
  }
  // Also check for derivative indicators in title
  final title = songTitle(song).toLowerCase();
  final derivativeRegex = RegExp(
    '(cover|remix|medley|mashup|sampling|parody|tribute|live version|acoustic version|instrumental)',
    caseSensitive: false,
  );
  return derivativeRegex.hasMatch(title);
}

/// Minimize song data for caching (removes pictures from audioTags).
Map<String, dynamic> minimizeSongData(dynamic song) {
  // R3 fix: Create a copy of audioTags before removing 'pictures' to avoid mutating input
  Map<String, dynamic>? audioTags;
  if (song['audioTags'] != null) {
    audioTags = Map<String, dynamic>.from(song['audioTags']);
    audioTags.remove('pictures');
  }
  return {
    'id': parseEntityId(song),
    'primary-type': song['primary-type'] ?? 'song',
    'title': songTitle(song),
    'artist': songArtist(song),
    'artist-credit': song['artist-credit'],
    'devicePath': song['devicePath'],
    // R4 fix: Don't cache songUrl - YouTube stream URLs expire and become stale
    'offlineAudioPath': song['offlineAudioPath'],
    'duration': song['duration'],
    'cachedAt': DateTime.now().toString(),
    'audioTags': audioTags,
    'image':
        song['validImage'] ??
        song['highResImage'] ??
        song['lowResImage'] ??
        song['image'],
  };
}

/// Check if two song references point to the same song.
bool checkSong(dynamic songA, dynamic songB) {
  // R16 fix: Use local variables instead of mutating input maps
  // R1499 fix: Pass Map copy to parseEntityId to prevent mutating original
  final idA = songA is Map ? parseEntityId(Map<String, dynamic>.from(songA)) : songA;
  final idB = songB is Map ? parseEntityId(Map<String, dynamic>.from(songB)) : songB;
  if (songA is String && songB is String)
    return (songA.isNotEmpty && songB.isNotEmpty) &&
        checkEntityId(songA, songB);
  if (songA is String && songB is Map)
    return (songA.isNotEmpty &&
            idB != null &&
            idB.isNotEmpty) &&
        (checkEntityId(songA, idB) ||
            checkEntityId(idB, songA));
  if (songB is String && songA is Map)
    return (songB.isNotEmpty &&
            idA != null &&
            idA.isNotEmpty) &&
        (checkEntityId(songB, idA) ||
            checkEntityId(idA, songB));
  if (idA == null ||
      idB == null ||
      idA.isEmpty ||
      idB.isEmpty)
    return checkTitleAndArtist(songA, songB);
  final idCheck = checkEntityId(idA, idB);
  final hashA = getSongHashCode(songA);
  final hashB = getSongHashCode(songB);
  final hashCheck =
      hashA != null &&
      hashB != null &&
      (getSongHashCode(songA) == getSongHashCode(songB));
  return idCheck || hashCheck;
}

/// Get song hash code based on title and artist.
int? getSongHashCode(dynamic song) {
  if (!(song is Map)) return null;
  if (!isSongTitleValid(song) || !isSongArtistValid(song)) return null;
  final title = songTitle(song).nullIfEmpty;
  final artist = songArtist(song).nullIfEmpty;
  // R2 fix: Add null guards instead of force-unwrapping nullable values
  if (title == null || artist == null) return null;
  return title.cleansed.toLowerCase().hashCode ^
      artist.cleansed.toLowerCase().hashCode;
}

/// Check if two songs have matching title and artist.
bool checkTitleAndArtist(dynamic songA, dynamic songB) {
  if (songA == null || songB == null) return false;
  if (!(songA is Map) || !(songB is Map)) return false;
  final titleA = songTitle(songA).cleansed.toLowerCase();
  final titleB = songTitle(songB).cleansed.toLowerCase();
  final artistA = songArtist(songA).cleansed.toLowerCase();
  final artistB = songArtist(songB).cleansed.toLowerCase();
  return titleA == titleB && artistA == artistB;
}

/// Get YouTube URL for a song.
String? youtubeUrl(dynamic song) {
  final ytid = song['ytid'];
  if (ytid == null || ytid.isEmpty) return null;
  return 'https://www.youtube.com/watch?v=$ytid';
}

/// Get MusicBrainz URL for a song.
String? musicbrainzUrl(dynamic song) {
  final mbid = song['rid'] ?? song['mbid'];
  if (mbid == null || mbid.isEmpty) return null;
  return 'https://musicbrainz.org/recording/$mbid';
}

/// Check if song is derivative from title components - helper for formatter.dart.
bool isSongDerivativeFromTitle(
  dynamic artist,
  dynamic album,
  dynamic title,
  dynamic value,
) {
  // Convert to lowercase and remove title/artist
  final replaced =
      value
          .toLowerCase()
          .replaceAll(title?.toLowerCase() ?? '', '')
          .replaceAll(album?.toLowerCase() ?? '', '')
          .replaceAll(artist?.toLowerCase() ?? '', '')
          .sanitized;

  final derivativeRegex = RegExp(
    '(cover|remix|medley|mashup|sampling|parody|tribute|live version|acoustic version|instrumental)',
    caseSensitive: false,
  );
  return derivativeRegex.hasMatch(replaced);
}
