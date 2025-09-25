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

  Future<List<Map<String, dynamic>>> getUserDeviceSongs() async {
    _startNotification();
    final completer = Completer<List<Map<String, dynamic>>>();
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _getUserDeviceSongs,
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

  Future<void> _getUserDeviceSongs(_IsolateMessage message) async {
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
            final song = {
              'title': title,
              'artist': artist,
              'devicePath': file.path,
            };
            userDeviceSongs.addOrUpdateWhere(checkSong, song);
          }
        } catch (_) {}
      }
    }
    message.sendPort.send(userDeviceSongs);
  }
}

// Message class for isolate communication
class _IsolateMessage {
  _IsolateMessage({required this.sendPort, required this.directories});
  final SendPort sendPort;
  final List<String> directories;
}
