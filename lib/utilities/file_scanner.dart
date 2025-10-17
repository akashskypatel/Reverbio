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
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/media_utils.dart';
import 'package:reverbio/utilities/utils.dart';

class FileScanner {
  FileScanner({required this.directories});
  final List<String> directories;
  final ValueNotifier<int> progress = ValueNotifier(0);

  void _startNotification() {
    showToast(
      L10n.current.scanningStart,
      id: 'scanningDeviceFiles',
      data: progress,
    );
  }

  void _endNotification(int found) {
    showToast('${L10n.current.scanningEnd} $found', id: 'scanningDeviceFiles');
  }

  Future<List<Map<String, dynamic>>> getUserDeviceSongsIsolate() async {
    _startNotification();
    final completer = Completer<List<Map<String, dynamic>>>();
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _getUserDeviceSongsIsolate,
      _IsolateMessage(sendPort: receivePort.sendPort, directories: directories),
    );

    receivePort.listen((message) {
      if (message is int) {
        progress.value = message;
      } else if (message is Exception) {
        completer.completeError(message);
      } else if (message is List<Map<String, dynamic>>) {
        completer.complete(message);
        receivePort.close();
        _endNotification(message.length);
      } else {
        completer.complete([]);
        receivePort.close();
        _endNotification(0);
      }
    });

    return completer.future;
  }

  Future<void> _getUserDeviceSongsIsolate(_IsolateMessage message) async {
    final List<Map<String, dynamic>> userDeviceSongs = [];
    final List<FileSystemEntity> fileList = [];
    for (final dir in message.directories) {
      fileList.addAll(Directory(dir).listSync(recursive: true));
    }
    for (int i = 0; i < fileList.length; i++) {
      final file = fileList[i];
      message.sendPort.send((i + 1) ~/ fileList.length);
      if (file is File && isAudio(file.path)) {
        try {
          final tag = await AudioTags.read(file.path);
          final title = tag?.title ?? basenameWithoutExtension(file.path);
          final artist = tag?.trackArtist ?? tag?.albumArtist;
          if (artist != null && title.isNotEmpty) {
            final song = <String, dynamic>{
              'title': title,
              'artist': artist,
              'devicePath':
                  Platform.isAndroid
                      ? await MediaUtils.instance.pathToUri(file.path)
                      : file.path,
            };
            if (tag != null) song['audioTags'] = tagToMap(tag);
            userDeviceSongs.addOrUpdateWhere(checkSong, song);
          }
        } catch (_) {}
      }
    }
    message.sendPort.send(userDeviceSongs);
  }

  Future<List<Map<String, dynamic>>> getUserDeviceSongs(
    List<String> directories,
  ) async {
    Map<String, dynamic> song = {};
    _startNotification();
    final List<Map<String, dynamic>> _userDeviceSongs = [];
    final List<FileSystemEntity> fileList = [];
    for (final dir in directories) {
      fileList.addAll(Directory(dir).listSync(recursive: true));
    }
    for (int i = 0; i < fileList.length; i++) {
      final file = fileList[i];
      progress.value = (i + 1) ~/ fileList.length;
      if (file is File && isAudio(file.path)) {
        try {
          Tag? tag;
          try {
            tag = await AudioTags.read(file.path);
          } catch (_) {}
          String title, artist;
          final fileName = basenameWithoutExtension(file.path).nullIfEmpty;
          title = tag?.title ?? fileName ?? L10n.current.unknown;
          artist = tag?.trackArtist ?? tag?.albumArtist ?? L10n.current.unknown;
          if (fileName != null &&
              fileName.contains(RegExp(r'=|(\%3d)', caseSensitive: false))) {
            final _song = await queueSongInfoRequest(fileName).completerFuture;
            if (_song != null && _song.isNotEmpty)
              song = {
                ..._song,
                'fileName': fileName,
                'devicePath':
                    Platform.isAndroid
                        ? await MediaUtils.instance.pathToUri(file.path)
                        : file.path,
              };
          } else if (artist.isUnknown && !title.isUnknown) {
            song = {
              ...tryParseTitleAndArtist(song),
              'fileName': fileName,
              'devicePath':
                  Platform.isAndroid
                      ? await MediaUtils.instance.pathToUri(file.path)
                      : file.path,
            };
          } else {
            song = {
              'id': 'fn=$fileName',
              'title': title,
              'artist': artist,
              'fileName': fileName,
              'devicePath':
                  Platform.isAndroid
                      ? await MediaUtils.instance.pathToUri(file.path)
                      : file.path,
            };
          }
          if (tag != null) song['audioTags'] = tagToMap(tag);
          _userDeviceSongs.addOrUpdateWhere(checkSong, song);
        } catch (_) {}
      }
    }
    _endNotification(_userDeviceSongs.length);
    return _userDeviceSongs;
  }
}

// Message class for isolate communication
class _IsolateMessage {
  _IsolateMessage({required this.sendPort, required this.directories});
  final SendPort sendPort;
  final List<String> directories;
}
