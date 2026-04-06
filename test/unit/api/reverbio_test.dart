/*
 * Unit tests for lib/API/reverbio.dart pure functions.
 * Tests ID parsing and entity comparison functions.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/API/reverbio.dart';

void main() {
  group('parseEntityId', () {
    test('null entity returns empty string', () {
      expect(parseEntityId(null), equals(''));
    });

    test('empty string returns empty string', () {
      expect(parseEntityId(''), equals(''));
    });

    test('string ID returns as-is', () {
      expect(parseEntityId('yt=abc&mb=xyz'), equals('yt=abc&mb=xyz'));
    });

    test('Map with id field returns id value', () {
      expect(
        parseEntityId(<String, dynamic>{'id': 'yt=abc&mb=xyz'}),
        equals('yt=abc&mb=xyz'),
      );
    });

    test('Map without id builds from fields', () {
      final result = parseEntityId(<String, dynamic>{'ytid': 'abc', 'mbid': 'xyz'});
      expect(result, contains('yt=abc'));
      expect(result, contains('mb=xyz'));
    });

    test('Map with all null ID fields returns empty string', () {
      expect(parseEntityId(<String, dynamic>{}), equals(''));
    });
  });

  group('checkEntityId — R4 operator precedence regression', () {
    test('matching song Maps by id field returns true', () {
      final song1 = <String, dynamic>{'id': 'yt=abc123'};
      final song2 = <String, dynamic>{'id': 'yt=abc123'};
      expect(checkEntityId(song1, song2), isTrue);
    });

    test('song Map vs matching ID string returns true', () {
      final song = <String, dynamic>{'id': 'yt=abc123'};
      expect(checkEntityId(song, 'yt=abc123'), isTrue);
    });

    test('song Map vs non-matching ID string returns false', () {
      final song = <String, dynamic>{'id': 'yt=abc123'};
      expect(checkEntityId(song, 'yt=different'), isFalse);
    });

    test('R4 regression: && / || precedence does not give false positives',
        () {
      expect(checkEntityId(<String, dynamic>{'id': 'yt=A'}, 'yt=B'), isFalse);
    });
  });
}
