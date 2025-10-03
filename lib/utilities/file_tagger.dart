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
import 'dart:isolate';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/utils.dart';

class FileTagger {
  FileTagger({this.offlineDirectory});
  final String? offlineDirectory;
  static final _extensionRegex = RegExp(r'\.[^\.]+$');
  late final _audioDirPath = '$offlineDirectory${Platform.pathSeparator}tracks';
  late final _artworkDirPath =
      '$offlineDirectory${Platform.pathSeparator}artworks';
  
  // Public method to read offline file tags (spawns isolate)
  Future<Tag?> getOfflineFileTag(dynamic song) async {
    final completer = Completer<Tag?>();
    final receivePort = ReceivePort();
    String? filePath;

    if (song != null) filePath = await getOfflinePath(song);

    if (filePath != null && filePath.isNotEmpty) {
      await Isolate.spawn(
        _getOfflineFileTag,
        _IsolateTagReaderMessage(
          sendPort: receivePort.sendPort,
          path: filePath,
          song: song,
        ),
      );

      receivePort.listen((message) {
        if (message is Exception || message == null) {
          completer.completeError(message);
        } else {
          final tag = Tag(
            title: message['title']?.toString(),
            trackArtist: message['trackArtist']?.toString(),
            album: message['album']?.toString(),
            albumArtist: message['albumArtist']?.toString(),
            year: int.tryParse(message['year']?.toString() ?? ''),
            genre: message['genre']?.toString(),
            trackNumber: int.tryParse(message['trackNumber']?.toString() ?? ''),
            trackTotal: int.tryParse(message['trackTotal']?.toString() ?? ''),
            discNumber: int.tryParse(message['discNumber']?.toString() ?? ''),
            discTotal: int.tryParse(message['discTotal']?.toString() ?? ''),
            lyrics: message['lyrics']?.toString(),
            duration: int.tryParse(message['duration']?.toString() ?? ''),
            pictures:
                ((message['pictures'] ?? []) as List<dynamic>)
                    .map(
                      (e) => Picture(
                        bytes: Uint8List.fromList(e['bytes'] ?? []),
                        pictureType: PictureType.values.elementAt(
                          e['pictureType'] ?? 0,
                        ),
                      ),
                    )
                    .toList(),
            bpm: double.tryParse(message['bpm']?.toString() ?? ''),
          );
          completer.complete(tag);
        }
        receivePort.close();
      });
    } else {
      completer.completeError(L10n.current.cannotOpenFile);
      receivePort.close();
    }

    return completer.future;
  }

  static Future<void> _getOfflineFileTag(
    _IsolateTagReaderMessage message,
  ) async {
    Map<String, dynamic>? tagMap;
    try {
      final tags = await AudioTags.read(message.path);
      tagMap = <String, dynamic>{
        'title': tags?.title,
        'trackArtist': tags?.trackArtist,
        'album': tags?.album,
        'albumArtist': tags?.albumArtist,
        'year': tags?.year,
        'genre': tags?.genre,
        'trackNumber': tags?.trackNumber,
        'trackTotal': tags?.trackTotal,
        'discNumber': tags?.discNumber,
        'discTotal': tags?.discTotal,
        'lyrics': tags?.lyrics,
        'duration': tags?.duration,
        'pictures':
            tags?.pictures
                .map(
                  (e) => {
                    'bytes': e.bytes.toList(),
                    'mimeType':
                        e.mimeType != null
                            ? MimeType.values.indexOf(e.mimeType!)
                            : null,
                    'pictureType': PictureType.values.indexOf(e.pictureType),
                  },
                )
                .toList(),
        'bpm': tags?.bpm,
      };
      message.sendPort.send(tagMap);
    } catch (_) {
      final album = <String, dynamic>{};
      for (final release in (message.song['releases'] ?? [])) {
        if (album.isEmpty &&
            release['release-group'] != null &&
            release['country'] == 'XW') {
          album.addAll(Map<String, dynamic>.from(release['release-group']));
          break;
        }
      }
      if (album.isEmpty && message.song['releases']?['release-group'] != null)
        album.addAll(
          Map<String, dynamic>.from(
            message.song['releases'][0]['release-group'],
          ),
        );
      File? picFile;
      await getValidImage(message.song, cache: false).then((value) async {
        if (value != null)
          picFile = await getImageFileData(path: value.toString());
      });
      tagMap = <String, dynamic>{
        'title': message.song['title'],
        'trackArtist': combineArtists(message.song),
        'album': album['title'],
        'albumArtist': combineArtists(album),
        'year':
            DateTime.tryParse(
              message.song['first-release-date']?.toString() ?? '',
            )?.year,
        'genre': (message.song['genres'] as List?)
            ?.map((e) => e['name'])
            .join(', '),
        'duration': message.song['duration'],
        'pictures':
            picFile != null
                ? [
                  {
                    'bytes': picFile!.readAsBytesSync().toList(),
                    'pictureType': PictureType.values.indexOf(
                      PictureType.coverFront,
                    ),
                  },
                ]
                : [],
        'bpm': message.song['bpm'],
      };
      picFile?.deleteSync();
      message.sendPort.send(tagMap);
    }
  }

  Future<void> tagOfflineFile(dynamic song, String id) async {
    final completer = Completer<void>();
    final receivePort = ReceivePort();
    if (offlineDirectory == null) {
      completer.completeError('Directory not provided');
      receivePort.close();
      return;
    }
    await Isolate.spawn(
      _tagOfflineFileIsolate,
      _IsolateTagWriterMessage(
        sendPort: receivePort.sendPort,
        song: song,
        id: id,
        offlineDirectory: offlineDirectory!,
        tagger: this, // Pass reference for static method access
      ),
    );

    receivePort.listen((message) {
      if (message is Exception) {
        completer.completeError(message);
      } else {
        completer.complete();
      }
      receivePort.close();
    });

    return completer.future;
  }

  // Isolate entry point (static method)
  static void _tagOfflineFileIsolate(_IsolateTagWriterMessage message) {
    try {
      message.tagger._tagOfflineFileImpl(message.song, message.id);
      message.sendPort.send('success');
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      message.sendPort.send(Exception('Failed to tag file: $e'));
    }
  }

  // Main implementation
  void _tagOfflineFileImpl(dynamic song, String id) {
    _createDirectories();

    final audioList = _getRelatedFilesSync(_audioDirPath, id);
    final artworkList = _getRelatedFilesSync(_artworkDirPath, id);

    _processAudioFiles(audioList, artworkList, song, id);
    _processArtworkFiles(artworkList, id);
  }

  // Directory operations
  void _createDirectories() {
    Directory(_audioDirPath).createSync(recursive: true);
    Directory(_artworkDirPath).createSync(recursive: true);
  }

  // File processing
  void _processAudioFiles(
    List<File> audioList,
    List<File> artworkList,
    dynamic song,
    String id,
  ) {
    for (final file in audioList) {
      if (file.existsSync()) {
        try {
          _processSingleAudioFile(file, artworkList, song, id);
        } catch (e, stackTrace) {
          logger.log(
            'Error in ${stackTrace.getCurrentMethodName()}:',
            e,
            stackTrace,
          );
        }
        _renameFileWithCorrectExtension(file, id);
      }
    }
  }

  Future<void> _processSingleAudioFile(
    File file,
    List<File> artworkList,
    dynamic song,
    String id,
  ) async {
    try {
      final tag = await AudioTags.read(file.path);
      final songTitle = song['mbTitle'] ?? song['title'] ?? song['ytTitle'];
      final songArtist = song['mbArtist'] ?? song['artist'] ?? song['ytArtist'];
      final songAlbum = song['album'];
      final songAlbumArtist = song['albumArtist'];
      final pictures = tag?.pictures ?? [];
      final needsRetagging =
          tag == null ||
          tag.title != songTitle ||
          tag.trackArtist != songArtist ||
          tag.pictures.isEmpty;
      if (songTitle != songArtist && needsRetagging) {
        await _addPicturesToTag(file, artworkList, song, id, pictures);

        final newTag = Tag(
          title: songTitle,
          trackArtist: songArtist,
          album: songAlbum,
          albumArtist: songAlbumArtist,
          pictures: pictures,
        );
        if (File(file.path).existsSync())
          await AudioTags.write(file.path, newTag);
      }
    } catch (e, stackTrace) {
      switch (e) {
        case AudioTagsError_InvalidPath:
          logger.log(
            'Error in ${stackTrace.getCurrentMethodName()}: ${file.path}',
            e,
            stackTrace,
          );
          break;
        default:
      }
    }
  }

  Future<void> _addPicturesToTag(
    File audioFile,
    List<File> artworkList,
    dynamic song,
    String id,
    List<Picture> pictures,
  ) async {
    try {
      if (pictures.isNotEmpty) return;

      if (artworkList.isEmpty) {
        final imagePath = await getValidImage(song);
        if (imagePath != null) {
          final artworkFile = await _downloadAndSaveArtworkFile(
            imagePath,
            '$_artworkDirPath${Platform.pathSeparator}$id',
          );
          if (artworkFile != null) {
            pictures.add(
              Picture(
                pictureType: PictureType.other,
                bytes: artworkFile.readAsBytesSync(),
              ),
            );
          }
        }
      } else {
        for (final artwork in artworkList) {
          pictures.add(
            Picture(
              pictureType: PictureType.other,
              bytes: artwork.readAsBytesSync(),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  void _processArtworkFiles(List<File> artworkList, String id) {
    for (final file in artworkList) {
      if (file.existsSync()) {
        _renameFileWithCorrectExtension(file, id);
      }
    }
  }

  void _renameFileWithCorrectExtension(File file, String id) {
    final mimeType = getMimeTypeFromFile(file.path);
    final extension = getExtensionFromMime(mimeType);
    final currentBaseName = path.basenameWithoutExtension(file.path);

    if (currentBaseName != id || _getFileExtension(file.path) != extension) {
      final newFileName = file.path.replaceAll(currentBaseName, id);
      final newFilePath = _ensureCorrectExtension(newFileName, extension);
      file.renameSync(newFilePath);
    }
  }

  // File search utilities
  List<File> _getRelatedFilesSync(String directory, String id) {
    final files = <File>[];
    try {
      final ids = id.toIds;
      final dir = Directory(directory);

      if (dir.existsSync()) {
        final fileEntities = dir.listSync();

        for (final file in fileEntities) {
          if (file is File) {
            for (final songId in ids.values) {
              if (checkEntityId(
                songId,
                path.basenameWithoutExtension(file.path),
              )) {
                files.add(file);
                break;
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return files;
  }

  Future<File?> _downloadAndSaveArtworkFile(Uri uri, String filePath) async {
    try {
      if (uri.isScheme('file') && doesFileExist(uri.toFilePath())) {
        final file = File(uri.toFilePath());
        // For local files, detect MIME type from content
        final mimeType = getMimeTypeFromFile(uri.toFilePath());
        final extension = getExtensionFromMime(mimeType);
        final newFilePath = _ensureCorrectExtension(filePath, extension);

        return await file.copy(newFilePath);
      } else {
        final response = await http.get(uri);
        if (response.statusCode < 300) {
          // Get MIME type from headers or detect from content
          String? mimeType = response.headers['content-type']?.split(';').first;

          // If no MIME type in headers, detect from content
          if (mimeType == null ||
              mimeType.isEmpty ||
              mimeType == 'application/octet-stream') {
            mimeType = lookupMimeType('', headerBytes: response.bodyBytes);
          }

          // Get file extension from MIME type
          final extension = getExtensionFromMime(mimeType);
          final newFilePath = _ensureCorrectExtension(filePath, extension);

          return await File(newFilePath).writeAsBytes(response.bodyBytes);
        } else {
          logger.log(
            'Failed to download file. Status code: ${response.statusCode}',
            null,
            null,
          );
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return null;
  }

  // MIME type utilities
  static String? getMimeTypeFromFile(String filePath) {
    try {
      final file = File(filePath);
      final raf = file.openSync();

      try {
        const bytesToRead = 128;
        final buffer = List<int>.filled(bytesToRead, 0);
        final bytesRead = raf.readIntoSync(buffer, 0, bytesToRead);

        final headerBytes =
            bytesRead < bytesToRead ? buffer.sublist(0, bytesRead) : buffer;

        return lookupMimeType(file.path, headerBytes: headerBytes);
      } finally {
        raf.closeSync();
      }
    } catch (e) {
      return null;
    }
  }

  static String getExtensionFromMime(String? mimeType) {
    if (mimeType == null) return 'bin';

    final extensions = {
      'image/jpg': 'jpg',
      'image/png': 'png',
      'image/gif': 'gif',
      'image/webp': 'webp',
      'image/bmp': 'bmp',
      'image/x-icon': 'ico',
      'audio/mp3': 'mp3',
      'audio/weba': 'webm',
      'video/weba': 'webm',
      'audio/webm': 'webm',
      'video/webm': 'webm',
    };

    final extension =
        extensionFromMime(mimeType) ??
        extensions[mimeType.toLowerCase()] ??
        'bin';

    return '.$extension';
  }

  // Path utilities
  static String _ensureCorrectExtension(String filePath, String extension) {
    final withoutExtension = filePath.replaceAll(_extensionRegex, '');
    return '$withoutExtension$extension';
  }

  static String _getFileExtension(String filePath) {
    final match = _extensionRegex.firstMatch(filePath);
    return match?.group(0) ?? '';
  }
}

// Message class for isolate communication
class _IsolateTagWriterMessage {
  _IsolateTagWriterMessage({
    required this.sendPort,
    required this.song,
    required this.id,
    required this.offlineDirectory,
    required this.tagger,
  });
  final SendPort sendPort;
  final dynamic song;
  final String id;
  final String offlineDirectory;
  final FileTagger tagger;
}

class _IsolateTagReaderMessage {
  _IsolateTagReaderMessage({
    required this.sendPort,
    required this.path,
    required this.song,
  });
  final SendPort sendPort;
  final String path;
  final dynamic song;
}
