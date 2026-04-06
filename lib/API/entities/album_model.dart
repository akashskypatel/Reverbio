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

/// Phase 5 Part C A2: Typed AlbumModel for type-safe album data handling
class AlbumModel {
  AlbumModel({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArtist,
    this.year,
    this.genre,
    this.artworkPath,
    this.songs = const [],
    this.isLiked = false,
    Map<String, dynamic>? extraData,
  }) : extraData = extraData ?? {};

  factory AlbumModel.fromMap(Map<String, dynamic> map) {
    return AlbumModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      albumArtist: map['albumArtist'] as String?,
      year: map['year'] as int?,
      genre: map['genre'] as String?,
      artworkPath: map['artworkPath'] as String?,
      songs: (map['songs'] as List?)?.cast<String>() ?? const [],
      isLiked: map['isLiked'] as bool? ?? false,
      extraData: map['extraData'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final String title;
  final String artist;
  final String? albumArtist;
  final int? year;
  final String? genre;
  final String? artworkPath;
  final List<String> songs;
  final bool isLiked;
  final Map<String, dynamic> extraData;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      if (albumArtist != null) 'albumArtist': albumArtist,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (artworkPath != null) 'artworkPath': artworkPath,
      'songs': songs,
      'isLiked': isLiked,
      if (extraData.isNotEmpty) 'extraData': extraData,
    };
  }

  AlbumModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? albumArtist,
    int? year,
    String? genre,
    String? artworkPath,
    List<String>? songs,
    bool? isLiked,
    Map<String, dynamic>? extraData,
  }) {
    return AlbumModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArtist: albumArtist ?? this.albumArtist,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      artworkPath: artworkPath ?? this.artworkPath,
      songs: songs ?? this.songs,
      isLiked: isLiked ?? this.isLiked,
      extraData: extraData ?? this.extraData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlbumModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          artist == other.artist &&
          albumArtist == other.albumArtist &&
          year == other.year &&
          genre == other.genre &&
          artworkPath == other.artworkPath &&
          songs.length == other.songs.length &&
          songs.every((song) => other.songs.contains(song)) &&
          isLiked == other.isLiked;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        artist,
        albumArtist,
        year,
        genre,
        artworkPath,
        isLiked,
      );

  @override
  String toString() =>
      'AlbumModel(id: $id, title: $title, artist: $artist, year: $year)';
}
