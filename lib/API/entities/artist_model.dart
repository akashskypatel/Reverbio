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

/// Phase 5 Part C A2: Typed ArtistModel for type-safe artist data handling
class ArtistModel {
  ArtistModel({
    required this.id,
    required this.name,
    this.bio,
    this.artworkPath,
    this.albums = const [],
    this.songs = const [],
    this.isLiked = false,
    Map<String, dynamic>? extraData,
  }) : extraData = extraData ?? {};

  factory ArtistModel.fromMap(Map<String, dynamic> map) {
    return ArtistModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      bio: map['bio'] as String?,
      artworkPath: map['artworkPath'] as String?,
      albums: (map['albums'] as List?)?.cast<String>() ?? const [],
      songs: (map['songs'] as List?)?.cast<String>() ?? const [],
      isLiked: map['isLiked'] as bool? ?? false,
      extraData: map['extraData'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final String name;
  final String? bio;
  final String? artworkPath;
  final List<String> albums;
  final List<String> songs;
  final bool isLiked;
  final Map<String, dynamic> extraData;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (bio != null) 'bio': bio,
      if (artworkPath != null) 'artworkPath': artworkPath,
      'albums': albums,
      'songs': songs,
      'isLiked': isLiked,
      if (extraData.isNotEmpty) 'extraData': extraData,
    };
  }

  ArtistModel copyWith({
    String? id,
    String? name,
    String? bio,
    String? artworkPath,
    List<String>? albums,
    List<String>? songs,
    bool? isLiked,
    Map<String, dynamic>? extraData,
  }) {
    return ArtistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      artworkPath: artworkPath ?? this.artworkPath,
      albums: albums ?? this.albums,
      songs: songs ?? this.songs,
      isLiked: isLiked ?? this.isLiked,
      extraData: extraData ?? this.extraData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          bio == other.bio &&
          artworkPath == other.artworkPath &&
          albums.length == other.albums.length &&
          albums.every((album) => other.albums.contains(album)) &&
          songs.length == other.songs.length &&
          songs.every((song) => other.songs.contains(song)) &&
          isLiked == other.isLiked;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        bio,
        artworkPath,
        isLiked,
      );

  @override
  String toString() => 'ArtistModel(id: $id, name: $name)';
}
