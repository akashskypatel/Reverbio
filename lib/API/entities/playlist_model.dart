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

/// Phase 5 Part C A2: Typed PlaylistModel for type-safe playlist data handling
class PlaylistModel {
  PlaylistModel({
    required this.id,
    required this.title,
    this.description,
    this.artworkPath,
    this.songs = const [],
    this.source,
    this.primaryType,
    this.isLiked = false,
    Map<String, dynamic>? extraData,
  }) : extraData = extraData ?? {};

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      artworkPath: map['artworkPath'] as String?,
      songs: (map['songs'] as List?)?.cast<String>() ?? const [],
      source: map['source'] as String?,
      primaryType: map['primaryType'] as String?,
      isLiked: map['isLiked'] as bool? ?? false,
      extraData: map['extraData'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final String title;
  final String? description;
  final String? artworkPath;
  final List<String> songs;
  final String? source;
  final String? primaryType;
  final bool isLiked;
  final Map<String, dynamic> extraData;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (artworkPath != null) 'artworkPath': artworkPath,
      'songs': songs,
      if (source != null) 'source': source,
      if (primaryType != null) 'primaryType': primaryType,
      'isLiked': isLiked,
      if (extraData.isNotEmpty) 'extraData': extraData,
    };
  }

  PlaylistModel copyWith({
    String? id,
    String? title,
    String? description,
    String? artworkPath,
    List<String>? songs,
    String? source,
    String? primaryType,
    bool? isLiked,
    Map<String, dynamic>? extraData,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      artworkPath: artworkPath ?? this.artworkPath,
      songs: songs ?? this.songs,
      source: source ?? this.source,
      primaryType: primaryType ?? this.primaryType,
      isLiked: isLiked ?? this.isLiked,
      extraData: extraData ?? this.extraData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          artworkPath == other.artworkPath &&
          songs.length == other.songs.length &&
          songs.every((song) => other.songs.contains(song)) &&
          source == other.source &&
          primaryType == other.primaryType &&
          isLiked == other.isLiked;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        artworkPath,
        source,
        primaryType,
        isLiked,
      );

  @override
  String toString() =>
      'PlaylistModel(id: $id, title: $title, songs: ${songs.length})';
}
