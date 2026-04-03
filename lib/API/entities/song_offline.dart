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
import 'dart:convert';
import 'dart:io';

import 'package:android_media_store/android_media_store.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path/path.dart' show PathException;
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/song_cache.dart';
import 'package:reverbio/API/entities/song_metadata.dart';
import 'package:reverbio/API/entities/song_musicbrainz.dart';
import 'package:reverbio/API/entities/song_state.dart';
import 'package:reverbio/API/entities/song_youtube.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/lyrics_manager.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/file_scanner.dart';
import 'package:reverbio/utilities/file_tagger.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';

/// Module-level variable for tracking last fetched lyrics.
String? lastFetchedLyrics;

/// H.6 fix: Extract offline functions from song.dart
/// Handles offline song management, device library, and file operations.

/// Get song URL, downloading offline if needed.
Future<dynamic> getSongUrl(dynamic song, {bool skipDownload = false}) async {
  song['isError'] = false;
  song?.remove('error');
  final taskIds = await FileDownloader().allTaskIds();
  final offlinePath =
      !taskIds.contains(song['id'])
          ? await getOfflinePath(song)
          : null;
  if (offlinePath != null) {
    song['songUrl'] = offlinePath;
  }
  if (offlinePath == null || offlinePath.isEmpty) {
    // R557 fix: PM.getSongUrl already sets song['songUrl'] internally via onSuccess callback
    // No need to assign the return value - it may overwrite the plugin's URL with fallback
    await PM.getSongUrl(song, getSongYoutubeUrl);
  }

  if (((song['autoCacheOffline'] ?? false) || autoCacheOffline.value) &&
      (song['songUrl'] != null && offlinePath == null) &&
      !skipDownload &&
      !taskIds.contains(song['id']))
    await makeSongOffline(song);
  return song;
}

/// Get song lyrics.
Future<String?> getSongLyrics(dynamic song) async {
  final artist = songArtist(song);
  final title = songTitle(song);
  // R14 fix: Standardize return value for "no lyrics" - don't cache unavailable lyrics
  if (lastFetchedLyrics != '$artist - $title' ||
      lyrics.value == null ||
      lyrics.value == L10n.current.lyricsNotAvailable) {
    lyrics.value = null;
    var _lyrics = await LyricsManager().fetchLyrics(song);
    if (_lyrics != null) {
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{2}'), '\n');
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{4}'), '\n\n');
      lyrics.value = _lyrics;
    } else {
      // R14 fix: Return null instead of caching unavailable message
      lastFetchedLyrics = '$artist - $title';
      return null;
    }

    lastFetchedLyrics = '$artist - $title';
    return _lyrics;
  }

  return lyrics.value;
}

/// Check if a song is already offline (in app or device library).
bool isSongAlreadyOffline(songToCheck) =>
    isSongAppOfflineOnly(songToCheck) || isSongInDeviceLibrary(songToCheck);

/// Check if a song is in the app's offline storage.
bool isSongAppOfflineOnly(songToCheck) => userOfflineSongs.any((song) {
  if (songToCheck is String) return checkEntityId(songToCheck, song);
  if (songToCheck is Map) return checkEntityId(songToCheck['id'], song);
  return false;
});

/// Check if a song is in the device's music library.
bool isSongInDeviceLibrary(songToCheck) => userDeviceSongs.any((song) {
  if (songToCheck is String) return checkEntityId(songToCheck, song);
  if (songToCheck is Map &&
      song['id'] != null &&
      songToCheck['id'] != null &&
      song['id'].isNotEmpty &&
      songToCheck['id'].isNotEmpty)
    return checkEntityId(songToCheck, song);
  if (songToCheck is Map) return checkTitleAndArtist(songToCheck, song);
  return false;
});

/// Move all songs to device library.
Future<int> moveAllSongToDeviceLibrary() async {
  int count = 0;
  final destination =
      Platform.isWindows ? await FilePicker.platform.getDirectoryPath() : null;
  try {
    if (Platform.isWindows && (destination == null || destination.isEmpty))
      throw PathException('Invalid destination directory selected');
    await getUserOfflineSongs();
    final snapshot = userOfflineSongs.toList();
    final moved = <String>[];
    for (final song in snapshot) {
      try {
        final _song = await queueSongInfoRequest(song).completerFuture;
        if (_song == null || _song.isEmpty) continue;
        count += await moveSongToDeviceLibrary(_song, destination: destination);
        moved.add(song);
      } catch (_) {}
    }
    for (final song in moved)
      userOfflineSongs.removeWhere((e) => checkEntityId(song, e));
  } catch (e, stackTrace) {
    logger.log('Error in moveAllSongToDeviceLibrary:', e, stackTrace);
  }
  return count;
}

/// Move a single song to device library.
Future<int> moveSongToDeviceLibrary(dynamic song, {String? destination}) async {
  int count = 0;
  try {
    if (!(await checkAllPermissions())) return count;
    if (song is String) song = await queueSongInfoRequest(song).completerFuture;
    if (isSongAppOfflineOnly(song) && !isSongInDeviceLibrary(song)) {
      // Fix: Use null-safe pattern for offlineDirectory.value
      final dirValue = offlineDirectory.value;
      if (dirValue == null) {
        logger.log('offlineDirectory not initialized yet', null, null);
        return 0;
      }
      final _dir = Directory(dirValue);
      final _audioDirPath = p.join(_dir.path, 'tracks');
      final files = await _getRelatedFiles(_audioDirPath, song);
      String? dest = Platform.isWindows ? destination : null;
      for (final file in files) {
        if (songArtist(song).isNotEmpty && songTitle(song).isNotEmpty) {
          final newName =
              '${songArtist(song)} - ${songTitle(song)}${p.extension(file.path)}'
                  .replaceAll(RegExp('[\\/:*?"<>|]'), '');
          String? copyPath;
          if (Platform.isAndroid) {
            final copy = file.copySync(
              file.path.replaceAll(p.basename(file.path), newName),
            );
            copyPath =
                dest = await AndroidMediaStore.instance.copyMediaFileToRelative(
                  copy.path,
                  newName,
                );
            copy.deleteSync();
          } else if (dest != null && dest.isNotEmpty) {
            copyPath = p.join(dest, newName);
            file.copySync(copyPath);
          }
          if (dest != null && dest.isNotEmpty) {
            song['devicePath'] = copyPath;
            file.deleteSync();
            count++;
          }
        }
      }
      if (count > 0) {
        userDeviceSongs.addOrUpdate(song, checkSong);
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in moveSongToDeviceLibrary:', e, stackTrace);
  }
  return count;
}

/// Tag all offline files with metadata.
Future<void> tagAllOfflineFiles() async {
  final offlineSongs = await getUserOfflineSongs();
  final ValueNotifier<int> progress = ValueNotifier(0);
  showToast(
    'Tagging offline songs with metadata...',
    id: 'tagOffline',
    data: progress,
  );
  final fileTagger = FileTagger();
  for (int i = 0; i < offlineSongs.length; i++) {
    final song =
        await queueSongInfoRequest(copyMap(offlineSongs[i])).completerFuture;
    await fileTagger.tagOfflineFile(song, id: parseEntityId(song));
    final num = (i + 1) / offlineSongs.length;
    progress.value = (num * 100).toInt();
  }
  showToast('Finished tagging offline songs with metadata.', id: 'tagOffline');
}

/// Download a song for offline playback.
Future<void> makeSongOffline(dynamic song) async {
  try {
    await getUserOfflineSongs();
    if (isSongAlreadyOffline(song)) return;
    // Fix: Use null-safe pattern for offlineDirectory.value
    final dirValue = offlineDirectory.value;
    if (dirValue == null) {
      logger.log('offlineDirectory not initialized yet', null, null);
      showToast('Storage not ready. Please try again.');
      return;
    }
    final _dir = Directory(dirValue);
    final _audioDirPath = p.join(_dir.path, 'tracks');
    final _artworkDirPath = p.join(_dir.path, 'artworks');
    await Directory(_audioDirPath).create(recursive: true);
    await Directory(_artworkDirPath).create(recursive: true);

    if (!isMusicbrainzSongValid(song)) {
      final songInfo = (await queueSongInfoRequest(song).completerFuture) ?? {};
      song.addAll(Map<String, dynamic>.from(songInfo));
    }
    if (!isYouTubeSongValid(song)) await findYTSong(song);
    final id = song['id'] = parseEntityId(song);
    // R1045 fix: Get extension before creating file path to ensure path matches actual file
    final songData = await getSongUrl(song, skipDownload: true);
    if (songData['songUrl'] == null)
      throw Exception('Could not find a download source.');
    final songUrl = songData['songUrl'];
    final mime = await getMimeTypeFromUrl(songUrl);
    final ext = getExtensionFromMime(mime);
    final _audioFile = p.join(_audioDirPath, '$id$ext');  // R1045 fix: Include extension
    final _artworkFile = File(p.join(_artworkDirPath, id));

    try {
      song = songData;
      if (song['songUrl'] == null)
        throw Exception('Could not find a download source.');
      final task = DownloadTask(
        taskId: id,
        url: songUrl,
        filename: '$id$ext',
        directory: 'tracks',
        baseDirectory: BaseDirectory.applicationSupport,
        updates: Updates.statusAndProgress,
        displayName: '${songTitle(song)} - ${songArtist(song)}',
        metaData: jsonEncode({
          'id': song['id'],
          'title': songTitle(song),
          'artist': songArtist(song),
        }),
      );
      final result = await FileDownloader().enqueue(task);
      if (!result)
        showToast(
          '${L10n.current.unableToDownload}: ${songTitle(song)} - ${songArtist(song)}',
        );
    } catch (e, stackTrace) {
      logger.log(
        'Error in makeSongOffline:',
        e,
        stackTrace,
      );
      throw Exception('Failed to download audio: $e');
    }

    try {
      final imagePath = await getValidImage(song);
      if (imagePath != null) {
        final artworkFile = await _downloadAndSaveArtworkFile(
          imagePath,
          _artworkFile.path,
        );

        if (artworkFile != null) {
          song['offlineArtworkPath'] = artworkFile.path;
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in makeSongOffline:',
        e,
        stackTrace,
      );
    }

    song['offlineAudioPath'] = _audioFile;
    
    // 8.3-B: Verify offline song quality after download
    final qualityResult = await verifyOfflineSongQuality(song);
    if (!qualityResult.isValid) {
      logger.log('Offline song quality check failed: ${qualityResult.message}', null, null);
      // Remove invalid download
      await removeSongFromOffline(song);
      showToast('Download failed quality verification. Please try again.');
    }
  } catch (e, stackTrace) {
    logger.log('Error in makeSongOffline:', e, stackTrace);
    rethrow;
  }
}

/// 8.3-B: Result class for offline song quality verification.
class OfflineSongQualityResult {
  final bool isValid;
  final String message;
  final int fileSize;
  final int? bitrate;
  
  OfflineSongQualityResult({
    required this.isValid,
    required this.message,
    this.fileSize = 0,
    this.bitrate,
  });
  
  factory OfflineSongQualityResult.invalid(String message) {
    return OfflineSongQualityResult(isValid: false, message: message);
  }
  
  factory OfflineSongQualityResult.valid({int fileSize = 0, int? bitrate}) {
    return OfflineSongQualityResult(
      isValid: true,
      message: 'Quality check passed',
      fileSize: fileSize,
      bitrate: bitrate,
    );
  }
}

/// 8.3-B: Verify the quality and integrity of an offline song.
/// Checks file existence, size, and attempts to read metadata.
Future<OfflineSongQualityResult> verifyOfflineSongQuality(dynamic song) async {
  try {
    final offlinePath = song['offlineAudioPath'] as String?;
    if (offlinePath == null || offlinePath.isEmpty) {
      return OfflineSongQualityResult.invalid('No offline path found');
    }
    
    final audioFile = File(offlinePath);
    
    // Check 1: File exists
    if (!await audioFile.exists()) {
      return OfflineSongQualityResult.invalid('Audio file not found');
    }
    
    // Check 2: File size meets minimum threshold (100KB)
    final fileSize = await audioFile.length();
    const minFileSize = 100 * 1024; // 100KB
    if (fileSize < minFileSize) {
      return OfflineSongQualityResult.invalid(
        'File too small (${(fileSize / 1024).toStringAsFixed(1)}KB < ${minFileSize ~/ 1024}KB)',
      );
    }
    
    // Check 3: File is readable and not corrupted
    try {
      final bytes = await audioFile.readAsBytes();
      if (bytes.isEmpty) {
        return OfflineSongQualityResult.invalid('File is empty');
      }
      
      // Basic format validation - check for common audio file headers
      final header = bytes.take(16).toList();
      final isLikelyAudio = _isValidAudioHeader(header);
      if (!isLikelyAudio) {
        return OfflineSongQualityResult.invalid('Invalid audio file format');
      }
    } catch (e) {
      return OfflineSongQualityResult.invalid('Cannot read file: $e');
    }
    
    return OfflineSongQualityResult.valid(fileSize: fileSize);
  } catch (e, stackTrace) {
    logger.log('Error in verifyOfflineSongQuality:', e, stackTrace);
    return OfflineSongQualityResult.invalid('Quality check failed: $e');
  }
}

/// 8.3-B: Check if file header looks like a valid audio file.
/// Supports MP3, M4A/AAC, OGG, FLAC, WEBM formats.
bool _isValidAudioHeader(List<int> header) {
  if (header.isEmpty) return false;
  
  // MP3: ID3v2 starts with "ID3" (0x49 0x44 0x33)
  // MP3 without ID3: 0xFF 0xFB or 0xFF 0xF3
  if (header.length >= 2) {
    if (header[0] == 0xFF && (header[1] == 0xFB || header[1] == 0xF3)) return true;
  }
  if (header.length >= 3) {
    if (header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) return true; // ID3
  }
  
  // M4A/AAC: starts with "ftyp" at offset 4
  if (header.length >= 8) {
    if (header[4] == 0x66 && header[5] == 0x74 && 
        header[6] == 0x79 && header[7] == 0x70) return true; // ftyp
  }
  
  // OGG: starts with "OggS"
  if (header.length >= 4) {
    if (header[0] == 0x4F && header[1] == 0x67 && 
        header[2] == 0x67 && header[3] == 0x53) return true; // OggS
  }
  
  // FLAC: starts with "fLaC"
  if (header.length >= 4) {
    if (header[0] == 0x66 && header[1] == 0x4C && 
        header[2] == 0x61 && header[3] == 0x43) return true; // fLaC
  }
  
  // WEBM: starts with EBML (0x1A 0x45 0xDF 0xA3)
  if (header.length >= 4) {
    if (header[0] == 0x1A && header[1] == 0x45 && 
        header[2] == 0xDF && header[3] == 0xA3) return true;
  }
  
  return false;
}

/// Get list of offline songs.
Future<List<dynamic>> getUserOfflineSongs() async {
  if (!(await checkOfflineFiles())) {
    await getExistingOfflineSongs();
  }
  final offline =
      userOfflineSongs.map((e) {
        final cached = getCachedSong(e);
        if (isSongValid(cached)) return cached;
        return <String, dynamic>{'id': e, 'title': null, 'artist': null};
      }).toList();
  return offline;
}

/// Get user's offline song by ID.
String getUserOfflineSong(dynamic song) {
  final id = parseEntityId(song);
  final offline = userOfflineSongs.firstWhere(
    (e) => checkEntityId(e, id),
    orElse: () => '',
  );
  return offline;
}

/// Check if offline files exist and are valid.
Future<bool> checkOfflineFiles() async {
  final dirValue = offlineDirectory.value;
  if (dirValue == null) return false;
  final _dir = Directory(dirValue);
  final _audioDirPath = p.join(_dir.path, 'tracks');
  if (!Directory(_audioDirPath).existsSync()) return false;
  final fileList =
      Directory(
        _audioDirPath,
      ).listSync().map((file) => p.basenameWithoutExtension(file.path)).toSet();
  final offlineSongsSet = userOfflineSongs.toSet();
  userOfflineSongs.removeWhere(
    (s) => !fileList.any((f) => checkEntityId(s, f)),
  );
  if (fileList.length != offlineSongsSet.length) return false;
  if (fileList.isEmpty && userOfflineSongs.isEmpty) return true;
  if ((userOfflineSongs.isEmpty && fileList.isNotEmpty) ||
      userOfflineSongs.length != fileList.length)
    return false;
  final exists = fileList.every(
    (f) => offlineSongsSet.any((s) => checkEntityId(f, s)),
  );
  return exists;
}

/// Scan device for music files.
Future<void> getUserDeviceSongs() async {
  try {
    if (await checkAllPermissions()) {
      final fileScanner = FileScanner(
        directories: additionalDirectories.toList(),
      );
      final _userDeviceSongs = await fileScanner.getUserDeviceSongs(
        additionalDirectories,
      );
      for (int i = 0; i < _userDeviceSongs.length; i++) {
        final result =
            await queueSongInfoRequest(_userDeviceSongs[i]).completerFuture;
        if (result != null) _userDeviceSongs[i] = result;
      }
      userDeviceSongs
        ..removeWhere(
          (e) =>
              e['id'] == null ||
              e['id'].isEmpty ||
              !_userDeviceSongs.any(
                (s) =>
                    checkSong(e, s) ||
                    e['devicePath'] == s['devicePath'] ||
                    e['fileName'] == s['fileName'],
              ),
        )
        ..addOrUpdateAllWhere(checkSong, _userDeviceSongs);
      unawaited(_getUserDeviceSongMetadata());
    }
  } catch (e, stackTrace) {
    logger.log('Error in getUserDeviceSongs:', e, stackTrace);
  }
}

/// Tag device songs with metadata.
Future<void> _getUserDeviceSongMetadata() async {
  final fileTagger = FileTagger();
  for (int i = 0; i < userDeviceSongs.length; i++) {
    final song = Map<String, dynamic>.from(userDeviceSongs[i]);
    if (!(songTitle(song).isUnknown && songArtist(song).isUnknown)) {
      final value = await queueSongInfoRequest(song).completerFuture;
      if (value != null) song.addAll(value);
      userDeviceSongs[i] = song;
      await fileTagger.tagOfflineFile(
        song,
        id: song['id'],
        filePath: song['devicePath'],
        rename: false,
      );
    }
  }
  userDeviceSongs.writeToCache();
}

/// Get existing offline songs from disk.
Future<void> getExistingOfflineSongs() async {
  // Fix: Use null-safe pattern for offlineDirectory.value
  final dirValue = offlineDirectory.value;
  if (dirValue == null) {
    logger.log('offlineDirectory not initialized yet', null, null);
    return;
  }
  final _dir = Directory(dirValue);
  final _audioDirPath = p.join(_dir.path, 'tracks');
  final List<String> _userOfflineSongs = [];
  await Directory(_audioDirPath).create(recursive: true);
  try {
    final fileList = Directory(_audioDirPath).listSync();
    for (final file in fileList) {
      try {
        final filename = p.basenameWithoutExtension(file.path);
        // Fix: Only rename files when MIME detection succeeds
        final mime = getMimeTypeFromFile(file.path);
        String newPath = file.path;
        if (mime != null) {
          final ext = getExtensionFromMime(mime);
          newPath = ensureCorrectExtension(file.path, extension: ext);
          if (newPath != file.path) {
            File(file.path).renameSync(newPath);
          }
        }
        // Fix: Check if file is audio BEFORE processing (use original path for check)
        if (isAudio(newPath)) {
          // Only add files with entity IDs (mb=, yt=, is=) to _userOfflineSongs
          final ids = Uri.parse('?$filename').queryParameters;
          final entityId = (ids['mb'] != null || ids['yt'] != null || ids['is'] != null)
              ? filename
              : 'fn=$filename';
          _userOfflineSongs.addOrUpdateWhere(checkEntityId, entityId);
        }
        if (filename.contains(RegExp(r'=|(\%3d)', caseSensitive: false))) {
          final fileTagger = FileTagger();
          final song =
              await queueSongInfoRequest({'id': filename}).completerFuture;
          await fileTagger.tagOfflineFile(song, id: parseEntityId(song));
        }
      } catch (_) {}
    }
    userOfflineSongs
      ..removeWhere((e) => !_userOfflineSongs.contains(e))
      ..addOrUpdateAll(_userOfflineSongs, checkEntityId);
  } catch (e, stackTrace) {
    logger.log('Error in getExistingOfflineSongs:', e, stackTrace);
  }
  userOfflineSongs.writeToCache();
}

/// Match file to song info.
Future<void> _matchFileToSongInfo(File file) async {
  try {
    // Fix: Use null-safe pattern for offlineDirectory.value
    final dirValue = offlineDirectory.value;
    if (dirValue == null) {
      logger.log('offlineDirectory not initialized yet', null, null);
      return;
    }
    final _dir = Directory(dirValue);
    final _artworkDirPath = p.join(_dir.path, 'artworks');
    await Directory(_artworkDirPath).create(recursive: true);
    final filename = p.basenameWithoutExtension(file.path);
    final song = await queueSongInfoRequest(filename).completerFuture;
    final imageFiles = await _getRelatedFiles(_artworkDirPath, song);
    if (imageFiles.isNotEmpty) {
      song?['offlineArtworkPath'] = imageFiles.first.path;
    }
    song?['offlineAudioPath'] = file.path;
    // Fix: Only add to userOfflineSongs if song ID is not null
    if (song?['id'] != null && song!['id'].isNotEmpty)
      userOfflineSongs.addOrUpdate(song['id'], checkEntityId);
  } catch (e, stackTrace) {
    logger.log('Error in _matchFileToSongInfo:', e, stackTrace);
  }
}

/// Get offline path for a song.
Future<String?> getOfflinePath(dynamic song) async {
  try {
    String? offlinePath =
        (song['devicePath'] ?? song['offlineAudioPath']) as String?;
    if (offlinePath != null) {
      if (offlinePath.startsWith('content') && Platform.isAndroid)
        offlinePath = await AndroidMediaStore.instance.uriToPath(offlinePath);
      if (offlinePath != null &&
          isFilePath(offlinePath) &&
          doesFileExist(offlinePath))
        return offlinePath;
    }
    // Fix: Use null-safe pattern for offlineDirectory.value
    final dirValue = offlineDirectory.value;
    if (dirValue == null) {
      logger.log('offlineDirectory not initialized yet', null, null);
      return null;
    }
    final _dir = Directory(dirValue);
    final _audioDirPath = p.join(_dir.path, 'tracks');
    final _artworkDirPath = p.join(_dir.path, 'artworks');
    await Directory(_audioDirPath).create(recursive: true);
    await Directory(_artworkDirPath).create(recursive: true);
    song['id'] = parseEntityId(song);
    final audioFiles = await _getRelatedFiles(_audioDirPath, song);
    final artworkFiles = await _getRelatedFiles(_artworkDirPath, song);
    //TODO: add quality check
    if (audioFiles.isNotEmpty) song['offlineAudioPath'] = audioFiles.first.path;
    if (artworkFiles.isNotEmpty)
      song['offlineArtworkPath'] = artworkFiles.first.path;
    offlinePath = song['offlineAudioPath'];
    if (offlinePath != null &&
        isFilePath(offlinePath) &&
        doesFileExist(offlinePath))
      return offlinePath;
  } catch (e, stackTrace) {
    logger.log('Error in getOfflinePath:', e, stackTrace);
  }
  return null;
}

/// Get related files for a song (audio and artwork).
Future<List<File>> _getRelatedFiles(String directory, dynamic entity) async {
  final files = <File>{};
  try {
    final ids = parseEntityId(entity).toIds;
    await for (final file in Directory(directory).list()) {
      for (final songId in ids.values) {
        if (file is File &&
            checkEntityId(songId, p.basenameWithoutExtension(file.path))) {
          files.add(file);
        }
      }
    }
    for (final song in userDeviceSongs) {
      if (checkSong(song, entity) &&
          song['devicePath'] != null &&
          song['devicePath'].isNotEmpty) {
        final deviceFile = File(song['devicePath'] as String);
        if (deviceFile.existsSync() &&
            !files.any((f) => f.path == deviceFile.path)) {
          files.add(deviceFile);
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in _getRelatedFiles:', e, stackTrace);
  }
  return files.toList();
}

/// Delete related files for a song.
Future<void> _deleteRelatedFiles(String directory, dynamic entity) async {
  try {
    final ids = Uri.parse('?${entity['id']}').queryParameters;
    await for (final file in Directory(directory).list()) {
      for (final songId in ids.values) {
        if (file is File &&
            p.basename(file.path).contains(songId) &&
            file.existsSync()) {
          await file.delete();
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in _deleteRelatedFiles:', e, stackTrace);
  }
}

/// Remove a song from offline storage.
Future<void> removeSongFromOffline(dynamic song) async {
  // Fix: Use null-safe pattern for offlineDirectory.value
  final dirValue = offlineDirectory.value;
  if (dirValue == null) {
    logger.log('offlineDirectory not initialized yet', null, null);
    showToast('Storage not ready. Please try again.');
    return;
  }
  final _dir = Directory(dirValue);
  final _audioDirPath = p.join(_dir.path, 'tracks');
  final _artworkDirPath = p.join(_dir.path, 'artworks');
  await Directory(_audioDirPath).create(recursive: true);
  await Directory(_artworkDirPath).create(recursive: true);
  song['id'] = parseEntityId(song);
  unawaited(_deleteRelatedFiles(_audioDirPath, song));
  unawaited(_deleteRelatedFiles(_artworkDirPath, song));
  song?.remove('offlineAudioPath');
  song?.remove('offlineArtworkPath');
  song?.remove('songUrl');
  song['isOffline'] = false;
  userOfflineSongs.removeWhere((s) => checkEntityId(song['id'], s));
  showToast(L10n.current.songRemovedFromOffline);
}

/// Download and save artwork file.
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
      await File(newFilePath).writeAsBytes(file.readAsBytesSync());
      return File(newFilePath);
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

        final file = File(newFilePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        logger.log(
          'Failed to download file. Status code: ${response.statusCode}',
          null,
          null,
        );
      }
    }
  } catch (e, stackTrace) {
    logger.log('Error in _downloadAndSaveArtworkFile:', e, stackTrace);
  }
  return null;
}
