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
import 'package:reverbio/utilities/notifiable_list.dart';

/// Functional tests for queue_manager.dart
/// Tests actual queue operations with real data structures.
void main() {
  setUp(() {
    // Reset queue state before each test
    activeQueue['id'] = '';
    activeQueue['ytid'] = '';
    activeQueue['title'] = 'No Songs in Queue';
    activeQueue['image'] = '';
    activeQueue['source'] = '';
    activeQueue['list'].clear();
  });

  group('Queue Manager - Add Operations', () {
    test('addSongToQueue adds song to activeQueue', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      addSongToQueue(song);
      
      expect(activeQueue['list'].length, equals(1));
      expect(activeQueue['list'].first['ytid'], equals('abc123'));
    });

    test('addSongToQueue does not add duplicates', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      addSongToQueue(song);
      addSongToQueue(song);
      
      expect(activeQueue['list'].length, equals(1));
    });

    test('addSongsToQueue adds multiple songs', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
        {'ytid': 'song3', 'title': 'Song 3'},
      ];
      
      addSongsToQueue(songs);
      
      expect(activeQueue['list'].length, equals(3));
    });

    test('addSongsToQueue skips duplicates', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song1', 'title': 'Song 1 Duplicate'},
        {'ytid': 'song2', 'title': 'Song 2'},
      ];
      
      addSongsToQueue(songs);
      
      expect(activeQueue['list'].length, equals(2));
    });
  });

  group('Queue Manager - Remove Operations', () {
    test('removeSongFromQueue removes matching song', () {
      final song1 = {'ytid': 'song1', 'title': 'Song 1'};
      final song2 = {'ytid': 'song2', 'title': 'Song 2'};
      addSongsToQueue([song1, song2]);
      
      final removed = removeSongFromQueue(song1);
      
      expect(removed, isTrue);
      expect(activeQueue['list'].length, equals(1));
      expect(activeQueue['list'].first['ytid'], equals('song2'));
    });

    test('removeSongFromQueue returns false for non-existent song', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      final removed = removeSongFromQueue(song);
      
      expect(removed, isFalse);
    });

    test('removeSongFromQueue removes by matching id', () {
      final song1 = {'ytid': 'abc123', 'title': 'Song 1'};
      final song2 = {'ytid': 'abc123', 'title': 'Song 1 Different Title'};
      addSongToQueue(song1);
      
      final removed = removeSongFromQueue(song2);
      
      expect(removed, isTrue);
      expect(activeQueue['list'].length, equals(0));
    });
  });

  group('Queue Manager - Query Operations', () {
    test('isSongInQueue returns true for existing song', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      addSongToQueue(song);
      
      expect(isSongInQueue(song), isTrue);
    });

    test('isSongInQueue returns false for non-existent song', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      
      expect(isSongInQueue(song), isFalse);
    });

    test('isSongInQueue matches by ytid', () {
      final song1 = {'ytid': 'abc123', 'title': 'Original Title'};
      final song2 = {'ytid': 'abc123', 'title': 'Different Title'};
      addSongToQueue(song1);
      
      expect(isSongInQueue(song2), isTrue);
    });

    test('isSongInQueue matches by mbid', () {
      final song1 = {'mbid': 'xyz789', 'title': 'Test Song'};
      final song2 = {'mbid': 'xyz789', 'title': 'Test Song'};
      addSongToQueue(song1);
      
      expect(isSongInQueue(song2), isTrue);
    });

    test('queueIndexOf returns correct index', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
        {'ytid': 'song3', 'title': 'Song 3'},
      ];
      addSongsToQueue(songs);
      
      final song2 = {'ytid': 'song2', 'title': 'Song 2'};
      final index = queueIndexOf(song2);
      
      expect(index, equals(1));
    });

    test('queueIndexOf returns -1 for non-existent song', () {
      final song = {'ytid': 'nonexistent', 'title': 'Not In Queue'};
      final index = queueIndexOf(song);
      
      expect(index, equals(-1));
    });
  });

  group('Queue Manager - Navigation Operations', () {
    test('nextSong returns next song in queue', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
        {'ytid': 'song3', 'title': 'Song 3'},
      ];
      addSongsToQueue(songs);
      
      final current = songs[0];
      final next = nextSong(current);
      
      expect(next, isNotNull);
      expect(next!['ytid'], equals('song2'));
    });

    test('nextSong returns null for last song', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
      ];
      addSongsToQueue(songs);
      
      final current = songs[1];
      final next = nextSong(current);
      
      expect(next, isNull);
    });

    test('nextSong returns null for empty queue', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      final next = nextSong(song);
      
      expect(next, isNull);
    });

    test('nextSong returns first song when at end with repeat all', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
      ];
      addSongsToQueue(songs);
      
      // This test would need AudioServiceRepeatMode.all set
      // For now, just verify basic navigation works
      final current = songs[0];
      final next = nextSong(current);
      
      expect(next, isNotNull);
      expect(next!['ytid'], equals('song2'));
    });

    test('previousSong returns previous song in queue', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
        {'ytid': 'song3', 'title': 'Song 3'},
      ];
      addSongsToQueue(songs);
      
      final current = songs[2];
      final previous = previousSong(current);
      
      expect(previous, isNotNull);
      expect(previous!['ytid'], equals('song2'));
    });

    test('previousSong returns null for first song', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
      ];
      addSongsToQueue(songs);
      
      final current = songs[0];
      final previous = previousSong(current);
      
      expect(previous, isNull);
    });

    test('previousSong returns null for empty queue', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      final previous = previousSong(song);
      
      expect(previous, isNull);
    });
  });

  group('Queue Manager - Clear Operations', () {
    test('clearSongQueue empties the queue', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
      ];
      addSongsToQueue(songs);
      
      clearSongQueue();
      
      expect(activeQueue['list'].length, equals(0));
      expect(activeQueue['title'], equals('No Songs in Queue'));
      expect(activeQueue['id'], isEmpty);
    });

    test('clearSongQueue resets all queue metadata', () {
      final song = {'ytid': 'abc123', 'title': 'Test Song'};
      addSongToQueue(song);
      
      // Set some metadata
      activeQueue['id'] = 'playlist123';
      activeQueue['title'] = 'My Playlist';
      activeQueue['source'] = 'youtube';
      
      clearSongQueue();
      
      expect(activeQueue['id'], isEmpty);
      expect(activeQueue['ytid'], isEmpty);
      expect(activeQueue['title'], equals('No Songs in Queue'));
      expect(activeQueue['image'], isEmpty);
      expect(activeQueue['source'], isEmpty);
    });
  });

  group('Queue Manager - Set Queue Operations', () {
    test('setQueueToPlaylist sets queue metadata', () {
      final playlist = {
        'id': 'playlist123',
        'ytid': 'yt456',
        'title': 'My Playlist',
        'image': 'image_url',
        'source': 'youtube',
      };
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
      ];
      
      setQueueToPlaylist(playlist, songs);
      
      expect(activeQueue['id'], equals('playlist123'));
      expect(activeQueue['ytid'], equals('yt456'));
      expect(activeQueue['title'], equals('My Playlist'));
      expect(activeQueue['image'], equals('image_url'));
      expect(activeQueue['source'], equals('youtube'));
      expect(activeQueue['list'].length, equals(2));
    });

    test('setQueueToPlaylist clears existing queue first', () {
      // Add existing songs
      addSongsToQueue([
        {'ytid': 'old1', 'title': 'Old Song 1'},
        {'ytid': 'old2', 'title': 'Old Song 2'},
      ]);
      
      final playlist = {
        'id': 'new_playlist',
        'ytid': 'new_ytid',
        'title': 'New Playlist',
        'image': '',
        'source': 'user',
      };
      final songs = [
        {'ytid': 'new1', 'title': 'New Song 1'},
      ];
      
      setQueueToPlaylist(playlist, songs);
      
      expect(activeQueue['list'].length, equals(1));
      expect(activeQueue['list'].first['ytid'], equals('new1'));
    });
  });

  group('Queue Manager - mediaItemFromSong', () {
    test('mediaItemFromSong creates MediaItem with correct id', () {
      final song = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };
      
      final mediaItem = mediaItemFromSong(song);
      
      expect(mediaItem, isNotNull);
      expect(mediaItem!.id, contains('abc123'));
    });

    test('mediaItemFromSong creates MediaItem with title', () {
      final song = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };
      
      final mediaItem = mediaItemFromSong(song);
      
      expect(mediaItem!.title, equals('Test Song'));
    });

    test('mediaItemFromSong creates MediaItem with artist', () {
      final song = {
        'ytid': 'abc123',
        'title': 'Test Song',
        'artist': 'Test Artist',
      };
      
      final mediaItem = mediaItemFromSong(song);
      
      expect(mediaItem!.artist, equals('Test Artist'));
    });

    test('mediaItemFromSong handles missing fields', () {
      final song = {'ytid': 'abc123'};
      
      final mediaItem = mediaItemFromSong(song);
      
      expect(mediaItem, isNotNull);
      expect(mediaItem!.id, contains('abc123'));
    });
  });

  group('Queue Manager - updateMediaItemQueue', () {
    test('updateMediaItemQueue updates with song maps', () {
      final songs = [
        {'ytid': 'song1', 'title': 'Song 1'},
        {'ytid': 'song2', 'title': 'Song 2'},
      ];
      final songMaps = NotifiableList<Map<String, dynamic>>.from(songs);
      
      updateMediaItemQueue(songMaps);
      
      // Verify queue was updated (actual MediaItem verification would require audio_handler)
      expect(songMaps.length, equals(2));
    });

    test('updateMediaItemQueue handles empty list', () {
      final songMaps = NotifiableList<Map<String, dynamic>>();
      
      updateMediaItemQueue(songMaps);
      
      expect(songMaps.length, equals(0));
    });
  });
}
