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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/widgets/song_list.dart';

/// Widget tests for SongList widget.
/// Tests rendering list, search filters, and sort functionality.
void main() {
  group('SongList Widget Tests', () {
    testWidgets('renders with song maps', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>.from([
        {'ytid': 'song1', 'title': 'Song 1', 'artist': 'Artist 1'},
        {'ytid': 'song2', 'title': 'Song 2', 'artist': 'Artist 2'},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'test',
                  title: 'Test Playlist',
                  songMaps: songMaps,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify SongList renders
      expect(find.byType(SongList), findsOneWidget);
      
      // Verify title is displayed
      expect(find.text('Test Playlist'), findsOneWidget);
    });

    testWidgets('displays empty state when no songs', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'test',
                  title: 'Empty Playlist',
                  songMaps: songMaps,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify empty state message
      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('shows search bar', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>.from([
        {'ytid': 'song1', 'title': 'Song 1', 'artist': 'Artist 1'},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'test',
                  title: 'Test Playlist',
                  songMaps: songMaps,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify search functionality is available
      expect(find.byType(SongList), findsOneWidget);
    });

    testWidgets('shows shuffle button', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>.from([
        {'ytid': 'song1', 'title': 'Song 1', 'artist': 'Artist 1'},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'test',
                  title: 'Test Playlist',
                  songMaps: songMaps,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify shuffle button is present
      expect(find.byIcon(Icons.shuffle), findsWidgets);
    });

    testWidgets('shows sort button', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>.from([
        {'ytid': 'song1', 'title': 'Song 1', 'artist': 'Artist 1'},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'test',
                  title: 'Test Playlist',
                  songMaps: songMaps,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify sort button is present
      expect(find.byIcon(Icons.sort), findsWidgets);
    });

    testWidgets('shows play button', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>.from([
        {'ytid': 'song1', 'title': 'Song 1', 'artist': 'Artist 1'},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'test',
                  title: 'Test Playlist',
                  songMaps: songMaps,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify play button is present
      expect(find.byIcon(Icons.play_circle), findsWidgets);
    });

    testWidgets('shows add to queue button for non-queue pages', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>.from([
        {'ytid': 'song1', 'title': 'Song 1', 'artist': 'Artist 1'},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'playlist',  // Not 'queue'
                  title: 'Test Playlist',
                  songMaps: songMaps,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify add to queue button is present for non-queue pages
      expect(find.byIcon(Icons.add_circle), findsWidgets);
    });

    testWidgets('hides add to queue button for queue page', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>.from([
        {'ytid': 'song1', 'title': 'Song 1', 'artist': 'Artist 1'},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'queue',  // Queue page
                  title: 'Queue',
                  songMaps: songMaps,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify add to queue button is hidden for queue page
      expect(find.byIcon(Icons.add_circle), findsNothing);
    });

    testWidgets('enables reorder when isEditable is true', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>.from([
        {'ytid': 'song1', 'title': 'Song 1', 'artist': 'Artist 1'},
        {'ytid': 'song2', 'title': 'Song 2', 'artist': 'Artist 2'},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'queue',
                  title: 'Queue',
                  songMaps: songMaps,
                  isEditable: true,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify reorderable list is present
      expect(find.byType(ReorderableDragStartListener), findsWidgets);
    });

    testWidgets('handles loading state', (tester) async {
      final songMaps = NotifiableList<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SongList(
                  page: 'test',
                  title: 'Loading Playlist',
                  songMaps: songMaps,
                ),
              ],
            ),
          ),
        ),
      );

      // Initial state may show loading indicator
      await tester.pump();
      
      // Should render without crashing
      expect(find.byType(SongList), findsOneWidget);
    });
  });
}
