/*
 * Shared test fixtures for unit tests.
 * Contains reusable Map fixtures for songs, artists, albums, etc.
 */

import 'dart:io';

/// Minimal song Map with required fields for testing.
const Map<String, dynamic> kMinimalSong = {
  'id': 'yt=dQw4w9WgXcQ',
  'ytid': 'dQw4w9WgXcQ',
  'title': 'Never Gonna Give You Up',
  'artist': 'Rick Astley',
  'primary-type': 'song',
};

/// Song Map with audioTags containing pictures key (for mutation tests).
const Map<String, dynamic> kSongWithAudioTags = {
  ...kMinimalSong,
  'audioTags': {
    'title': 'Never Gonna Give You Up',
    'artist': 'Rick Astley',
    'pictures': [0xff, 0xd8, 0xff, 0xe0], // Fake JPEG bytes
  },
};

/// Minimal artist Map with required fields.
const Map<String, dynamic> kMinimalArtist = {
  'id': 'mb=artist123',
  'name': 'Test Artist',
  'source': 'musicbrainz',
  'primary-type': 'artist',
};

/// Minimal album Map with required fields.
const Map<String, dynamic> kMinimalAlbum = {
  'id': 'mb=album456',
  'title': 'Test Album',
  'artist': 'Test Artist',
  'primary-type': 'album',
};

/// Song with null ID (for edge case tests).
const Map<String, dynamic> kSongWithNullId = {
  'ytid': 'dQw4w9WgXcQ',
  'title': 'Never Gonna Give You Up',
  'artist': 'Rick Astley',
};

/// Song with empty ID (for edge case tests).
const Map<String, dynamic> kSongWithEmptyId = {
  'id': '',
  'ytid': 'dQw4w9WgXcQ',
  'title': 'Never Gonna Give You Up',
  'artist': 'Rick Astley',
};

/// Load a JSON fixture file from test/fixtures/.
String loadFixture(String filename) {
  return File('test/fixtures/$filename').readAsStringSync();
}
