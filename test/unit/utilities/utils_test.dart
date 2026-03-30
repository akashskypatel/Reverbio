/*
 * Unit tests for utils.dart - pure functions subset.
 * Tests only functions that don't access globals on happy path.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/utilities/utils.dart';

void main() {
  group('isUrl', () {
    test('accepts https URL', () {
      expect(isUrl('https://example.com'), isTrue);
    });

    test('accepts http URL with query', () {
      expect(isUrl('http://example.com/path?q=1'), isTrue);
    });

    test('rejects bare domain without scheme', () {
      expect(isUrl('example.com'), isFalse);
    });

    test('rejects non-URL string', () {
      expect(isUrl('not a url'), isFalse);
    });

    test('rejects empty string', () {
      expect(isUrl(''), isFalse);
    });
  });

  group('isFilePath', () {
    test('accepts Unix path', () {
      expect(isFilePath('/home/user/music.mp3'), isTrue);
    });

    test('accepts Windows path', () {
      expect(isFilePath(r'C:\Users\music.mp3'), isTrue);
    });

    test('rejects URL', () {
      expect(isFilePath('https://example.com'), isFalse);
    });
  });

  group('isImage', () {
    test('accepts jpg', () {
      expect(isImage('photo.jpg'), isTrue);
    });

    test('accepts png lowercase', () {
      expect(isImage('photo.png'), isTrue);
    });

    test('accepts webp', () {
      expect(isImage('photo.webp'), isTrue);
    });

    test('rejects mp3', () {
      expect(isImage('audio.mp3'), isFalse);
    });

    test('rejects empty string', () {
      expect(isImage(''), isFalse);
    });
  });

  group('isAudio', () {
    test('accepts mp3', () {
      expect(isAudio('track.mp3'), isTrue);
    });

    test('accepts flac', () {
      expect(isAudio('track.flac'), isTrue);
    });

    test('accepts opus', () {
      expect(isAudio('track.opus'), isTrue);
    });

    test('rejects jpg', () {
      expect(isAudio('image.jpg'), isFalse);
    });
  });

  group('getFileExtension', () {
    test('returns extension for mp3', () {
      expect(getFileExtension('track.mp3'), equals('.mp3'));
    });

    test('returns empty for no extension', () {
      expect(getFileExtension('no_extension'), equals(''));
    });

    test('returns last extension for double extension', () {
      expect(getFileExtension('archive.tar.gz'), equals('.gz'));
    });
  });

  group('stableHash', () {
    test('same input produces same hash', () {
      final hash1 = stableHash('hello');
      final hash2 = stableHash('hello');
      expect(hash1, equals(hash2));
    });

    test('different inputs produce different hashes', () {
      final hash1 = stableHash('hello');
      final hash2 = stableHash('world');
      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('joinIfNotEmpty', () {
    test('joins non-empty strings', () {
      expect(joinIfNotEmpty(['a', 'b', 'c'], '-'), equals('a-b-c'));
    });

    test('skips nulls and empty strings', () {
      expect(joinIfNotEmpty(['a', null, '', 'b'], '-'), equals('a-b'));
    });

    test('returns empty string for all nulls', () {
      expect(joinIfNotEmpty([null, null], '-'), equals(''));
    });

    test('returns empty string for empty list', () {
      expect(joinIfNotEmpty([], '-'), equals(''));
    });
  });

  group('getFileNameFromUrl', () {
    test('extracts filename from URL path', () {
      expect(
        getFileNameFromUrl('https://example.com/path/file.mp3'),
        equals('file.mp3'),
      );
    });

    test('extracts filename with query params', () {
      expect(
        getFileNameFromUrl('https://example.com/file.mp3?token=abc'),
        equals('file.mp3'),
      );
    });
  });

  group('ensureReverbioPath', () {
    test('appends reverbio suffix', () {
      final result = ensureReverbioPath('/music');
      expect(result, contains('reverbio'));
    });

    test('no double-append', () {
      final result = ensureReverbioPath('/music/reverbio');
      expect(result, contains('reverbio'));
      // Should not have double reverbio
      expect(result.split('reverbio').length - 1, equals(1));
    });
  });

  group('withinPercent', () {
    test('values within threshold', () {
      expect(withinPercent(100.0, 105.0, 10.0), isTrue);
    });

    test('values outside threshold', () {
      expect(withinPercent(100.0, 115.0, 10.0), isFalse);
    });

    test('zero values', () {
      expect(withinPercent(0.0, 0.0, 0.0), isTrue);
    });
  });

  group('isMobilePlatform', () {
    test('returns bool without throwing', () {
      expect(isMobilePlatform(), isA<bool>());
    });
  });

  group('tryEncode/tryDecode', () {
    test('encode object to JSON', () {
      final result = tryEncode({'key': 'value'});
      expect(result, contains('key'));
      expect(result, contains('value'));
    });

    test('encode null returns string null', () {
      expect(tryEncode(null), equals('null'));
    });

    test('decode JSON string', () {
      final result = tryDecode('{"key":"value"}');
      expect(result, isA<Map>());
      expect(result!['key'], equals('value'));
    });

    test('decode invalid JSON returns null', () {
      expect(tryDecode('not json'), isNull);
    });

    test('decode null returns null', () {
      expect(tryDecode(null), isNull);
    });
  });

  group('tryParseDate', () {
    test('parses valid date string', () {
      final result = tryParseDate('2024-01-15');
      expect(result.year, equals(2024));
      expect(result.month, equals(1));
      expect(result.day, equals(15));
    });

    test('null returns current date', () {
      final result = tryParseDate(null);
      expect(result, isA<DateTime>());
    });

    test('invalid string returns current date', () {
      final result = tryParseDate('not a date');
      expect(result, isA<DateTime>());
    });
  });

  group('pickRandomItem', () {
    test('returns item from list', () {
      final result = pickRandomItem([1, 2, 3]);
      expect([1, 2, 3], contains(result));
    });

    test('empty list returns null', () {
      expect(pickRandomItem([]), isNull);
    });
  });

  group('pickRandomItems', () {
    test('returns exactly n items', () {
      final result = pickRandomItems([1, 2, 3, 4, 5], 3);
      expect(result.length, equals(3));
    });

    test('no duplicates in result', () {
      final result = pickRandomItems([1, 2, 3, 4, 5], 3);
      final unique = result.toSet();
      expect(unique.length, equals(result.length));
    });

    test('empty list returns empty', () {
      expect(pickRandomItems([], 3), equals([]));
    });
  });

  group('safeConvert', () {
    test('converts list of maps', () {
      final result = safeConvert([{'a': 1}, {'b': 2}]);
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.length, equals(2));
    });

    test('non-list returns empty list', () {
      expect(safeConvert('not a list'), equals([]));
    });

    test('null returns empty list', () {
      expect(safeConvert(null), equals([]));
    });
  });

  group('parseTimeStringToSeconds', () {
    test('parses minutes:seconds', () {
      expect(parseTimeStringToSeconds('1:23'), equals(83));
    });

    test('parses zero time', () {
      expect(parseTimeStringToSeconds('0:00'), equals(0));
    });

    test('parses hours:minutes:seconds', () {
      expect(parseTimeStringToSeconds('1:00:00'), equals(3600));
    });
  });

  group('tryParseDuration', () {
    test('parses minutes:seconds string', () {
      final result = tryParseDuration('3:45');
      expect(result, equals(const Duration(minutes: 3, seconds: 45)));
    });

    test('invalid string returns null', () {
      expect(tryParseDuration('bad'), isNull);
    });
  });

  group('splitArtists', () {
    test('splits on comma and feat', () {
      final result = splitArtists('Artist A, Artist B feat. Artist C');
      expect(result, contains('Artist A'));
      expect(result, contains('Artist B'));
      expect(result, contains('Artist C'));
    });
  });

  group('copyMap', () {
    test('deep copy - nested map mutation does not affect original', () {
      final original = {'key': 'val', 'nested': {'a': 1}};
      final copy = copyMap(original);
      (copy['nested'] as Map)['a'] = 99;
      expect((original['nested'] as Map)['a'], equals(1));
    });

    test('null returns empty map', () {
      expect(copyMap(null), equals({}));
    });

    test('deep copy - list mutation does not affect original', () {
      final original = {'list': [1, 2, 3]};
      final copy = copyMap(original);
      (copy['list'] as List).add(4);
      expect((original['list'] as List).length, equals(3));
    });
  });

  group('getExtensionFromMime', () {
    test('audio/mpeg returns .mp3', () {
      expect(getExtensionFromMime('audio/mpeg'), equals('.mp3'));
    });

    test('audio/flac returns extension', () {
      final result = getExtensionFromMime('audio/flac');
      expect(result, isNotEmpty);
    });

    test('image/jpeg returns .jpg', () {
      expect(getExtensionFromMime('image/jpeg'), equals('.jpg'));
    });

    test('image/png returns .png', () {
      expect(getExtensionFromMime('image/png'), equals('.png'));
    });

    test('null returns default extension', () {
      final result = getExtensionFromMime(null);
      expect(result, isNotEmpty);
    });

    test('unknown type returns default extension', () {
      final result = getExtensionFromMime('unknown/type');
      expect(result, isNotEmpty);
    });
  });

  group('removeDuplicates', () {
    test('removes adjacent duplicates', () {
      expect(
        removeDuplicates('the the quick quick fox'),
        equals('the quick fox'),
      );
    });

    test('no duplicates returns unchanged', () {
      expect(removeDuplicates('hello world'), equals('hello world'));
    });

    test('empty string returns empty', () {
      expect(removeDuplicates(''), equals(''));
    });
  });

  group('sanitizeSongTitle', () {
    test('strips Official Music Video suffix', () {
      final result = sanitizeSongTitle('Song Title (Official Music Video)');
      expect(result, isNot(contains('(Official Music Video)')));
    });

    test('strips HD suffix', () {
      final result = sanitizeSongTitle('Song Title [HD]');
      expect(result, isNot(contains('[HD]')));
    });

    test('preserves meaningful content', () {
      final result = sanitizeSongTitle('Never Gonna Give You Up');
      expect(result, contains('Never'));
      expect(result, contains('Give'));
      expect(result, contains('You'));
      expect(result, contains('Up'));
    });
  });
}
