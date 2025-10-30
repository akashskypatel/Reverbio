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
import 'package:path_provider/path_provider.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/logger_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/media_utils.dart';
import 'package:reverbio/utilities/utils.dart';

class FileTagger {
  FileTagger();
  static final supportedFormats = {
    'AAC': ['aac'],
    'Ape': ['ape'],
    'AIFF': ['aiff', 'aif'],
    'FLAC': ['flac'],
    'MP3': ['mp3'],
    'MP4': ['mp4', 'm4a', 'm4b'],
    'MPC': ['mpc', 'mp+'],
    'Opus': ['opus'],
    'Ogg': ['ogg', 'oga'],
    'Speex': ['spx'],
    'WAV': ['wav'],
    'WavPack': ['wv'],
  };
  // Public method to read offline file tags (spawns isolate)
  Future<Tag?> getTagFromOfflineFileIsolate(
    dynamic song, {
    String? filePath,
  }) async {
    final completer = Completer<Tag?>();
    final receivePort = ReceivePort();

    try {
      if (song != null && song.isNotEmpty)
        filePath = await getOfflinePath(song);

      if (filePath != null && filePath.isNotEmpty) {
        await Isolate.spawn(
          _getOfflineFileTag,
          _IsolateTagReaderMessage(
            logger: logger,
            sendPort: receivePort.sendPort,
            path: filePath,
            song: song,
          ),
        );

        receivePort
            .listen((message) {
              if (message is Exception) {
                completer.completeError(message);
              } else if (message != null) {
                final tag = mapToTag(message);
                completer.complete(tag);
              } else {
                completer.complete(null);
              }
              receivePort.close();
            })
            .onError((e) {
              completer.completeError(e);
              receivePort.close();
            });
      } else {
        completer.completeError(L10n.current.cannotOpenFile);
        receivePort.close();
      }
    } catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
      receivePort.close();
    }

    return completer.future;
  }

  // Public method to read offline file tags (spawns isolate)
  Future<Tag?> getTagFromOfflineFile(dynamic song, {String? filePath}) async {
    try {
      if (song != null && song.isNotEmpty)
        filePath = await getOfflinePath(song);
      if (filePath != null && filePath.isNotEmpty) {
        try {
          return await AudioTags.read(filePath);
        } catch (_) {
          return null;
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()} at $filePath',
        e,
        stackTrace,
      );
    }
    return null;
  }

  static Future<void> _getOfflineFileTag(
    _IsolateTagReaderMessage message,
  ) async {
    Map<String, dynamic>? tagMap;
    try {
      final tags = await AudioTags.read(message.path);
      if (tags != null) {
        tagMap = tagToMap(tags);
        message.sendPort.send(tagMap);
        return;
      }
    } catch (_) {
      message.sendPort.send(null);
    }
    message.sendPort.send(null);
  }

  static Future<Tag?> getTagFromMetadata(dynamic song) async {
    try {
      if (song != null && song.isNotEmpty && isSongValid(song)) {
        final album = <String, dynamic>{};
        for (final release in (song['releases'] ?? [])) {
          if (album.isEmpty &&
              release['release-group'] != null &&
              release['country'] == 'XW') {
            album.addAll(Map<String, dynamic>.from(release['release-group']));
            break;
          }
        }
        if (album.isEmpty &&
            song['releases'] != null &&
            song['releases'].isNotEmpty &&
            song['releases']?[0]['release-group'] != null)
          album.addAll(
            Map<String, dynamic>.from(song['releases'][0]['release-group']),
          );
        File? picFile;
        await getValidImage(song, cache: false).then((value) async {
          if (value != null) {
            if (isFilePath(value.toString()))
              picFile = File(value.toString());
            else if (isUrl(value.toString()))
              picFile = await getFileFromUrl(value.toString());
          }
        });
        final tag = Tag(
          title: song['title'],
          trackArtist: combineArtists(song),
          album: album['title'],
          albumArtist: combineArtists(album),
          year:
              DateTime.tryParse(
                song['first-release-date']?.toString() ?? '',
              )?.year,
          genre: (song['genres'] as List?)?.map((e) => e['name']).join(', '),
          duration: song['duration'],
          pictures:
              picFile != null
                  ? [
                    Picture(
                      bytes: picFile!.readAsBytesSync(),
                      pictureType: PictureType.coverFront,
                    ),
                  ]
                  : [],
          bpm: song['bpm'],
        );
        return tag;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}',
        e,
        stackTrace,
      );
    }
    return null;
  }

  Future<Tag> getTagFromFileOrMetadata(dynamic song) async {
    final metaTag = await getTagFromMetadata(song);
    final songTag = mapToTag(song['audioTags']);
    final fileTag =
        songTag.equalsWithoutPictures(metaTag)
            ? metaTag
            : await getTagFromOfflineFile(song);
    final pictures =
        <Picture>[]
          ..addAll(fileTag?.pictures ?? [])
          ..addAll(metaTag?.pictures ?? []);
    final tag = Tag(
      title: fileTag?.title?.nullIfEmpty ?? metaTag?.title,
      trackArtist: fileTag?.trackArtist?.nullIfEmpty ?? metaTag?.trackArtist,
      album: fileTag?.album?.nullIfEmpty ?? metaTag?.album,
      albumArtist: fileTag?.albumArtist?.nullIfEmpty ?? metaTag?.albumArtist,
      year: fileTag?.year ?? metaTag?.year,
      genre: fileTag?.genre?.nullIfEmpty ?? metaTag?.genre,
      trackNumber: fileTag?.trackNumber ?? metaTag?.trackNumber,
      trackTotal: fileTag?.trackTotal ?? metaTag?.trackTotal,
      discNumber: fileTag?.discNumber ?? metaTag?.discNumber,
      discTotal: fileTag?.discTotal ?? metaTag?.discTotal,
      lyrics: fileTag?.lyrics?.nullIfEmpty ?? metaTag?.lyrics,
      duration: fileTag?.duration ?? metaTag?.duration,
      pictures: pictures,
      bpm: fileTag?.bpm ?? metaTag?.bpm,
    );
    song['audioTags'] = tagToMap(tag);
    addSongToCache(song);
    return tag;
  }

  Future<bool> tagOfflineFileIsolate(
    dynamic song, {
    Tag? tag,
    String? id,
    String? directory,
    String? filePath,
    bool rename = true,
  }) async {
    final completer = Completer<bool>();
    final receivePort = ReceivePort();
    directory ??= offlineDirectory.value;

    _createDirectories(directory!);

    await Isolate.spawn(
      _tagOfflineFileIsolate,
      _IsolateTagWriterMessage(
        logger: logger,
        sendPort: receivePort.sendPort,
        song: song,
        tag: tag,
        tempDir: path.join(
          (await getApplicationSupportDirectory()).path,
          'temp',
        ),
        id: id,
        audioFiles:
            filePath == null
                ? _getRelatedFilesSync(
                  path.join(directory, 'tracks'),
                  id ?? song['id'],
                )
                : [filePath],
        tagger: this, // Pass reference for static method access
        mediaUtils: MediaUtils.instance,
        token: RootIsolateToken.instance!,
        rename: rename,
      ),
    );

    receivePort.listen((message) {
      if (message is Exception) {
        completer.completeError(message);
      } else if (message is List<Tag> && message.isNotEmpty) {
        song['audioTags'] = tagToMap(message.first);
        addSongToCache(song);
        completer.complete(true);
      } else {
        completer.complete(false);
      }
      receivePort.close();
    });

    return completer.future;
  }

  Future<bool> tagOfflineFile(
    dynamic song, {
    Tag? tag,
    String? id,
    String? directory,
    String? filePath,
    bool rename = true,
  }) async {
    try {
      directory ??= offlineDirectory.value;

      _createDirectories(directory!);
      final tempDir = path.join(
        (await getApplicationSupportDirectory()).path,
        'temp',
      );
      final audioFiles =
          filePath == null
              ? _getRelatedFilesSync(
                path.join(directory, 'tracks'),
                id ?? song['id'],
              )
              : [filePath];
      if (song is String)
        song = await queueSongInfoRequest(song).completerFuture;
      final tags = await _processAudioFiles(
        audioFiles,
        song,
        song is String ? song : song['id'],
        tag,
        tempDir,
        logger,
        MediaUtils.instance,
        rename: rename,
      );
      if (tags.isNotEmpty) {
        song['audioTags'] = tagToMap(tags.first);
        addSongToCache(song);
      }
      return tags.isNotEmpty;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}',
        e,
        stackTrace,
      );
    }
    return false;
  }

  // Isolate entry point (static method)
  static Future<void> _tagOfflineFileIsolate(
    _IsolateTagWriterMessage message,
  ) async {
    try {
      BackgroundIsolateBinaryMessenger.ensureInitialized(message.token);
      final tags = await message.tagger._processAudioFiles(
        message.audioFiles,
        message.song,
        message.id,
        message.tag,
        message.tempDir,
        message.logger,
        message.mediaUtils,
      );
      message.sendPort.send(tags);
    } catch (e, stackTrace) {
      message.logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      message.sendPort.send(Exception('Failed to tag file: $e'));
    }
  }

  // Directory operations
  void _createDirectories(String directory) {
    final _audioDirPath = path.join(directory, 'tracks');
    final _artworkDirPath = path.join(directory, 'artworks');
    Directory(_audioDirPath).createSync(recursive: true);
    Directory(_artworkDirPath).createSync(recursive: true);
  }

  // File processing
  Future<List<Tag>> _processAudioFiles(
    List<String> audioList,
    dynamic song,
    String? id,
    Tag? tag,
    String tempDir,
    Logger _logger,
    MediaUtils mediaUtils, {
    bool rename = true,
  }) async {
    final tags = <Tag>[];
    for (final filePath in audioList) {
      final file = File(filePath);
      if (file.existsSync()) {
        try {
          final _tag = await tagSingleAudioFile(
            file,
            song,
            tempDir,
            _logger,
            mediaUtils,
            tag: tag,
          );
          if (_tag != null) tags.add(_tag);
        } catch (e, stackTrace) {
          _logger.log(
            'Error in ${stackTrace.getCurrentMethodName()}:',
            e,
            stackTrace,
          );
        }
        if (rename) _renameFileWithCorrectExtension(file, id);
      }
    }
    return tags;
  }

  Future<Tag?> tagSingleAudioFile(
    File file,
    dynamic song,
    String tempDir,
    Logger _logger,
    MediaUtils mediaUtils, {
    Tag? tag,
  }) async {
    if (!(await checkAllPermissions())) return null;
    Tag? newTag = tag;
    try {
      if (tag == null) {
        final metaTag = await getTagFromMetadata(song);
        final songTag = song is String ? null : mapToTag(song['audioTags']);
        final fileTag =
            songTag != null && songTag.equalsWithoutPictures(metaTag)
                ? metaTag
                : await AudioTags.read(file.path);
        final pictures =
            <Picture>[]
              ..addAll(fileTag?.pictures ?? [])
              ..addAll(metaTag?.pictures ?? []);
        if (fileTag == metaTag || metaTag == null) {
          return fileTag;
        } else {
          newTag = Tag(
            title: fileTag?.title?.nullIfEmpty ?? metaTag.title,
            trackArtist:
                fileTag?.trackArtist?.nullIfEmpty ?? metaTag.trackArtist,
            album: fileTag?.album?.nullIfEmpty ?? metaTag.album,
            albumArtist:
                fileTag?.albumArtist?.nullIfEmpty ?? metaTag.albumArtist,
            year: fileTag?.year ?? metaTag.year,
            genre: fileTag?.genre?.nullIfEmpty ?? metaTag.genre,
            trackNumber: fileTag?.trackNumber ?? metaTag.trackNumber,
            trackTotal: fileTag?.trackTotal ?? metaTag.trackTotal,
            discNumber: fileTag?.discNumber ?? metaTag.discNumber,
            discTotal: fileTag?.discTotal ?? metaTag.discTotal,
            lyrics: fileTag?.lyrics?.nullIfEmpty ?? metaTag.lyrics,
            duration: fileTag?.duration ?? metaTag.duration,
            pictures: pictures,
            bpm: fileTag?.bpm ?? metaTag.bpm,
          );
        }
      }
      if (File(file.path).existsSync()) {
        if (Platform.isAndroid) {
          final copy = File(
            file.path,
          ).copySync(path.join(tempDir, path.basename(file.path)));
          await AudioTags.write(copy.path, newTag!);
          final success = await mediaUtils.copyMediaFileToPathOrUri(
            file.path,
            copy.path,
          );
          copy.deleteSync();
          if (success == null) return null;
        } else
          await AudioTags.write(file.path, newTag!);
      }
      return newTag;
    } catch (e, stackTrace) {
      _logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}: ${file.path}',
        e,
        stackTrace,
      );
      return null;
    }
  }

  void _renameFileWithCorrectExtension(File file, String? id) {
    final mimeType = getMimeTypeFromFile(file.path);
    final extension = getExtensionFromMime(mimeType);
    final currentBaseName = path.basenameWithoutExtension(file.path);
    String newFileName = currentBaseName;
    String newFilePath = ensureCorrectExtension(
      newFileName,
      extension: extension,
    );
    if (id != null && currentBaseName != id) {
      newFileName = file.path.replaceAll(currentBaseName, id);
      newFilePath = ensureCorrectExtension(newFileName, extension: extension);
    }
    if (getFileExtension(file.path) != extension ||
        (id != null && currentBaseName != id))
      try {
        file.renameSync(newFilePath);
      } catch (_) {}
  }

  // File search utilities
  List<String> _getRelatedFilesSync(String directory, String id) {
    final files = <String>[];
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
                files.add(file.path);
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
        final newFilePath = ensureCorrectExtension(
          filePath,
          extension: extension,
        );

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
          final newFilePath = ensureCorrectExtension(
            filePath,
            extension: extension,
          );

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
}

// Message class for isolate communication
class _IsolateTagWriterMessage {
  _IsolateTagWriterMessage({
    required this.sendPort,
    required this.song,
    required this.tagger,
    required this.audioFiles,
    required this.logger,
    required this.tempDir,
    required this.mediaUtils,
    required this.token,
    this.rename = true,
    this.tag,
    this.id,
  });
  final SendPort sendPort;
  final dynamic song;
  final String? id;
  final Tag? tag;
  final String tempDir;
  final FileTagger tagger;
  final List<String> audioFiles;
  final Logger logger;
  final MediaUtils mediaUtils;
  final RootIsolateToken token;
  final bool rename;
}

class _IsolateTagReaderMessage {
  _IsolateTagReaderMessage({
    required this.sendPort,
    required this.path,
    required this.song,
    required this.logger,
  });
  final SendPort sendPort;
  final String path;
  final dynamic song;
  final Logger logger;
}
