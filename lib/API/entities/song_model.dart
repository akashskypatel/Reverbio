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

/// Phase 5 Part C A1: Typed SongModel for type-safe song data handling
class SongModel {
  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.artworkPath,
    this.offlineAudioPath,
    this.offlineArtworkPath,
    this.songUrl,
    this.devicePath,
    this.isOffline = false,
    this.isLiked = false,
    Map<String, dynamic>? extraData,
  }) : extraData = extraData ?? {};

  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String?,
      duration: map['duration'] as int?,
      artworkPath: map['artworkPath'] as String?,
      offlineAudioPath: map['offlineAudioPath'] as String?,
      offlineArtworkPath: map['offlineArtworkPath'] as String?,
      songUrl: map['songUrl'] as String?,
      devicePath: map['devicePath'] as String?,
      isOffline: map['isOffline'] as bool? ?? false,
      isLiked: map['isLiked'] as bool? ?? false,
      extraData: map['extraData'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final String title;
  final String artist;
  final String? album;
  final int? duration;
  final String? artworkPath;
  final String? offlineAudioPath;
  final String? offlineArtworkPath;
  final String? songUrl;
  final String? devicePath;
  final bool isOffline;
  final bool isLiked;
  final Map<String, dynamic> extraData;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      if (album != null) 'album': album,
      if (duration != null) 'duration': duration,
      if (artworkPath != null) 'artworkPath': artworkPath,
      if (offlineAudioPath != null) 'offlineAudioPath': offlineAudioPath,
      if (offlineArtworkPath != null) 'offlineArtworkPath': offlineArtworkPath,
      if (songUrl != null) 'songUrl': songUrl,
      if (devicePath != null) 'devicePath': devicePath,
      'isOffline': isOffline,
      'isLiked': isLiked,
      if (extraData.isNotEmpty) 'extraData': extraData,
    };
  }

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? artworkPath,
    String? offlineAudioPath,
    String? offlineArtworkPath,
    String? songUrl,
    String? devicePath,
    bool? isOffline,
    bool? isLiked,
    Map<String, dynamic>? extraData,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      artworkPath: artworkPath ?? this.artworkPath,
      offlineAudioPath: offlineAudioPath ?? this.offlineAudioPath,
      offlineArtworkPath: offlineArtworkPath ?? this.offlineArtworkPath,
      songUrl: songUrl ?? this.songUrl,
      devicePath: devicePath ?? this.devicePath,
      isOffline: isOffline ?? this.isOffline,
      isLiked: isLiked ?? this.isLiked,
      extraData: extraData ?? this.extraData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          duration == other.duration &&
          artworkPath == other.artworkPath &&
          offlineAudioPath == other.offlineAudioPath &&
          offlineArtworkPath == other.offlineArtworkPath &&
          songUrl == other.songUrl &&
          devicePath == other.devicePath &&
          isOffline == other.isOffline &&
          isLiked == other.isLiked;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        artist,
        album,
        duration,
        artworkPath,
        offlineAudioPath,
        offlineArtworkPath,
        songUrl,
        devicePath,
        isOffline,
        isLiked,
      );

  @override
  String toString() =>
      'SongModel(id: $id, title: $title, artist: $artist, album: $album)';
}
