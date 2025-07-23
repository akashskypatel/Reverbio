/*
 *     Copyright (C) 2025 Akashy Patel
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
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:reverbio/API/version.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/url_launcher.dart';
import 'package:reverbio/widgets/auto_format_text.dart';

const String checkUrl =
    'https://raw.githubusercontent.com/akashskypatel/Reverbio/update/check.json';
const String releasesUrl =
    'https://api.github.com/repos/akashskypatel/Reverbio/releases/latest';
const String downloadUrlKey = 'android';
const String downloadAmd64url = 'amd64url';
const String downloadLatest = 'latest';

Future<Map<String, dynamic>> getLatestAppVersion() async {
  try {
    final response = await http.get(Uri.parse(checkUrl));

    if (response.statusCode != 200) {
      logger.log(
        'Fetch update API (checkUrl) call returned status code ${response.statusCode}',
        null,
        null,
      );
      return {
        'error': 'Error getting lastest app version.',
        'canUpdate': false,
      };
    }

    final map = json.decode(response.body) as Map<String, dynamic>;
    announcementURL.value = map['announcementurl'];
    final latestVersion = map['version'].toString();
    if (isLatestVersionHigher(appVersion, latestVersion)) {
      return {
        'message': 'Current version: $appVersion New Version: $latestVersion',
        'canUpdate': true,
      };
    }
    return {
      'message': 'You using the latest version: $appVersion',
      'canUpdate': false,
    };
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}', e, stackTrace);
    return {'error': 'Error getting lastest app version.', 'canUpdate': false};
  }
}

Future<void> checkAppUpdates() async {
  try {
    final response = await http.get(Uri.parse(checkUrl));

    if (response.statusCode != 200) {
      logger.log(
        'Fetch update API (checkUrl) call returned status code ${response.statusCode}',
        null,
        null,
      );
      return;
    }

    final map = json.decode(response.body) as Map<String, dynamic>;
    announcementURL.value = map['announcementurl'];
    final latestVersion = map['version'].toString();

    if (!isLatestVersionHigher(appVersion, latestVersion)) {
      return;
    }

    final releasesRequest = await http.get(Uri.parse(releasesUrl));

    if (releasesRequest.statusCode != 200) {
      logger.log(
        'Fetch update API (releasesUrl) call returned status code ${response.statusCode}',
        null,
        null,
      );
      return;
    }

    final releasesResponse =
        json.decode(releasesRequest.body) as Map<String, dynamic>;

    await showDialog(
      context: NavigationManager().context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n!.appUpdateIsAvailable,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'V$latestVersion',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height / 2.14,
                ),
                child: SingleChildScrollView(
                  child: AutoFormatText(text: releasesResponse['body']),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            OutlinedButton(
              onPressed: () {
                GoRouter.of(context).pop(context);
              },
              child: Text(context.l10n!.cancel.toUpperCase()),
            ),
            FilledButton(
              onPressed: () {
                getDownloadUrl(map).then(
                  (url) => {
                    launchURL(Uri.parse(url)),
                    GoRouter.of(context).pop(context),
                  },
                );
              },
              child: Text(context.l10n!.download.toUpperCase()),
            ),
          ],
        );
      },
    );
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}', e, stackTrace);
  }
}

bool isLatestVersionHigher(String appVersion, String latestVersion) {
  final parsedAppVersion = appVersion.split('.');
  final parsedAppLatestVersion = latestVersion.split('.');
  final length =
      parsedAppVersion.length > parsedAppLatestVersion.length
          ? parsedAppVersion.length
          : parsedAppLatestVersion.length;
  for (var i = 0; i < length; i++) {
    final value1 =
        i < parsedAppVersion.length ? int.parse(parsedAppVersion[i]) : 0;
    final value2 =
        i < parsedAppLatestVersion.length
            ? int.parse(parsedAppLatestVersion[i])
            : 0;
    if (value2 > value1) {
      return true;
    } else if (value2 < value1) {
      return false;
    }
  }

  return false;
}

Future<String> getDownloadUrl(Map<String, dynamic> map) async {
  if (io.Platform.isAndroid) return map[downloadUrlKey].toString();
  if (io.Platform.isWindows) return map[downloadAmd64url].toString();
  return map[downloadLatest].toString();
}
