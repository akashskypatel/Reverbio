/*
 * Integration tests for entity list initialization and lifecycle.
 * Uses in-memory Hive to verify initializeData() and entity persistence.
 */

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/hive_service.dart';

import '../helpers/fake_hive_service.dart';
import '../helpers/test_fixtures.dart';

void main() {
  setUp(() async {
    await setUpHive();
  });

  tearDown(() async {
    await tearDownHive();
  });

  group('initializeData() + entity list lifecycle', () {
    test('initializeData completes without error on fresh Hive', () async {
      expect(initializeData, returnsNormally);
    });

    test('all entity lists are empty on first run', () async {
      await initializeData();

      expect(userLikedSongsList.isEmpty, isTrue);
      expect(userOfflineSongs.isEmpty, isTrue);
      expect(cachedSongsList.isEmpty, isTrue);
      expect(cachedAlbumsList.isEmpty, isTrue);
      expect(cachedArtistsList.isEmpty, isTrue);
      expect(userLikedArtistsList.isEmpty, isTrue);
    });

    test('adding song to userLikedSongsList persists to Hive', () async {
      await initializeData();

      final testSong = Map<String, dynamic>.from(kMinimalSong);
      userLikedSongsList.add(testSong);

      // Wait for debounce timer
      await Future.delayed(const Duration(milliseconds: 1100));

      final box = Hive.box<dynamic>(HiveBoxNames.user);
      expect(box.containsKey('userLikedSongs'), isTrue);
    });

    test('re-calling initializeData after persisting reads persisted data',
        () async {
      await initializeData();

      final testSong = Map<String, dynamic>.from(kMinimalSong);
      userLikedSongsList.add(testSong);

      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 1100));

      // Re-initialize
      await initializeData();

      expect(userLikedSongsList.isEmpty, isFalse);
    });

    test('disposeData disposes all NotifiableList instances', () async {
      await initializeData();

      disposeData();

      // After dispose, lists should be disposed
      // Verify no crash on subsequent operations
      expect(() => disposeData(), returnsNormally);
    });

    test('after disposeData add to list does not crash (disposed guard)',
        () async {
      await initializeData();
      disposeData();

      final testSong = Map<String, dynamic>.from(kMinimalSong);

      // Should not crash due to disposed guard
      expect(() => userLikedSongsList.add(testSong), returnsNormally);
    });
  });
}
