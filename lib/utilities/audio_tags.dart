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

import 'dart:convert';
import 'dart:io';

import 'package:android_media_store/android_media_store.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/utils.dart';

/// The MIME type of the picture.
enum MimeType { png, jpeg, tiff, bmp, gif }

/// The type of picture of the song.
enum PictureType {
  other,
  icon,
  otherIcon,
  coverFront,
  coverBack,
  leaflet,
  media,
  leadArtist,
  artist,
  conductor,
  band,
  composer,
  lyricist,
  recordingLocation,
  duringRecording,
  duringPerformance,
  screenCapture,
  brightFish,
  illustration,
  bandLogo,
  publisherLogo,
}

/// An object representing a picture metadata.
class Picture {
  const Picture({
    required this.pictureType,
    this.mimeType,
    required this.bytes,
  });

  /// Creates a Picture instance from a JSON map.
  factory Picture.fromJson(Map<String, dynamic> json) {
    return Picture(
      pictureType: PictureType.values.byName(json['pictureType']),
      mimeType:
          json['mimeType'] != null
              ? MimeType.values.byName(json['mimeType'])
              : null,
      bytes: base64Decode(json['bytes']),
    );
  }

  /// The type of picture (ex. front cover)
  final PictureType pictureType;

  /// The mime type of the picture (ex. `image/jpg`)
  final MimeType? mimeType;

  /// The picture data, in bytes.
  final Uint8List bytes;

  @override
  int get hashCode => pictureType.hashCode ^ mimeType.hashCode ^ bytes.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Picture &&
          runtimeType == other.runtimeType &&
          pictureType == other.pictureType &&
          mimeType == other.mimeType &&
          bytes == other.bytes;

  /// Converts the Picture instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'pictureType': pictureType.name,
      'mimeType': mimeType?.name,
      'bytes': base64Encode(bytes),
    };
  }
}

class Tag {
  // New field

  Tag({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.comment,
    this.track,
    this.trackTotal,
    this.disc,
    this.discTotal,
    this.duration,
    this.pictures = const [],
    this.lyrics,
    this.bpm,
    this.composer,
    this.copyright,
    this.encoder,
    this.encodedBy,
    this.description,
    this.synopsis,
    this.grouping,
    this.youtube,
    this.musicbrainz,
    this.customTags,
  });

  /// Creates a Tag instance from a JSON map.
  factory Tag.fromJson(Map<String, dynamic> json) {
    final customTags = <String, String>{};
    if (json['customTags'] != null) {
      for (final entry in json['customTags'].entries) {
        customTags[entry.key] = entry.value.toString();
      }
    }
    return Tag(
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      albumArtist: (json['albumArtist'] ?? json['album_artist']) as String?,
      genre: json['genre'] as String?,
      year: int.tryParse(
        json['date']?.toString() ?? json['creation_time']?.toString() ?? '',
      ),
      comment: json['comment'] as String?,
      track: int.tryParse(
        (json['track'] ?? json['trackNumber'])?.toString().split('/').first ??
            '',
      ),
      trackTotal: int.tryParse(
        (json['track'] ?? json['trackNumber'])?.toString().split('/').last ??
            '',
      ),
      disc: int.tryParse(
        (json['disc'] ?? json['discNumber'])?.toString().split('/').first ?? '',
      ),
      discTotal: int.tryParse(
        (json['disc'] ?? json['discNumber'])?.toString().split('/').last ?? '',
      ),
      duration: (double.tryParse(json['duration'] ?? '0.0') ?? 0.0).round(),
      lyrics: json['lyrics'] as String?,
      bpm: double.tryParse(json['bpm']?.toString() ?? ''),
      composer: json['composer'] as String?,
      copyright: json['copyright'] as String?,
      encoder: json['encoder'] as String?,
      encodedBy: (json['encodedBy'] ?? json['encoded_by']) as String?,
      description: json['description'] as String?,
      synopsis: json['synopsis'] as String?,
      grouping: json['grouping'] as String?,
      youtube: json['youtube'] as String?,
      musicbrainz: json['musicbrainz'] as String?,
      customTags: customTags.isNotEmpty ? customTags : null,
      pictures:
          (json['pictures'] as List<dynamic>)
              .map(
                (picJson) => Picture.fromJson(picJson as Map<String, dynamic>),
              )
              .toList(),
    );
  }
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final String? comment;
  final int? track;
  final int? trackTotal;
  final int? disc;
  final int? discTotal;
  final int? duration;
  final List<Picture> pictures;
  final String? lyrics;
  final double? bpm;
  final String? composer;
  final String? copyright;
  final String? encoder;
  final String? encodedBy;
  final String? description;
  final String? synopsis;
  final String? grouping;
  final String? youtube; // Reverbio Custom
  final String? musicbrainz; // Reverbio Custom
  final Map<String, String>? customTags;

  /// Converts the Tag instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtist': albumArtist,
      'genre': genre,
      'year': year,
      'comment': comment,
      'track': track,
      'trackTotal': trackTotal,
      'disc': disc,
      'discTotal': discTotal,
      'duration': duration,
      'lyrics': lyrics,
      'bpm': bpm,
      'composer': composer,
      'copyright': copyright,
      'encoder': encoder,
      'encodedBy': encodedBy,
      'description': description,
      'synopsis': synopsis,
      'grouping': grouping,
      'youtube': youtube,
      'musicbrainz': musicbrainz,
      'customTags': customTags,
      'pictures': pictures.map((p) => p.toJson()).toList(),
    };
  }

  @override
  String toString() {
    final json =
        toJson()
          // Exclude pictures from default toString for cleaner logging
          ..remove('pictures');
    return 'Tag($json)';
  }

  /// Strictly defined tags
  /// Tag to FFMPEG standard tag mapping
  static Map<String, String> get mapping => {
    'title': 'title',
    'artist': 'artist',
    'album': 'album',
    'albumArtist': 'album_artist',
    'genre': 'genre',
    'year': 'date',
    'comment': 'comment',
    'track': 'track',
    'trackTotal': 'trackTotal',
    'disc': 'disc',
    'discTotal': 'discTotal',
    'duration': 'duration',
    'lyrics': 'lyrics',
    'bpm': 'bpm',
    'composer': 'composer',
    'copyright': 'copyright',
    'encoder': 'encoder',
    'encodedBy': 'encoded_by',
    'description': 'description',
    'synopsis': 'synopsis',
    'grouping': 'grouping',
    'youtube': 'youtube',
    'musicbrainz': 'musicbrainz',
    'pictures': 'pictures',
  };
}

// Make sure the Tag class from step 2 is available
// import 'audio_tags.dart';

class AudioTags {
  // Map for converting PictureType enum to its standard comment string.
  static final Map<PictureType, String> _pictureTypeToCommentMap = {
    PictureType.other: 'Other',
    PictureType.icon: 'Icon',
    PictureType.otherIcon: 'Other icon',
    PictureType.coverFront: 'Cover (front)',
    PictureType.coverBack: 'Cover (back)',
    PictureType.leaflet: 'Leaflet',
    PictureType.media: 'Media',
    PictureType.leadArtist: 'Lead artist',
    PictureType.artist: 'Artist',
    PictureType.conductor: 'Conductor',
    PictureType.band: 'Band',
    PictureType.composer: 'Composer',
    PictureType.lyricist: 'Lyricist',
    PictureType.recordingLocation: 'Recording location',
    PictureType.duringRecording: 'During recording',
    PictureType.duringPerformance: 'During performance',
    PictureType.screenCapture: 'Screen capture',
    PictureType.brightFish: 'Bright fish',
    PictureType.illustration: 'Illustration',
    PictureType.bandLogo: 'Band logo',
    PictureType.publisherLogo: 'Publisher logo',
  };

  // Map for parsing a comment string to a PictureType.
  // The order is important for precedence (e.g., 'lead artist' must be checked before 'artist').
  // Dart Map literals preserve insertion order.
  static final Map<String, PictureType> _commentToPictureTypeMap = {
    'front': PictureType.coverFront,
    'back': PictureType.coverBack,
    'leaflet': PictureType.leaflet,
    'media': PictureType.media,
    'leadartist': PictureType.leadArtist,
    'artist': PictureType.artist,
    'conductor': PictureType.conductor,
    'bandlogo': PictureType.bandLogo,
    'band': PictureType.band,
    'composer': PictureType.composer,
    'lyricist': PictureType.lyricist,
    'recordinglocation': PictureType.recordingLocation,
    'duringrecording': PictureType.duringRecording,
    'duringperformance': PictureType.duringPerformance,
    'screencapture': PictureType.screenCapture,
    'fish': PictureType.brightFish,
    'illustration': PictureType.illustration,
    'publisherlogo': PictureType.publisherLogo,
    'othericon': PictureType.otherIcon,
    'icon': PictureType.icon,
  };

  /// Reads metadata tags from an audio file.
  ///
  /// Returns an [Tag] object on success, or null on failure.
  static Future<Tag?> read(String filePath) async {
    final command =
        '-v quiet -print_format json -show_format -show_streams "$filePath"';

    final session = await FFprobeKit.execute(command);
    final output = await session.getOutput();

    if (!ReturnCode.isSuccess(await session.getReturnCode()) ||
        output == null) {
      debugPrint('FFprobe failed to read metadata for $filePath');
      return null;
    }

    try {
      final json = jsonDecode(output);
      final format = json['format'] ?? {};
      final tags = format['tags'] ?? {};

      // Check for an attached picture video stream
      final picStream = (json['streams'] as List?)?.firstWhere(
        (s) =>
            s['codec_type'] == 'video' &&
            s['disposition']?['attached_pic'] == 1,
        orElse: () => null,
      );

      final pictures = <Picture>[];
      if (picStream != null) {
        final artworkBytes = await _extractArtwork(
          filePath,
          picStream['codec_name'],
        );
        if (artworkBytes != null) {
          pictures.add(
            Picture(
              // Default to front cover, as it's the most common type for embedded art
              pictureType: _getPictureTypeFromComment(
                picStream['tags']?['comment'],
              ),
              // MimeType is difficult to determine reliably without another ffprobe call,
              // so we leave it null. The `bytes` are the most important part.
              bytes: artworkBytes,
            ),
          );
        }
      }
      final customTags = <String, String>{};
      for (final entry in tags.entries) {
        if (!Tag.mapping.values.contains(entry.key)) {
          customTags[entry.key] = entry.value.toString();
        }
      }
      return Tag(
        title: tags['title'],
        artist: tags['artist'],
        album: tags['album'],
        albumArtist: tags['album_artist'],
        genre: tags['genre'],
        year: int.tryParse(
          tags['date']?.toString() ?? tags['creation_time']?.toString() ?? '',
        ),
        comment: tags['comment'],
        track: int.tryParse(tags['track']?.toString().split('/').first ?? ''),
        trackTotal: int.tryParse(
          tags['track']?.toString().split('/').last ?? '',
        ),
        disc: int.tryParse(tags['disc']?.toString().split('/').first ?? ''),
        discTotal: int.tryParse(tags['disc']?.toString().split('/').last ?? ''),
        duration: (double.tryParse(format['duration'] ?? '0.0') ?? 0.0).round(),
        lyrics: tags['lyrics'],
        bpm: double.tryParse(tags['bpm']?.toString() ?? ''),
        composer: tags['composer'],
        copyright: tags['copyright'],
        encoder: format['encoder'],
        encodedBy: format['encoded_by'],
        description: tags['description'],
        synopsis: tags['synopsis'],
        grouping: tags['grouping'],
        youtube: tags['youtube'],
        musicbrainz: tags['musicbrainz'],
        customTags: customTags.isNotEmpty ? customTags : null,
        pictures: pictures,
      );
    } catch (e) {
      debugPrint('Error parsing FFprobe JSON output: $e');
      return null;
    }
  }

  /// Writes metadata tags to an audio file.
  ///
  /// This is an "in-place" operation that works by creating a temporary file
  /// and replacing the original on success.
  /// Returns true on success, false on failure.
  static Future<bool> write(String filePath, Tag tags) async {
    bool success = false;
    final tempDir = Directory(
      join(
        (await getTemporaryDirectory()).path,
        'tmp_${DateTime.now().millisecondsSinceEpoch}',
      ),
    )..createSync(recursive: true);
    try {
      final tempArtDir = Directory(join(tempDir.path, 'artworks'))
        ..createSync(recursive: true);
      final tempFilePath = join(tempDir.path, basename(filePath));

      final arguments = <String>['-i', '"$filePath"'];
      final List<String> artworkPaths = [];

      if (tags.pictures.isNotEmpty) {
        // Add each picture as a new input file.
        for (final picture in tags.pictures) {
          final picExt = getExtensionFromMime(getMimeFromBytes(picture.bytes));
          final artworkPath =
              '${tempArtDir.path}/artwork_${artworkPaths.length}$picExt';
          await File(artworkPath).writeAsBytes(picture.bytes);
          artworkPaths.add(artworkPath);
          arguments.add('-i "$artworkPath"');
        }

        // Map the audio stream from the original file (input 0).
        arguments.add('-map 0:a');
        // Map each picture input to a new video stream.
        for (int i = 0; i < artworkPaths.length; i++) {
          arguments.add('-map ${i + 1}:v');
        }

        // Set the codec for the video streams.
        arguments.add('-c:v copy');

        // Set the disposition and comment metadata for each video stream individually.
        for (int i = 0; i < tags.pictures.length; i++) {
          final pictureComment = _getCommentFromPictureType(
            tags.pictures[i].pictureType,
          );
          // ':v:$i' refers to the i-th output video stream.
          arguments
            ..add('-disposition:v:$i attached_pic')
            ..add('-metadata:s:v:$i comment="$pictureComment"');
        }
      } else {
        // If no pictures are provided, map only the audio stream, which
        // effectively removes any existing pictures from the file.
        arguments.add('-map 0:a');
      }

      arguments
        ..addAll(['-c:a', 'copy', '-c:s', 'copy'])
        ..addAll(['-map_metadata', '-1']);

      if (tags.title != null)
        arguments.addAll(['-metadata', 'title="${tags.title}"']);
      if (tags.artist != null)
        arguments.addAll(['-metadata', 'artist="${tags.artist}"']);
      if (tags.album != null)
        arguments.addAll(['-metadata', 'album="${tags.album}"']);
      if (tags.albumArtist != null)
        arguments.addAll(['-metadata', 'album_artist="${tags.albumArtist}"']);
      if (tags.genre != null)
        arguments.addAll(['-metadata', 'genre="${tags.genre}"']);
      if (tags.year != null)
        arguments.addAll(['-metadata', 'date="${tags.year}"']);
      if (tags.comment != null)
        arguments.addAll(['-metadata', 'comment="${tags.comment}"']);
      if (tags.lyrics != null)
        arguments.addAll(['-metadata', 'lyrics="${tags.lyrics}"']);
      if (tags.bpm != null)
        arguments.addAll(['-metadata', 'bpm="${tags.bpm}"']);
      if (tags.composer != null)
        arguments.addAll(['-metadata', 'composer="${tags.composer}"']);
      if (tags.copyright != null)
        arguments.addAll(['-metadata', 'copyright="${tags.copyright}"']);
      if (tags.encoder != null)
        arguments.addAll(['-metadata', 'encoder="${tags.encoder}"']);
      if (tags.encodedBy != null)
        arguments.addAll(['-metadata', 'encoded_by="${tags.encodedBy}"']);
      if (tags.description != null)
        arguments.addAll(['-metadata', 'description="${tags.description}"']);
      if (tags.synopsis != null)
        arguments.addAll(['-metadata', 'synopsis="${tags.synopsis}"']);
      if (tags.grouping != null)
        arguments.addAll(['-metadata', 'grouping="${tags.grouping}"']);
      if (tags.youtube != null)
        arguments.addAll(['-metadata', 'youtube="${tags.youtube}"']);
      if (tags.musicbrainz != null)
        arguments.addAll(['-metadata', 'musicbrainz="${tags.musicbrainz}"']);
      if (tags.customTags != null)
        for (final entry in tags.customTags!.entries) {
          arguments.addAll(['-metadata', '${entry.key}=${entry.value}']);
        }

      if (tags.track != null) {
        final trackValue =
            tags.trackTotal != null
                ? '${tags.track}/${tags.trackTotal}'
                : '${tags.track}';
        arguments.addAll(['-metadata', 'track="$trackValue"']);
      }
      if (tags.disc != null) {
        final discValue =
            tags.discTotal != null
                ? '${tags.disc}/${tags.discTotal}'
                : '${tags.disc}';
        arguments.addAll(['-metadata', 'disc="$discValue"']);
      }

      arguments.add('"$tempFilePath"');

      final session = await FFmpegKit.execute(arguments.join(' '));
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (Platform.isAndroid && await checkAllPermissions())
          await AndroidMediaStore.instance.copyMediaFileToPathOrUri(
            filePath,
            tempFilePath,
          );
        else if (!Platform.isAndroid)
          File(tempFilePath).copySync(filePath);
        logger.log('Updated metadata to $filePath successfully', null, null);
        success = true;
      } else {
        // Keep your existing debug logs here
        logger
          ..log('FFmpeg write failed. Return code: $returnCode', null, null)
          ..log(
            'Command: ${arguments.join(' ')}',
            null,
            null,
          ) // Helpful for debugging
          ..log('Logs: ${await session.getLogsAsString()}', null, null);
        success = false;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}',
        e,
        stackTrace,
      );
      success = false;
    }
    tempDir.deleteSync(recursive: true);
    return success;
  }

  /// Clears all metadata from a file, leaving only the audio stream.
  ///
  /// This removes all tags, pictures, and other non-audio data.
  /// Returns true on success, false on failure.
  static Future<bool> clear(String filePath) async {
    bool success = false;
    final tempDir = Directory(
      join(
        (await getTemporaryDirectory()).path,
        'tmp_${DateTime.now().millisecondsSinceEpoch}',
      ),
    )..createSync(recursive: true);
    try {
      final tempFilePath = join(tempDir.path, basename(filePath));

      // Command Breakdown:
      // -i "$filePath": Input file.
      // -map 0:a: Selects and maps ONLY the audio streams from the input.
      //           This inherently discards video (pictures), subtitles, etc.
      // -c:a copy: Copies the audio stream without re-encoding, preserving quality.
      // -map_metadata -1: Explicitly removes all global metadata tags.
      final command =
          '-i "$filePath" -map 0:a -c:a copy -map_metadata -1 "$tempFilePath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (Platform.isAndroid && await checkAllPermissions())
          await AndroidMediaStore.instance.copyMediaFileToPathOrUri(
            filePath,
            tempFilePath,
          );
        else if (!Platform.isAndroid)
          File(tempFilePath).copySync(filePath);
        logger.log('Cleared metadata from $filePath successfully', null, null);
        success = true;
      } else {
        logger
          ..log('FFmpeg clear failed. Return code: $returnCode', null, null)
          ..log('Command: $command', null, null)
          ..log('Logs: ${await session.getLogsAsString()}', null, null);
        success = false;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}',
        e,
        stackTrace,
      );
      success = false;
    }
    tempDir.deleteSync(recursive: true);
    return success;
  }

  /// Helper to generate a comment string from a PictureType.
  static String _getCommentFromPictureType(PictureType pictureType) {
    return _pictureTypeToCommentMap[pictureType] ?? 'Other';
  }

  /// Helper to determine PictureType from the picture stream's comment tag.
  static PictureType _getPictureTypeFromComment(String? comment) {
    final lowerComment =
        comment?.toLowerCase().trim().replaceAll(' ', '') ?? '';
    if (lowerComment.isEmpty) {
      return PictureType.coverFront;
    }

    for (final entry in _commentToPictureTypeMap.entries) {
      if (lowerComment.contains(entry.key)) {
        return entry.value;
      }
    }

    // Default to front cover as it's the most common and often unspecified.
    return PictureType.coverFront;
  }

  /// Helper to extract artwork to a byte array.
  static Future<Uint8List?> _extractArtwork(
    String filePath,
    String? codecName,
  ) async {
    Uint8List? bytes;
    final tempDir = Directory(
      join(
        (await getTemporaryDirectory()).path,
        'tmp_${DateTime.now().millisecondsSinceEpoch}',
      ),
    )..createSync(recursive: true);
    String extension = '';
    switch (codecName?.toLowerCase()) {
      case 'mjpeg':
        extension = '.jpg';
        break;
      case 'png':
        extension = '.png';
        break;
      case 'bmp':
        extension = '.bmp';
        break;
      case 'tiff':
        extension = '.tiff';
        break;
      case 'gif':
        extension = '.gif';
        break;
    }
    final tempArtworkPath =
        '${tempDir.path}/extracted_artwork_${DateTime.now().millisecondsSinceEpoch}$extension';

    // Command to extract the first attached picture
    final command = '-i "$filePath" -an -vcodec copy "$tempArtworkPath"';
    final session = await FFmpegKit.execute(command);
    final success = ReturnCode.isSuccess(await session.getReturnCode());
    if (success) {
      final file = File(tempArtworkPath);
      if (await file.exists()) {
        bytes = await file.readAsBytes();
      }
    } else {
      logger.log(await session.getLogsAsString(), null, null);
    }
    tempDir.deleteSync(recursive: true);
    return bytes;
  }
}
