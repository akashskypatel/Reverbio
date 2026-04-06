/*
 * Unit tests for lib/API/entities/song.dart pure accessors.
 * Tests song metadata accessors and minimize function.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/API/entities/song.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  group('songTitle', () {
    test('returns song[title] when present', () {
      final song = <String, dynamic>{...kMinimalSong, 'title': 'Test Title'};
      expect(songTitle(song), equals('Test Title'));
    });

    test('falls back to song[ytTitle] when title absent', () {
      final song = <String, dynamic>{...kMinimalSong}..remove('title');
      song['ytTitle'] = 'YouTube Title';
      expect(songTitle(song), equals('YouTube Title'));
    });

    test('returns empty string when both absent', () {
      final song = <String, dynamic>{...kMinimalSong}
        ..remove('title')
        ..remove('ytTitle');
      expect(songTitle(song), equals(''));
    });

    test('returns empty string on null input', () {
      expect(songTitle(null), equals(''));
    });
  });

  group('songArtist', () {
    test('returns song[artist] when present', () {
      final song = <String, dynamic>{...kMinimalSong, 'artist': 'Test Artist'};
      expect(songArtist(song), equals('Test Artist'));
    });

    test('falls back to song[ytArtist] when artist absent', () {
      final song = <String, dynamic>{...kMinimalSong}..remove('artist');
      song['ytArtist'] = 'YouTube Artist';
      expect(songArtist(song), equals('YouTube Artist'));
    });

    test('returns empty string when both absent', () {
      final song = <String, dynamic>{...kMinimalSong}
        ..remove('artist')
        ..remove('ytArtist');
      expect(songArtist(song), equals(''));
    });

    test('returns empty string on null input', () {
      expect(songArtist(null), equals(''));
    });
  });

  group('minimizeSongData — R3 mutation regression', () {
    test('returns Map containing expected keys', () {
      final song = <String, dynamic>{
        ...kMinimalSong,
        'image': 'img.jpg',
        'duration': 180,
        'highResImage': 'large.jpg',
      };

      final result = minimizeSongData(song);

      expect(result, contains('id'));
      expect(result, contains('title'));
      expect(result, contains('artist'));
      expect(result, contains('primary-type'));
    });

    test('does NOT include large fields like highResImage', () {
      final song = <String, dynamic>{
        ...kMinimalSong,
        'highResImage': 'large.jpg',
      };

      final result = minimizeSongData(song);

      expect(result, isNot(contains('highResImage')));
    });

    test('input song[audioTags] still has pictures key after call', () {
      final song = <String, dynamic>{...kSongWithAudioTags};

      minimizeSongData(song);

      // Original should still have 'pictures' key
      expect((song['audioTags'] as Map?)?.isNotEmpty, isTrue);
    });

    test('returned map audioTags does NOT have pictures key', () {
      final song = <String, dynamic>{...kSongWithAudioTags};

      final result = minimizeSongData(song);

      expect((result['audioTags'] as Map?)?.containsKey('pictures'), isFalse);
    });

    test('input with audioTags: null returns without crash', () {
      final song = <String, dynamic>{
        ...kMinimalSong,
        'audioTags': null,
      };

      expect(() => minimizeSongData(song), returnsNormally);
    });
  });
}
