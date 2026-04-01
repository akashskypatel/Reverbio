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
const String downloadObtainium = 'obtainium';

// R9 fix: In-progress guard to prevent duplicate update checks
bool _isCheckingUpdates = false;
bool _isUpdateDialogShowing = false;

// R12 fix: Shared helper for HTTP requests with timeout
Future<http.Response> _httpGetWithTimeout(Uri uri, {String label = ''}) async {
  try {
    return await http.get(uri).timeout(
      const Duration(seconds: 10),  // R10 fix: Add HTTP request timeout
      onTimeout: () {
        logger.log('HTTP GET timeout for $label: $uri', null, null);
        throw TimeoutException('HTTP GET timeout for $label');
      },
    );
  } catch (e, stackTrace) {
    logger.log('HTTP GET error for $label', e, stackTrace);
    rethrow;
  }
}

Future<Map<String, dynamic>> getLatestAppVersion() async {
  try {
    final response = await _httpGetWithTimeout(Uri.parse(checkUrl), label: 'checkUrl');

    if (response.statusCode != 200) {
      logger.log(
        'Fetch update API (checkUrl) call returned status code ${response.statusCode}',
        null,
        null,
      );
      return {'error': L10n.current.errorLatestVersion, 'canUpdate': false};
    }

    final map = json.decode(response.body) as Map<String, dynamic>;
    announcementURL.value = map['announcementurl'];
    final latestVersion = map['version'].toString();
    if (isLatestVersionHigher(appVersion, latestVersion)) {
      return {
        'message':
            '${L10n.current.currentVersion}: $appVersion ${L10n.current.latestVersion}: $latestVersion',
        'canUpdate': true,
      };
    }
    return {
      'message': '${L10n.current.latestVersionUsed}: $appVersion',
      'canUpdate': false,
    };
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}', e, stackTrace);
    return {'error': L10n.current.errorLatestVersion, 'canUpdate': false};
  }
}

Future<void> checkAppUpdates() async {
  // R9 fix: In-progress guard to prevent duplicate update checks
  if (_isCheckingUpdates || _isUpdateDialogShowing) return;
  
  try {
    _isCheckingUpdates = true;
    final response = await _httpGetWithTimeout(Uri.parse(checkUrl), label: 'checkUrl');

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

    final releasesRequest = await _httpGetWithTimeout(Uri.parse(releasesUrl), label: 'releasesUrl');

    if (releasesRequest.statusCode != 200) {
      logger.log(
        'Fetch update API (releasesUrl) call returned status code ${releasesRequest.statusCode}',
        null,
        null,
      );
      return;
    }

    final releasesResponse =
        json.decode(releasesRequest.body) as Map<String, dynamic>;

    // R8 fix: Add null guard for NavigationManager().context
    final navContext = NavigationManager().context;
    if (navContext == null || !navContext.mounted) {
      logger.log('Navigation context not available for update dialog', null, null);
      return;
    }
    
    _isUpdateDialogShowing = true;  // R9 fix: Set guard before showing dialog
    
    await showDialog(
      context: navContext,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                L10n.current.appUpdateIsAvailable,
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
                  // R4 fix: Add null fallback for AutoFormatText.text
                  child: AutoFormatText(text: releasesResponse['body'] ?? ''),
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
              child: Text(L10n.current.cancel.toUpperCase()),
            ),
            FilledButton(
              onPressed: () {
                // R5 fix: Changed set literal {} to statement block () { ... }
                getDownloadUrl(map).then((url) {
                  launchURL(Uri.parse(url));
                  GoRouter.of(context).pop(context);
                });
              },
              child: Text(L10n.current.download.toUpperCase()),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _isUpdateDialogShowing = false;  // R9 fix: Reset guard when dialog closes
    });
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}', e, stackTrace);
  } finally {
    _isCheckingUpdates = false;  // R9 fix: Reset guard
  }
}

// R11 fix: Add try/catch for non-numeric version segments
bool isLatestVersionHigher(String appVersion, String latestVersion) {
  try {
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
  } catch (e, stackTrace) {
    // R11 fix: Handle non-numeric version segments gracefully
    logger.log('Error comparing versions: $appVersion vs $latestVersion', e, stackTrace);
    return false;
  }
}

// R6 fix: Use null-aware access to prevent "null" string returns
Future<String> getDownloadUrl(Map<String, dynamic> map) async {
  if (io.Platform.isAndroid) {
    return map[downloadUrlKey]?.toString() ?? '';
  }
  if (io.Platform.isWindows) {
    return map[downloadAmd64url]?.toString() ?? '';
  }
  return map[downloadLatest]?.toString() ?? '';
}

// R7 fix: Change return type to Future<void> for proper async handling
Future<void> postUpdate() async {
  final hasPostUpdateRun = postUpdateRun.value[appVersion] ?? false;
  if (!hasPostUpdateRun) {
    //Make changes from here
    //await clearCache();
    //to here
  }
  // R2 fix: Reassign value to trigger NotifiableValue persistence
  postUpdateRun.value = Map.from(postUpdateRun.value)..[appVersion] = true;
}
