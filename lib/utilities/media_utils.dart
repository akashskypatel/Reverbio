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

import 'package:flutter/services.dart';
import 'package:reverbio/main.dart';

/// Converts a local file path to a MediaStore URI
///
/// @param path - Local file system path (e.g., '/storage/emulated/0/Download/file.jpg')
/// @param mimeType - Optional MIME type to help with URI resolution
/// @returns MediaStore content URI as string, or null if conversion fails
///
/// Example:
/// ```dart
/// String? uri = await MediaUtilsBridge.pathToUri(
///   '/storage/emulated/0/Pictures/photo.jpg',
///   mimeType: 'image/jpeg'
/// );
/// ```
Future<String?> pathToUri(String path, {String? mimeType}) async {
  try {
    return await mediaChannel.invokeMethod('pathToUri', {
      'path': path,
      'mimeType': mimeType,
    });
  } on PlatformException catch (e) {
    logger.log('Error converting path to URI: ${e.message}', null, null);
    return null;
  }
}

/// Creates a new media file in MediaStore from byte data
///
/// @param displayName - File name to display in MediaStore
/// @param relativePath - MediaStore relative path for the file
/// @param data - Raw file data as bytes
/// @param mimeType - Optional MIME type of the file
/// @returns MediaStore content URI as string, or null if operation fails
///
/// Example:
/// ```dart
/// String? uri = await MediaUtilsBridge.createMediaFileFromBytes(
///   displayName: 'image.png',
///   relativePath: 'Pictures/MyApp/',
///   data: imageBytes,
///   mimeType: 'image/png'
/// );
/// ```
Future<String?> createMediaFileFromBytes({
  required String displayName,
  required String relativePath,
  required Uint8List data,
  String? mimeType,
}) async {
  try {
    return await mediaChannel.invokeMethod('createMediaFileFromBytes', {
      'displayName': displayName,
      'relativePath': relativePath,
      'data': data,
      'mimeType': mimeType,
    });
  } on PlatformException catch (e) {
    logger.log(
      'Error creating media file from bytes: ${e.message}',
      null,
      null,
    );
    return null;
  }
}

/// Overwrites an existing media file with new data
///
/// @param uri - MediaStore content URI of the file to edit
/// @param data - New file data as bytes
/// @returns true if successful, false otherwise
///
/// Example:
/// ```dart
/// bool success = await MediaUtilsBridge.editMediaFile(
///   'content://media/external/images/media/123',
///   updatedImageData
/// );
/// ```
Future<bool> editMediaFile(String uri, Uint8List data) async {
  try {
    return await mediaChannel.invokeMethod('editMediaFile', {
          'uri': uri,
          'data': data,
        }) ??
        false;
  } on PlatformException catch (e) {
    logger.log('Error editing media file: ${e.message}', null, null);
    return false;
  }
}

/// Deletes a media file from MediaStore
///
/// @param identifier - Either a content URI string or a local file path
/// @returns true if successful, false otherwise
///
/// Example with URI:
/// ```dart
/// bool deleted = await MediaUtilsBridge.deleteMediaFile(
///   'content://media/external/images/media/123'
/// );
/// ```
///
/// Example with file path:
/// ```dart
/// bool deleted = await MediaUtilsBridge.deleteMediaFile(
///   '/storage/emulated/0/Pictures/photo.jpg'
/// );
/// ```
Future<bool> deleteMediaFile(String identifier) async {
  try {
    return await mediaChannel.invokeMethod('deleteMediaFile', {
          'identifier': identifier,
        }) ??
        false;
  } on PlatformException catch (e) {
    logger.log('Error deleting media file: ${e.message}', null, null);
    return false;
  }
}

/// Copies a local file to MediaStore
///
/// @param sourcePath - Local file system path of the source file
/// @param relativePath - MediaStore relative path
/// @param displayName - File name to display in MediaStore
/// @param mimeType - Optional MIME type for the file
/// @returns MediaStore content URI as string, or null if operation fails
///
/// Example:
/// ```dart
/// String? uri = await MediaUtilsBridge.copyFileToMediaStore(
///   sourcePath: '/storage/emulated/0/Download/temp.mp3',
///   relativePath: 'Music/MyApp/',
///   displayName: 'song.mp3',
///   mimeType: 'audio/mpeg'
/// );
/// ```
Future<String?> copyFileToMediaStore({
  required String sourcePath,
  required String relativePath,
  required String displayName,
  String? mimeType,
}) async {
  try {
    return await mediaChannel.invokeMethod('copyFileToMediaStore', {
      'sourcePath': sourcePath,
      'relativePath': relativePath,
      'displayName': displayName,
      'mimeType': mimeType,
    });
  } on PlatformException catch (e) {
    logger.log('Error copying file to MediaStore: ${e.message}', null, null);
    return null;
  }
}

/// Copies from a content URI to MediaStore
///
/// @param sourceUri - Source content URI (e.g., from file picker)
/// @param relativePath - Destination relative path in MediaStore
/// @param displayName - File name in MediaStore
/// @param mimeType - Optional MIME type override
/// @returns New MediaStore content URI as string, or null if operation fails
///
/// Example:
/// ```dart
/// String? uri = await MediaUtilsBridge.copyUriToMediaStore(
///   sourceUri: 'content://media/external/images/media/123',
///   relativePath: 'Pictures/Backup/',
///   displayName: 'backup.jpg',
///   mimeType: 'image/jpeg'
/// );
/// ```
Future<String?> copyUriToMediaStore({
  required String sourceUri,
  required String relativePath,
  required String displayName,
  String? mimeType,
}) async {
  try {
    return await mediaChannel.invokeMethod('copyUriToMediaStore', {
      'sourceUri': sourceUri,
      'relativePath': relativePath,
      'displayName': displayName,
      'mimeType': mimeType,
    });
  } on PlatformException catch (e) {
    logger.log('Error copying URI to MediaStore: ${e.message}', null, null);
    return null;
  }
}

/// Reads a media file and returns its contents as bytes
///
/// @param pathOrUri - Either a local file path or a content URI string
/// @param mimeType - Optional MIME type for validation
/// @returns File data as bytes, or null if reading fails
///
/// Example with URI:
/// ```dart
/// Uint8List? data = await MediaUtilsBridge.readMediaFile(
///   'content://media/external/images/media/123'
/// );
/// ```
///
/// Example with file path:
/// ```dart
/// Uint8List? data = await MediaUtilsBridge.readMediaFile(
///   '/storage/emulated/0/Pictures/photo.jpg'
/// );
/// ```
Future<Uint8List?> readMediaFile(String pathOrUri, {String? mimeType}) async {
  try {
    return await mediaChannel.invokeMethod('readMediaFile', {
      'pathOrUri': pathOrUri,
      'mimeType': mimeType,
    });
  } on PlatformException catch (e) {
    logger.log('Error reading media file: ${e.message}', null, null);
    return null;
  }
}

// ────────────────────────────────────────────────
// ENHANCED METHODS WITH FLEXIBLE DESTINATIONS
// ────────────────────────────────────────────────

/// Copies a file with flexible source and destination options
///
/// @param source - Can be: file path OR content URI
/// @param destination - Can be:
///   - content URI (overwrites existing file)
///   - file path (copies to file system)
///   - relative path (creates in MediaStore)
///   - null (auto-detected from source)
/// @param relativePath - Optional: backward compatibility, used if destination is null
/// @param displayName - Optional file name for new MediaStore entries
/// @param mimeType - Optional MIME type
/// @returns URI of the destination file, or null if failed
///
/// Example: Copy to existing content URI (overwrite):
/// ```dart
/// String? uri = await MediaUtilsBridge.copyToMediaStore(
///   source: '/storage/emulated/0/Music/song.mp3',
///   destination: 'content://media/external/audio/media/123',
/// );
/// ```
///
/// Example: Copy to file system path:
/// ```dart
/// String? uri = await MediaUtilsBridge.copyToMediaStore(
///   source: 'content://media/external/images/media/456',
///   destination: '/storage/emulated/0/Backup/photo.jpg',
/// );
/// ```
///
/// Example: Copy to MediaStore relative path:
/// ```dart
/// String? uri = await MediaUtilsBridge.copyToMediaStore(
///   source: '/storage/emulated/0/Download/photo.jpg',
///   destination: 'Photos/Archived/',
///   displayName: 'photo.jpg',
/// );
/// ```
Future<String?> copyToMediaStore({
  required String source,
  String? destination,
  String? relativePath,
  String? displayName,
  String? mimeType,
}) async {
  try {
    return await mediaChannel.invokeMethod('copyToMediaStore', {
      'source': source,
      'destination': destination,
      'relativePath': relativePath,
      'displayName': displayName,
      'mimeType': mimeType,
    });
  } on PlatformException catch (e) {
    logger.log('Error copying to MediaStore: ${e.message}', null, null);
    return null;
  }
}

/// Creates a media file with flexible source and destination options
///
/// @param displayName - Optional file name
/// @param destination - Can be:
///   - content URI (overwrites existing)
///   - file path (creates file)
///   - relative path (creates in MediaStore)
///   - null (auto-detected from dataSource)
/// @param relativePath - Optional: backward compatibility
/// @param dataSource - Can be: Uint8List, file path, or content URI
/// @param mimeType - Optional MIME type
/// @returns URI of the created file, or null if failed
///
/// Example: Create from bytes to existing URI:
/// ```dart
/// String? uri = await MediaUtilsBridge.createMediaFile(
///   dataSource: imageData,
///   destination: 'content://media/external/images/media/789',
/// );
/// ```
///
/// Example: Create from file to file system:
/// ```dart
/// String? uri = await MediaUtilsBridge.createMediaFile(
///   dataSource: '/storage/emulated/0/temp.txt',
///   destination: '/storage/emulated/0/Backup/file.txt',
///   displayName: 'backup.txt',
/// );
/// ```
///
/// Example: Create from URI to relative path:
/// ```dart
/// String? uri = await MediaUtilsBridge.createMediaFile(
///   dataSource: 'content://media/external/audio/media/111',
///   destination: 'Music/Processed/',
///   displayName: 'processed_audio.mp3',
/// );
/// ```
Future<String?> createMediaFile({
  String? displayName,
  String? destination,
  String? relativePath,
  required dynamic dataSource,
  String? mimeType,
}) async {
  try {
    // Convert Uint8List to List<int> for platform channel
    dynamic processedDataSource = dataSource;
    if (dataSource is Uint8List) {
      processedDataSource = dataSource.toList();
    }

    return await mediaChannel.invokeMethod('createMediaFile', {
      'displayName': displayName,
      'destination': destination,
      'relativePath': relativePath,
      'dataSource': processedDataSource,
      'mimeType': mimeType,
    });
  } on PlatformException catch (e) {
    logger.log('Error creating media file: ${e.message}', null, null);
    return null;
  }
}
