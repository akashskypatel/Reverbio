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
 *
 *
 *     For more information about Reverbio, including how to contribute,
 *     please visit: https://github.com/akashskypatel/Reverbio
 */

import 'package:flutter/material.dart';
import 'package:reverbio/utilities/notifiable_future.dart';

/// Phase 4 A2.1: Module-level state variables for song.dart
/// Extracted to prevent circular imports when splitting song.dart into domain files

/// Global songs cache for recommended songs
final List globalSongs = [];

/// Active song ID for playback tracking
int activeSongId = 0;

/// Lyrics notifier for UI updates
final lyrics = ValueNotifier<String?>(null);

/// Queue of pending song info requests
final List<NotifiableFuture<Map<String, dynamic>>> getSongInfoQueue = [];

/// Limit for recently played songs list
const recentlyPlayedSongsLimit = 50;

/// Clear global songs cache to prevent memory buildup
void clearGlobalSongs() {
  globalSongs.clear();
}
