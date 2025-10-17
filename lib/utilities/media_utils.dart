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

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MediaUtilsException implements Exception {
  MediaUtilsException(this.code, this.message);
  final String code;
  final String? message;

  @override
  String toString() => 'MediaUtilsException($code): $message';
}

class MediaOperation<T> {
  MediaOperation();
  final ValueNotifier<Completer<T>?> _completer = ValueNotifier(null);
  Function? _onComplete;
  Timer? resetTimer;
  Function? get onComplete => _onComplete;
  Completer<T>? get completer => _completer.value;

  void reset({dynamic error}) {
    _onComplete = null;
    resetTimer?.cancel();
    resetTimer = null;
    if(error != null && !(completer?.isCompleted ?? true)) {
      completer?.completeError(error);
    }
  }

  void set(
    Completer<T> newCompleter,
    Function? onCompleteCallback, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    if (completer != null && !completer!.isCompleted) {      
      reset(error: TimeoutException('Request timed out'));
    }
    reset();
    _completer.value = newCompleter;
    _onComplete = onCompleteCallback;
    resetTimer = Timer(timeout, () {
      reset(error: TimeoutException('Request timed out'));
    });
  }
}

class MediaUtils {
  MediaUtils();
  static final MediaUtils instance = MediaUtils();
  static const mediaChannel = MethodChannel(
    'com.akashskypatel.reverbio/media_utils',
  );
  static bool initialized = false;
  static final MediaOperation<bool> _deleteOperation = MediaOperation();
  static final MediaOperation<String?> _createOperation = MediaOperation();

  static Future<void> ensureInitialized() async {
    if (!Platform.isAndroid) return;
    if (initialized) return;
    bool? channelInitialized;
    while (channelInitialized == null) {
      try {
        channelInitialized = await isChannelInitialized();
      } catch (_) {}
    }
    mediaChannel.setMethodCallHandler((event) async {
      switch (event.method) {
        case 'notifyDeleteComplete':
          if (_deleteOperation.completer != null &&
              !_deleteOperation.completer!.isCompleted) {
            _deleteOperation.completer!.complete(event.arguments as bool);
            if (_deleteOperation.onComplete != null)
              _deleteOperation.onComplete!(event.arguments);
          }
          break;
        case 'notifyCreateComplete':
          if (_createOperation.completer != null &&
              !_createOperation.completer!.isCompleted) {
            _createOperation.completer!.complete(
              (event.arguments as List).first.toString(),
            );
            if (_createOperation.onComplete != null)
              _createOperation.onComplete!(event.arguments);
          }
          break;
        default:
      }
    });
    initialized = true;
  }

  static Future<bool?> isChannelInitialized() async {
    try {
      return await mediaChannel.invokeMethod('isInitialized');
    } on PlatformException catch (e) {
      throw MediaUtilsException(e.code, e.message);
    }
  }

  /// Converts a file system path to a MediaStore or FileProvider compatible URI.
  ///
  /// This method handles conversion for both existing media files and new files,
  /// supporting various storage locations including app-specific directories,
  /// external storage, and MediaStore collections.
  ///
  /// Supported path types:
  /// - App-specific directories (`/data/data/package/files/`)
  /// - External storage paths (`/storage/emulated/0/`)
  /// - MediaStore content URIs (returns unchanged)
  ///
  /// Example:
  /// ```dart
  /// final uri = await MediaUtils.pathToUri('/storage/emulated/0/Music/song.mp3');
  /// // Returns: 'content://media/external/audio/media/123'
  /// ```
  /// Parameters:
  /// - [path] : The absolute file system path to convert
  /// - [mimeType] : Optional MIME type to improve URI resolution accuracy. Will be determined from source file if not provided
  ///
  /// Returns: A content URI string, or `null` if the path cannot be resolved
  ///
  /// Throws: [MediaUtilsException] if the platform operation fails
  Future<String?> pathToUri(String path, {String? mimeType}) async {
    try {
      await ensureInitialized();
      return await mediaChannel.invokeMethod('pathToUri', {
        'path': path,
        'mimeType': mimeType,
      });
    } on PlatformException catch (e) {
      throw MediaUtilsException(e.code, e.message);
    }
  }

  /// Converts a MediaStore or FileProvider URI back to a file system path.
  ///
  /// This method resolves various URI types to their corresponding file paths:
  /// - MediaStore URIs (`content://media/external/audio/media/123`)
  /// - FileProvider URIs (`content://com.akashskypatel.reverbio.fileprovider/...`)
  /// - DocumentsProvider URIs (`content://com.android.externalstorage.documents/...`)
  ///
  /// Note: Some URIs may not have a direct file path representation,
  /// particularly those from Storage Access Framework (SAF) providers.
  ///
  /// Parameters:
  /// - [uri] : The content URI to resolve to a file path
  ///
  /// Returns: The absolute file system path, or `null` if no path exists
  ///
  /// Throws: [MediaUtilsException] if the URI cannot be resolved
  Future<String?> uriToPath(String uri) async {
    try {
      await ensureInitialized();
      return await mediaChannel.invokeMethod('uriToPath', {'uri': uri});
    } on PlatformException catch (e) {
      throw MediaUtilsException(e.code, e.message);
    }
  }

  /// Overwrites an existing media file with new binary data.
  ///
  /// This operation may require user permission on Android 11+ (API 30+) when
  /// modifying files outside the app's scoped storage. The method automatically
  /// handles permission requests when needed.
  ///
  /// Supported identifiers:
  /// - Content URIs (`content://media/external/audio/media/123`)
  /// - File paths (`/storage/emulated/0/Music/song.mp3`)
  ///
  /// Platform behavior:
  /// - Android 10-: Direct file overwrite
  /// - Android 11+: MediaStore write request with user consent
  ///
  /// Parameters:
  /// - [pathOrUri] : Either a content URI or file path of the media file
  /// - [data] : The new binary content to write
  /// - [mimeType] : Optional MIME type for path-based operations. Will be determined from source file if not provided
  ///
  /// Returns: `true` if the operation completed successfully
  ///
  /// Throws: [MediaUtilsException] if writing fails or permission is denied
  Future<String?> editMediaFile(
    String pathOrUri,
    List<int> data, {
    String? mimeType,
    Function? onComplete,
  }) async {
    try {
      await ensureInitialized();
      _createOperation.set(Completer(), onComplete);
      await mediaChannel.invokeMethod('editMediaFile', {
        'pathOrUri': pathOrUri,
        'data': Uint8List.fromList(data),
        'mimeType': mimeType,
      });
      return _createOperation.completer!.future;
    } on PlatformException catch (e) {
      throw MediaUtilsException(e.code, e.message);
    }
  }

  /// Reads the complete binary content of a media file.
  ///
  /// This method provides efficient file reading for both URI and path-based
  /// media files, using appropriate ContentResolver methods for URIs and
  /// direct file access for paths.
  ///
  /// Performance note: For large files, consider streaming approaches
  /// instead of loading entire files into memory.
  ///
  /// Parameters:
  /// - [pathOrUri] : Either a content URI or file path of the media file
  /// - [mimeType] : Optional MIME type for path-based operations. Will be determined from source file if not provided
  ///
  /// Returns: The file content as bytes, or `null` if the file doesn't exist
  ///
  /// Throws: [MediaUtilsException] if reading fails or file is inaccessible
  Future<Uint8List?> readMediaFile(
    String pathOrUri, {
    String? mimeType,
    Function? onComplete,
  }) async {
    try {
      await ensureInitialized();
      return await mediaChannel.invokeMethod('readMediaFile', {
        'pathOrUri': pathOrUri,
        'mimeType': mimeType,
      });
    } on PlatformException catch (e) {
      throw MediaUtilsException(e.code, e.message);
    }
  }

  /// Permanently deletes a media file from storage.
  ///
  /// On Android 11+ (API 30+), this may trigger a system permission dialog
  /// for files not owned by the app. The operation is queued and executed
  /// after user approval.
  ///
  /// Warning: This operation is irreversible. Deleted files cannot be
  /// recovered through this API.
  ///
  /// Parameters:
  /// - [pathOrUri] : Either a content URI or file path of the media file to delete
  ///
  /// Returns: `true` if the delete operation completed successfully
  ///
  /// Throws: [MediaUtilsException] if deletion fails or permission is denied
  Future<bool> deleteMediaFile(String pathOrUri, {Function? onComplete}) async {
    try {
      await ensureInitialized();
      _deleteOperation.set(Completer(), onComplete);
      await mediaChannel.invokeMethod('deleteMediaFile', {
        'pathOrUri': pathOrUri,
      });
      return _deleteOperation.completer!.future;
    } catch (e, stackTrace) {
      _deleteOperation.completer?.completeError(
        MediaUtilsException(e.toString(), stackTrace.toString()),
      );
      rethrow;
    }
  }

  /// Creates a new media file in a specific MediaStore relative directory.
  ///
  /// This method creates files in standard Android media directories with
  /// proper MediaStore integration. The relative path determines the file's
  /// location in the public storage.
  ///
  /// Supported relative paths:
  /// - `Environment.DIRECTORY_MUSIC` → "Music/"
  /// - `Environment.DIRECTORY_PODCASTS` → "Podcasts/"
  /// - `Environment.DIRECTORY_PICTURES` → "Pictures/"
  /// - `Environment.DIRECTORY_MOVIES` → "Movies/"
  /// - `Environment.DIRECTORY_DOWNLOADS` → "Download/"
  ///
  /// Android 11+ note: May require user permission for certain directories.
  ///
  /// Parameters:
  /// - [displayName] : The filename including extension (e.g., "song.mp3")
  /// - [relativePath] : The target MediaStore directory (e.g., "Music/")
  /// - [data] : The binary content of the new file
  /// - [mimeType] : Optional MIME type of the file content. Will be determined from source file if not provided
  ///
  /// Returns: The content URI of the newly created file
  ///
  /// Throws: [MediaUtilsException] if file creation fails
  Future<String?> createMediaFileAtRelative(
    String displayName,
    String relativePath,
    List<int> data, {
    String? mimeType,
    Function? onComplete,
  }) async {
    try {
      await ensureInitialized();
      _createOperation.set(Completer(), onComplete);
      await mediaChannel.invokeMethod('createMediaFileAtRelative', {
        'displayName': displayName,
        'relativePath': relativePath,
        'data': Uint8List.fromList(data),
        'mimeType': mimeType,
      });
      return _createOperation.completer!.future;
    } catch (e, stackTrace) {
      _createOperation.completer?.completeError(
        MediaUtilsException(e.toString(), stackTrace.toString()),
      );
      rethrow;
    }
  }

  /// Creates a new media file with automatic directory selection.
  ///
  /// The target directory is automatically determined based on the MIME type:
  /// - Audio files → "Music/"
  /// - Image files → "Pictures/"
  /// - Video files → "Movies/"
  /// - Other files → "Download/"
  ///
  /// This is a convenience method that simplifies file creation when the
  /// exact storage location isn't critical.
  ///
  /// Parameters:
  /// - [displayName] : The filename including extension (e.g., "photo.jpg")
  /// - [data] : The binary content of the new file
  /// - [mimeType] : Optional MIME type used for directory selection. Will be determined from source file if not provided
  ///
  /// Returns: The content URI of the newly created file
  ///
  /// Throws: [MediaUtilsException] if file creation fails
  Future<String?> createMediaFile(
    String displayName,
    List<int> data, {
    String? mimeType,
    Function? onComplete,
  }) async {
    try {
      await ensureInitialized();
      _createOperation.set(Completer(), onComplete);
      await mediaChannel.invokeMethod('createMediaFile', {
        'displayName': displayName,
        'data': Uint8List.fromList(data),
        'mimeType': mimeType,
      });
      return _createOperation.completer!.future;
    } catch (e, stackTrace) {
      _createOperation.completer?.completeError(
        MediaUtilsException(e.toString(), stackTrace.toString()),
      );
      rethrow;
    }
  }

  /// Copies a media file to a new location in a specific relative directory.
  ///
  /// Creates a copy of the source file in the target MediaStore directory
  /// with the specified display name. The original file remains unchanged.
  ///
  /// Platform behavior:
  /// - Android 10-: Direct file copy operation
  /// - Android 11+: MediaStore-managed copy with permission handling
  ///
  /// Parameters:
  /// - [pathOrUri] : Source file URI or path
  /// - [displayName] : Destination file name
  /// - [relativePath] : Optional Target MediaStore directory (e.g., "Music/"). Will be determined from mime-type if not provided
  /// - [mimeType] : Optional MIME type of the file being copied. Will be determined from source file if not provided
  ///
  /// Returns: Content URI of the newly created copy
  ///
  /// Throws: [MediaUtilsException] if copy operation fails
  Future<String?> copyMediaFileToRelative(
    String pathOrUri,
    String displayName, {
    String? relativePath,
    String? mimeType,
    Function? onComplete,
  }) async {
    try {
      await ensureInitialized();
      _createOperation.set(Completer(), onComplete);
      await mediaChannel.invokeMethod('copyMediaFileToRelative', {
        'pathOrUri': pathOrUri,
        'displayName': displayName,
        'relativePath': relativePath,
        'mimeType': mimeType,
      });
      return _createOperation.completer!.future;
    } catch (e, stackTrace) {
      _createOperation.completer?.completeError(
        MediaUtilsException(e.toString(), stackTrace.toString()),
      );
      rethrow;
    }
  }

  /// Copies a media file to a specific destination path or URI.
  ///
  /// This method provides flexible file copying to either:
  /// - A specific file path (`/storage/emulated/0/NewLocation/file.mp3`)
  /// - A specific content URI (overwrites existing MediaStore entry)
  ///
  /// Note: When copying to a URI, the destination must already exist
  /// in MediaStore. Use [createMediaFile] methods for new entries.
  ///
  /// Parameters:
  /// - [toPathOrUri] : Source file URI or path
  /// - [fromPathOrUri] : Destination file path or URI
  /// - [mimeType] : Optional MIME type for path-based operations. Will be determined from source file if not provided
  ///
  /// Returns: Content URI of the newly created copy
  ///
  /// Throws: [MediaUtilsException] if copy operation fails
  Future<String?> copyMediaFileToPathOrUri(
    String toPathOrUri,
    String fromPathOrUri, {
    String? mimeType,
    Function? onComplete,
  }) async {
    try {
      await ensureInitialized();
      _createOperation.set(Completer(), onComplete);
      await mediaChannel.invokeMethod('copyMediaFileToPathOrUri', {
        'toPathOrUri': toPathOrUri,
        'fromPathOrUri': fromPathOrUri,
        'mimeType': mimeType,
      });
      return _createOperation.completer!.future;
    } catch (e, stackTrace) {
      _createOperation.completer?.completeError(
        MediaUtilsException(e.toString(), stackTrace.toString()),
      );
      rethrow;
    }
  }
}
