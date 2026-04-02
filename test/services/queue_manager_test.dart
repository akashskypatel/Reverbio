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
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/services/queue_manager.dart';

/// Unit tests for queue_manager.dart activeQueue operations.
/// Note: Full integration tests require audioHandler mock.
void main() {
  group('activeQueue', () {
    setUp(() {
      // Reset activeQueue before each test
      activeQueue['id'] = '';
      activeQueue['ytid'] = '';
      activeQueue['title'] = 'No Songs in Queue';
      activeQueue['image'] = '';
      activeQueue['source'] = '';
      activeQueue['list'] = [];
    });

    test('activeQueue initializes with empty list', () {
      expect(activeQueue['list'], isEmpty);
      expect(activeQueue['title'], equals('No Songs in Queue'));
    });

    test('activeQueue list can add songs', () {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      final song2 = {'ytid': 'def456', 'title': 'Song 2'};
      
      activeQueue['list'].add(song1);
      activeQueue['list'].add(song2);
      
      expect(activeQueue['list'].length, equals(2));
      expect(activeQueue['list'][0]['ytid'], equals('abc123'));
      expect(activeQueue['list'][1]['ytid'], equals('def456'));
    });

    test('activeQueue list can remove songs', () {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      
      activeQueue['list'].add(song1);
      expect(activeQueue['list'].length, equals(1));
      
      activeQueue['list'].remove(song1);
      expect(activeQueue['list'], isEmpty);
    });

    test('activeQueue list remove returns true on success', () {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      
      activeQueue['list'].add(song1);
      final removed = activeQueue['list'].remove(song1);
      
      expect(removed, isTrue);
    });

    test('activeQueue list remove returns false when not found', () {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      
      final removed = activeQueue['list'].remove(song1);
      
      expect(removed, isFalse);
    });

    test('activeQueue can be cleared', () {
      activeQueue['list'].add({'ytid': 'abc123'});
      activeQueue['list'].add({'ytid': 'def456'});
      
      activeQueue['list'].clear();
      
      expect(activeQueue['list'], isEmpty);
    });

    test('activeQueue list maintains insertion order', () {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      final song2 = {'ytid': 'def456', 'title': 'Song 2'};
      final song3 = {'ytid': 'ghi789', 'title': 'Song 3'};
      
      activeQueue['list'].add(song1);
      activeQueue['list'].add(song2);
      activeQueue['list'].add(song3);
      
      expect(activeQueue['list'][0]['ytid'], equals('abc123'));
      expect(activeQueue['list'][1]['ytid'], equals('def456'));
      expect(activeQueue['list'][2]['ytid'], equals('ghi789'));
    });
  });
}
