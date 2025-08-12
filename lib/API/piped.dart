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

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';

class PipedVideoAccount {
  PipedVideoAccount({
    required this.username,
    required this.password,
    required this.instance,
  });
  final String username;
  final String password;
  final PipedVideoInstance instance;
  String? token;
}

class PipedVideoInstance {
  const PipedVideoInstance({
    required this.name,
    required this.apiUrl,
    required this.locations,
    this.cdn = false,
  });
  final String name;
  final String apiUrl;
  final String locations;
  final bool cdn;
}

class PipedVideo {
  PipedVideo(PipedVideoAccount account) {
    unawaited(login(account));
    PipedVideo.accounts.add(account);
  }
  static final List<PipedVideoAccount> accounts = [];
  static final List<PipedVideoInstance> instances = [];

  Future<String?> login(PipedVideoAccount account) async {
    try {
      final payload = {
        'account': account.username,
        'password': account.password,
      };
      final uri = Uri.https(account.instance.apiUrl, '/login');
      final response = await http.post(uri, body: payload);
      final result = Map<String, dynamic>.from(jsonDecode(response.body));
      if (result['token'] == null)
        throw ErrorDescription(
          'Could not log in to ${account.instance.apiUrl}.',
        );
      account.token = result['token'];
      return result['token'];
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<String?> getAudioUrl(String videoId) async {
    try {
      final uri = Uri.https('pipedapi.kavin.rocks', '/streams/$videoId');
      final response = await http.get(uri);
      final data = Map<String, dynamic>.from(jsonDecode(response.body));
      if (data['audioStreams'] != null && data['audioStreams'].isNotEmpty) {
        for (final stream in data['audioStreams']) {
          return stream['url'];
        }
      }
      return null;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
  }
}
