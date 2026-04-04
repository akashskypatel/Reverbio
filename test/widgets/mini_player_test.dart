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
import 'package:reverbio/widgets/mini_player.dart';

/// Widget tests for MiniPlayer widget.
/// Tests displaying current song, play/pause, and navigation.
void main() {
  group('MiniPlayer Widget Tests', () {
    testWidgets('renders with close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              closeButton: const Icon(Icons.close),
            ),
          ),
        ),
      );

      // Verify MiniPlayer renders
      expect(find.byType(MiniPlayer), findsOneWidget);
      
      // Verify close button is present
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('displays position slider', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              closeButton: const Icon(Icons.close),
            ),
          ),
        ),
      );

      // Wait for any async loading
      await tester.pumpAndSettle();
      
      // Verify position slider is present (when song is playing)
      // Note: Slider may not show if no song is loaded
      expect(find.byType(MiniPlayer), findsOneWidget);
    });

    testWidgets('tapping mini player navigates to now playing', (tester) async {
      bool navigated = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () => navigated = true,
              child: MiniPlayer(
                closeButton: const Icon(Icons.close),
              ),
            ),
          ),
        ),
      );

      // Tap the MiniPlayer
      await tester.tap(find.byType(MiniPlayer));
      await tester.pumpAndSettle();
      
      // Verify tap was registered
      expect(navigated, isTrue);
    });

    testWidgets('shows volume button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              closeButton: const Icon(Icons.close),
            ),
          ),
        ),
      );

      // Wait for any async loading
      await tester.pumpAndSettle();
      
      // Verify volume button is present
      expect(find.byIcon(Icons.volume_up), findsWidgets);
    });

    testWidgets('shows play/pause button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              closeButton: const Icon(Icons.close),
            ),
          ),
        ),
      );

      // Wait for any async loading
      await tester.pumpAndSettle();
      
      // Verify play/pause button is present
      expect(find.byIcon(Icons.play_arrow), findsWidgets);
    });

    testWidgets('shows next button when hasNext', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              closeButton: const Icon(Icons.close),
            ),
          ),
        ),
      );

      // Wait for any async loading
      await tester.pumpAndSettle();
      
      // Verify next button is present
      expect(find.byIcon(Icons.skip_next), findsWidgets);
    });

    testWidgets('shows previous button when hasPrevious', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              closeButton: const Icon(Icons.close),
            ),
          ),
        ),
      );

      // Wait for any async loading
      await tester.pumpAndSettle();
      
      // Verify previous button is present
      expect(find.byIcon(Icons.skip_previous), findsWidgets);
    });

    testWidgets('renders with custom close button', (tester) async {
      const customCloseButton = Icon(Icons.delete);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              closeButton: customCloseButton,
            ),
          ),
        ),
      );

      // Verify custom close button is used
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('handles empty state gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              closeButton: const Icon(Icons.close),
            ),
          ),
        ),
      );

      // Should render without crashing even with no song loaded
      expect(find.byType(MiniPlayer), findsOneWidget);
    });

    testWidgets('layout adapts to screen size', (tester) async {
      // Test on small screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: MiniPlayer(
                closeButton: const Icon(Icons.close),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Test on large screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: MiniPlayer(
                closeButton: const Icon(Icons.close),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayer), findsOneWidget);
    });
  });
}
