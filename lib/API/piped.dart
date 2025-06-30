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
