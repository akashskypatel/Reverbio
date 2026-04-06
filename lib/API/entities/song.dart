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

// Phase 7 H.7: song.dart is now a pure barrel file
// All function bodies have been extracted into domain-specific files:
// - song_state.dart: Module-level state variables
// - song_metadata.dart: Pure metadata functions
// - song_likes.dart: Like/unlike functions
// - song_cache.dart: Cache functions
// - song_youtube.dart: YouTube functions
// - song_musicbrainz.dart: MusicBrainz functions
// - song_offline.dart: Offline functions

export 'song_cache.dart';
export 'song_likes.dart';
export 'song_metadata.dart';
export 'song_musicbrainz.dart';
export 'song_offline.dart';
// Barrel exports - all existing callers remain unchanged
export 'song_state.dart';
export 'song_youtube.dart';
