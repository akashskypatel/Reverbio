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
import 'package:reverbio/repositories/playlist_repository.dart';
import 'package:reverbio/repositories/impl/playlist_repository_impl.dart';

/// Unit tests for PlaylistRepository implementation.
/// Tests getPlaylists, getPlaylistInfo, createCustomPlaylist, updatePlaylistList, updateLikeStatus.
void main() {
  late PlaylistRepository repository;

  setUp(() {
    repository = PlaylistRepositoryImpl();
  });

  group('PlaylistRepositoryImpl', () {
    group('getPlaylists', () {
      test('returns list when called without parameters', () async {
        final result = await repository.getPlaylists();
        expect(result, isA<List>());
      });

      test('returns list when onlyLiked is false', () async {
        final result = await repository.getPlaylists(onlyLiked: false);
        expect(result, isA<List>());
      });

      test('returns list when onlyLiked is true', () async {
        final result = await repository.getPlaylists(onlyLiked: true);
        expect(result, isA<List>());
      });
    });

    group('getPlaylistInfo', () {
      test('returns map or null for valid playlist', () async {
        final playlist = {'id': 'playlist1', 'title': 'Test Playlist'};
        final result = await repository.getPlaylistInfo(playlist);
        expect(result == null || result is Map<String, dynamic>, isTrue);
      });

      test('returns null for empty playlist', () async {
        final result = await repository.getPlaylistInfo({});
        expect(result, isNull);
      });
    });

    group('createCustomPlaylist', () {
      test('returns result for valid name', () {
        final result = repository.createCustomPlaylist('Test Playlist');
        // PlaylistOperationResult is returned
        expect(result, isNotNull);
      });

      test('returns result for empty name', () {
        final result = repository.createCustomPlaylist('');
        expect(result, isNotNull);
      });
    });

    group('updatePlaylistList', () {
      test('completes without error for valid id', () async {
        expect(() => repository.updatePlaylistList('playlist1'), returnsNormally);
      });

      test('completes without error for empty id', () async {
        expect(() => repository.updatePlaylistList(''), returnsNormally);
      });
    });

    group('updateLikeStatus', () {
      test('completes without error for add', () async {
        final playlist = {'id': 'playlist1', 'title': 'Test Playlist'};
        expect(() => repository.updateLikeStatus(playlist, true), returnsNormally);
      });

      test('completes without error for remove', () async {
        final playlist = {'id': 'playlist1', 'title': 'Test Playlist'};
        expect(() => repository.updateLikeStatus(playlist, false), returnsNormally);
      });
    });
  });
}
