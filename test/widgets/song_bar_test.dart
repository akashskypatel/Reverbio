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
import 'package:reverbio/widgets/song_bar.dart';

/// Widget tests for SongBar widget.
/// Tests rendering, onTap behavior, and context menu.
void main() {
  group('SongBar Widget Tests', () {
    testWidgets('renders with valid song data', (tester) async {
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongBar(songData),
          ),
        ),
      );

      // Verify SongBar renders
      expect(find.byType(SongBar), findsOneWidget);
      
      // Verify card is present
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('displays song title when loaded', (tester) async {
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongBar(songData),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify title text is displayed
      expect(find.text('Test Song'), findsOneWidget);
    });

    testWidgets('displays artist name when loaded', (tester) async {
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongBar(songData),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Verify artist text is displayed
      expect(find.text('Test Artist'), findsOneWidget);
    });

    testWidgets('handles missing title gracefully', (tester) async {
      final songData = {
        'ytid': 'abc123',
        'artist': 'Test Artist',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongBar(songData),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Should still render without crashing
      expect(find.byType(SongBar), findsOneWidget);
    });

    testWidgets('handles missing artist gracefully', (tester) async {
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongBar(songData),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Should still render without crashing
      expect(find.byType(SongBar), findsOneWidget);
    });

    testWidgets('tapping song bar triggers onTap', (tester) async {
      bool tapped = false;
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () => tapped = true,
              child: SongBar(songData),
            ),
          ),
        ),
      );

      // Tap the SongBar
      await tester.tap(find.byType(SongBar));
      await tester.pumpAndSettle();
      
      // Verify tap was registered
      expect(tapped, isTrue);
    });

    testWidgets('shows download icon for offline songs', (tester) async {
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
        'offlineAudioPath': '/path/to/file.mp3',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongBar(songData),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Should show download icon
      expect(find.byIcon(Icons.download), findsWidgets);
    });

    testWidgets('applies custom border radius', (tester) async {
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongBar(
              songData,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Should render without error
      expect(find.byType(SongBar), findsOneWidget);
    });

    testWidgets('applies custom background color', (tester) async {
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongBar(
              songData,
              backgroundColor: Colors.blue,
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Should render without error
      expect(find.byType(SongBar), findsOneWidget);
    });

    testWidgets('long press shows context menu', (tester) async {
      final songData = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongBar(songData),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();
      
      // Long press to show context menu
      await tester.longPress(find.byType(SongBar));
      await tester.pumpAndSettle();
      
      // Verify popup menu appears
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });
}
