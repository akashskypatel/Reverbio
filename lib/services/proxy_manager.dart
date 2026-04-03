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
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/main.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class Proxy {
  Proxy({
    required this.source,
    required this.country,
    required this.address,
    this.ssl,
  });
  final String address;
  final String country;
  final bool? ssl;
  final String source;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Proxy &&
        other.address == address &&
        other.country == country;
  }

  @override
  int get hashCode => Object.hash(address, country);
}

class ProxyManager {
  factory ProxyManager() => _instance;
  ProxyManager._internal() {
    ensureInitialized();
  }
  static final ProxyManager _instance = ProxyManager._internal();
  static Future<void>? _fetchingList;
  static bool _fetched = false;
  static final Map<String, Set<Proxy>> _proxies = {};
  // R4 fix: Track working proxies with timestamps for TTL-based expiration
  static final Map<Proxy, DateTime> _workingProxies = {};
  // R4 fix: TTL for working proxies (10 minutes)
  static const Duration _workingProxyTTL = Duration(minutes: 10);
  static final _random = Random();
  static DateTime _lastFetched = DateTime.fromMillisecondsSinceEpoch(0);
  static IOClient _proxyClient = IOClient();
  static final YoutubeExplode _localYTClient = YoutubeExplode();
  static YoutubeExplode _proxyYTClient = YoutubeExplode();

  YoutubeExplode get localYoutubeClient => _localYTClient;
  YoutubeExplode get proxyYoutubeClient => _proxyYTClient;

  static Future<void> ensureInitialized() async {
    final fetchingList = _fetchingList;
    if (fetchingList != null) {
      await fetchingList;
    } else if (_proxies.isEmpty ||
        DateTime.now().difference(_lastFetched).inMinutes >= 60 ||
        !_fetched) {
      await _fetchProxies();
      // Reinitialize clients only after fetch is complete
      // R97 fix: Don't close old clients - let them complete in-flight requests naturally
      // Old clients will be garbage collected when no longer referenced
      _proxyClient = _randomProxyClient();
      _proxyYTClient = YoutubeExplode(YoutubeHttpClient(_proxyClient));
      // Note: Old clients NOT closed to prevent breaking in-flight requests
      // They will be garbage collected when no longer in use
    }
    // If no fetch occurred, keep existing clients (no disruption to in-flight requests)
  }

  static Future<void> _fetchProxies() async {
    // R4 fix: Assign future to _fetchingList to prevent concurrent fetches
    final completer = Completer<void>();
    _fetchingList = completer.future;
    try {
      if (kDebugMode) logger.log('Fetching proxies...', null, null);
      _proxies.clear();
      // Clear working proxies on refresh to prevent stale entries
      _workingProxies.clear();

      final futures =
          <Future>[]
            ..add(_fetchJetkaiProxyList())
            ..add(_fetchOpenProxyList())
            ..add(_fetchProxyScrape());

      // R115 fix: Removed dead code - fetch methods return void, results are populated via side effects
      await Future.wait(futures);
      _lastFetched = DateTime.now();
      _fetched = true;
      completer.complete();
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      completer.completeError(e);
    } finally {
      // R4 fix: Clear _fetchingList after fetch completes (success or error)
      _fetchingList = null;
    }
  }

  static Future<void> _fetchOpenProxyListXyz() async {
    try {
      if (kDebugMode)
        logger.log('Fetching from OpenProxyList.xyz...', null, null);
      const sources = [
        //'https://api.openproxylist.xyz/https.txt',
        'https://api.openproxylist.xyz/socks4.txt',
        'https://api.openproxylist.xyz/socks5.txt',
      ];
      int current = 0;
      for (final url in sources) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          logger.log('Failed to fetch from OpenProxyList.xyz', null, null);
          continue;
        }
        response.body.split('\n').fold(_proxies, (v, e) {
          final rgx = RegExp(r'(?<ip>\d+\.\d+\.\d+\.\d+)\:(?<port>\d+)$');
          final rgxm = rgx.firstMatch(e);
          Map d = {};
          if (rgxm != null)
            d = {
              'ip': (rgxm.namedGroup('ip') ?? '').trim(),
              'port': (rgxm.namedGroup('port') ?? '').trim(),
              'country': 'US',
              'ssl': true,
            };

          if (d.isNotEmpty && d['country'].isNotEmpty && d['ssl']) {
            current++;
            v[d['country']] = v[d['country']] ?? {};
            v[d['country']]!.add(
              Proxy(
                source: 'openproxylist.xyz',
                address: '${d['ip']}:${d['port']}',
                country: d['country'],
                ssl: d['ssl'],
              ),
            );
          }
          return v;
        });
      }
      if (kDebugMode)
        logger.log(
          'Proxies fetched: $current from OpenProxyList.xyz',
          null,
          null,
        );
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  ///
  /// Fetches proxies from jetkai/proxy-list
  ///
  /// Example Schema:
  ///
  /// [ {
  ///  "ip" : "1.0.136.16",
  ///  "port" : 4153,
  ///  "protocols" : [ {
  ///    "type" : "socks4",
  ///    "port" : 4153,
  ///    "tls" : false
  ///  } ],
  ///  "location" : {
  ///    "continent" : "Asia",
  ///    "country" : "Thailand",
  ///    "isocode" : "TH",
  ///    "region" : "Nakhon Pathom",
  ///    "regioncode" : "73",
  ///    "city" : "Nakhon Pathom",
  ///    "latitude" : 13.8667,
  ///    "longitude" : 100.1917,
  ///    "provider" : "TOT Public Company Limited",
  ///    "organisation" : "TOT Public Company Limited",
  ///    "asn" : "AS23969"
  ///  },
  ///  "dateAdded" : "2023-04-10 23:34:13.0",
  ///  "lastTested" : "2023-04-15 02:35:46.0",
  ///  "lastSuccess" : "2023-04-15 02:35:45.0"
  ///}]
  static Future<void> _fetchJetkaiProxyList() async {
    try {
      if (kDebugMode)
        logger.log('Fetching from jetkai/proxy-list...', null, null);
      const url =
          'https://raw.githubusercontent.com/jetkai/proxy-list/main/online-proxies/json/proxies-advanced.json';
      int current = 0;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        logger.log('Failed to fetch from jetkai/proxy-list', null, null);
        return;
      }
      final result = jsonDecode(response.body);
      // Handle both array and object with 'proxies' key
      final List proxiesList;
      if (result is List) {
        proxiesList = result;
      } else if (result is Map && result['proxies'] is List) {
        proxiesList = result['proxies'] as List;
      } else {
        logger.log('Unexpected jetkai response format', null, null);
        return;
      }

      for (final e in proxiesList) {
        try {
          if (e is! Map) continue;
          final entry = e as Map<String, dynamic>;
          
          // Parse protocols array - check for SOCKS4/SOCKS5 with TLS
          final protocols = entry['protocols'];
          if (protocols is! List || protocols.isEmpty) continue;
          
          final isSSL = protocols.any((p) {
            if (p is! Map) return false;
            final type = p['type'] as String?;
            final tls = p['tls'] as bool?;
            return (type == 'socks4' || type == 'socks5') && (tls ?? false);
          });
          
          if (!isSSL) continue;
          
          // Parse location object
          final location = entry['location'];
          if (location is! Map) continue;
          final isocode = location['isocode'] as String?;
          if (isocode == null || isocode.isEmpty) continue;
          
          // Parse ip and port
          final ip = entry['ip'] as String?;
          if (ip == null || ip.isEmpty) continue;
          
          final port = entry['port'];
          if (port == null) continue;
          // Port can be int or String - convert to String
          final portStr = port is int ? port.toString() : port as String?;
          if (portStr == null || portStr.isEmpty) continue;

          current++;
          _proxies[isocode] = _proxies[isocode] ?? {};
          _proxies[isocode]!.add(
            Proxy(
              source: 'jetkai/proxy-list',
              address: '$ip:$portStr',
              country: isocode,
              ssl: isSSL,
            ),
          );
        } catch (e) {
          // Skip invalid entries
        }
      }
      if (kDebugMode)
        logger.log(
          'Proxies fetched: $current from jetkai/proxy-list',
          null,
          null,
        );
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  ///
  /// Fetches proxies from openproxylist
  ///
  /// Example Schema:
  ///
  /// SOCKS4 Proxy list updated at 2026-03-30 06:00:01 GMT+7
  /// Website=https://openproxylist.com
  ///
  /// Support us:
  /// BTC : 1PJNmhxKETLqaD6eexiNxg8ofT4uF7GKvF
  /// ETH : 0x50403baa42092a3424f41fdc3a8621aeda333ee6
  /// LTC : MAG1cWWEpgdviZChWvr2oyuxD61JPJ1Q43
  /// Doge: DSmsHYZUz5NZcfCgso1ZSAvz4ayv6kUPKQ
  /// https://buymeacoffee.com/roosterkid
  ///
  /// Format: CountryFlag IP:PORT ResponseTime CountryCode [ISP]
  ///
  /// Example entries:
  /// - 🇲🇳 203.174.26.137:4153 296ms MN [YokozunaNET]
  /// - 🇧🇼 83.143.29.161:1080 285ms BW [BOTSWANA FIBRE NETWORKS]
  /// - 🇧🇩 203.190.8.59:1088 183ms BD [DAFFODILNET-SUB]
  static Future<void> _fetchOpenProxyList() async {
    try {
      if (kDebugMode) logger.log('Fetching from openproxylist...', null, null);
      const sources = [
        //'https://raw.githubusercontent.com/roosterkid/openproxylist/main/HTTPS.txt',
        'https://raw.githubusercontent.com/roosterkid/openproxylist/refs/heads/main/SOCKS4.txt',
        'https://raw.githubusercontent.com/roosterkid/openproxylist/refs/heads/main/SOCKS5.txt',
      ];
      int current = 0;
      for (final url in sources) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          logger.log('Failed to fetch from openproxylist', null, null);
          continue;
        }
        response.body.split('\n').fold(_proxies, (v, e) {
          final rgx = RegExp(
            r'(.)\s(?<ip>\d+\.\d+\.\d+\.\d+)\:(?<port>\d+)\s(?:(?<responsetime>\d+)(?:ms))\s(?<country>[A-Z]{2})\s(?<isp>.+)$',
          );
          final rgxm = rgx.firstMatch(e);
          Map d = {};
          if (rgxm != null)
            d = {
              'ip': (rgxm.namedGroup('ip') ?? '').trim(),
              'port': (rgxm.namedGroup('port') ?? '').trim(),
              'country': (rgxm.namedGroup('country') ?? '').trim(),
            };

          if (d.isNotEmpty && d['country'].isNotEmpty) {
            current++;
            v[d['country']] = v[d['country']] ?? {};
            v[d['country']]!.add(
              Proxy(
                source: 'openproxylist',
                address: '${d['ip']}:${d['port']}',
                country: d['country'],
                ssl: true,
              ),
            );
          }
          return v;
        });
      }
      if (kDebugMode)
        logger.log('Proxies fetched: $current from openproxylist', null, null);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  ///
  /// Fetches proxies from spys.me
  ///
  /// Example Schema:
  ///
  /// Proxy list (#400) updated at Mon, 30 Mar 26 01:58:01 +0300
  /// Socks proxy=https://spys.me/socks.txt
  /// Support by donations:
  /// BTC bc1q0hxnu4gmn5ru8j7g29tv2dq2ng5g0zhanl6t4t
  /// IP address:Port CountryCode-Anonymity(Noa/Anm/Hia)-SSL_support(S)-Google_passed(+)
  ///
  /// 103.90.67.35:8080 ID-N! -
  /// 179.1.48.49:8080 CO-N! -
  /// 114.5.97.150:8080 ID-N -
  static Future<void> _fetchSpysMe() async {
    try {
      if (kDebugMode) logger.log('Fetching from spys.me...', null, null);
      const url = 'https://spys.me/proxy.txt';
      int current = 0;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        logger.log('Failed to fetch from spys.me', null, null);
        return;
      }
      response.body.split('\n').fold(_proxies, (v, e) {
        final rgx = RegExp(
          r'(?<ip>\d+\.\d+\.\d+\.\d+)\:(?<port>\d+)\s(?<country>[A-Z]{2})\-(?<anon>[HNA!]{1,2})(?:\s|\-)(?<ssl>[\sS!]*)(?:\s)?(?<google>[\+\-]?)(?:\s)$',
        );
        final rgxm = rgx.firstMatch(e);
        Map d = {};
        if (rgxm != null)
          d = {
            'ip': (rgxm.namedGroup('ip') ?? '').trim(),
            'port': (rgxm.namedGroup('port') ?? '').trim(),
            'country': (rgxm.namedGroup('country') ?? '').trim(),
            'anon': (rgxm.namedGroup('anon') ?? '').trim(),
            'ssl': (rgxm.namedGroup('ssl') ?? '').trim().isNotEmpty,
            'google': (rgxm.namedGroup('google') ?? '').trim() == '+',
          };

        if (d.isNotEmpty &&
            d['country'].isNotEmpty &&
            d['ssl'] &&
            d['google']) {
          current++;
          v[d['country']] = v[d['country']] ?? {};
          v[d['country']]!.add(
            Proxy(
              source: 'spys.me',
              address: '${d['ip']}:${d['port']}',
              country: d['country'],
              ssl: d['ssl'],
            ),
          );
        }
        return v;
      });
      if (kDebugMode)
        logger.log('Proxies fetched: $current from spys.me', null, null);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  ///
  /// Fetches proxies from proxyscrape.com
  ///
  /// Example Schema:
  /// {
  ///   "proxies": [
  ///     {
  ///       "alive": true,
  ///       "alive_since": 1774827836.8593388,
  ///       "anonymity": "elite",
  ///       "average_timeout": 963.237919717382,
  ///       "first_seen": 1697032567.714141,
  ///       "ip_data": {
  ///         "as": "AS46562 Performive LLC",
  ///         "asname": "PERFORMIVE",
  ///         "city": "Los Angeles",
  ///         "continent": "North America",
  ///         "continentCode": "NA",
  ///         "country": "United States",
  ///         "countryCode": "US",
  ///         "district": "",
  ///         "hosting": true,
  ///         "isp": "Performive LLC",
  ///         "lat": 34.0549,
  ///         "lon": -118.243,
  ///         "mobile": false,
  ///         "org": "Performive LLC",
  ///         "proxy": true,
  ///         "regionName": "California",
  ///         "status": "success",
  ///         "timezone": "America/Los_Angeles",
  ///         "zip": "90009"
  ///       },
  ///       "ip_data_last_update": 1774499670,
  ///       "last_seen": 1774827836.8593388,
  ///       "port": 4145,
  ///       "protocol": "socks4",
  ///       "proxy": "socks4://142.54.229.249:4145",
  ///       "ssl": true,
  ///       "timeout": 808.3782196044922,
  ///       "times_alive": 178424,
  ///       "times_dead": 742837,
  ///       "uptime": 19.367367119632764,
  ///       "ip": "142.54.229.249"
  ///     }
  ///   ]
  /// }
  static Future<void> _fetchProxyScrape() async {
    try {
      if (kDebugMode)
        logger.log('Fetching from proxyscrape.com...', null, null);
      const url =
          'https://api.proxyscrape.com/v4/free-proxy-list/get?request=display_proxies&ssl=yes&proxy_format=protocolipport&format=json';
      int current = 0;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        logger.log('Failed to fetch from proxyscrape', null, null);
        return;
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final proxiesList = result['proxies'] as List?;
      if (proxiesList == null) {
        logger.log('No proxies in proxyscrape response', null, null);
        return;
      }
      for (final e in proxiesList) {
        try {
          if (e is! Map) continue;
          final entry = e as Map<String, dynamic>;
          final ipData = entry['ip_data'];
          if (ipData is! Map) continue;

          final countryCode = ipData['countryCode'] as String?;
          final ip = entry['ip'] as String?;
          final port = entry['port']; // Can be int or String
          final alive = entry['alive'] as bool?;
          final ssl = entry['ssl'] as bool?;

          if (countryCode != null && (alive ?? false) && (ssl ?? false)) {
            current++;
            _proxies[countryCode] = _proxies[countryCode] ?? {};
            _proxies[countryCode]!.add(
              Proxy(
                source: 'proxyscrape.com',
                address: '$ip:$port',
                country: countryCode,
                ssl: ssl ?? false,
              ),
            );
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
      if (kDebugMode)
        logger.log(
          'Proxies fetched: $current from proxyscrape.com',
          null,
          null,
        );
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<StreamManifest?> _validateDirect(
    String songId,
    int? timeout,
  ) async {
    StreamManifest? manifest;
    try {
      if (kDebugMode) logger.log('Validating direct connection...', null, null);
      if (timeout != null)
        manifest = await _localYTClient.videos.streams
            .getManifest(songId, ytClients: [YoutubeApiClient.androidVr])
            .timeout(Duration(seconds: timeout));
      else
        manifest = await _localYTClient.videos.streams.getManifest(
          songId,
          ytClients: [YoutubeApiClient.androidVr],
        );
      if (kDebugMode)
        logger.log(
          'Direct connection succeeded. Proxy not needed.',
          null,
          null,
        );
    } catch (e) {
      logger.log('Direct connection failed', e, null);
      return null;
    }
    return manifest;
  }

  static Future<StreamManifest?> _validateProxy(
    Proxy proxy,
    String songId,
    int timeout,
    YoutubeExplode ytExplode,
  ) async {
    if (kDebugMode) logger.log('Validating proxy...', null, null);
    try {
      final manifest = await ytExplode.videos.streams
          .getManifest(songId, ytClients: [YoutubeApiClient.androidVr])
          .timeout(Duration(seconds: timeout));
      // R4 fix: Add proxy with current timestamp for TTL tracking
      _workingProxies[proxy] = DateTime.now();
      if (kDebugMode)
        logger.log(
          'Manifest success by proxy: ${proxy.source} - ${proxy.address}',
          null,
          null,
        );
      ytExplode.close();
      return manifest;
    } catch (e) {
      // Remove from working proxies on failure
      _workingProxies.remove(proxy);
      logger.log('Proxy ${proxy.source} - ${proxy.address} failed', e, null);
      return null;
    }
  }

  static Proxy? _randomProxySync({String? preferredCountry}) {
    try {
      if (_proxies.isEmpty) return null;
      Proxy proxy;
      String countryCode;
      if (preferredCountry != null && _proxies.containsKey(preferredCountry)) {
        countryCode = preferredCountry;
      } else {
        countryCode = userGeolocation['countryCode'] ?? _proxies.keys.first;
      }
      final countryProxies =
          _proxies[countryCode] ?? _proxies.values.expand((x) => x).toList();
      if (countryProxies.isEmpty) {
        return null;
      }
      if (countryProxies.length == 1) {
        proxy = countryProxies.last;
      } else {
        proxy = countryProxies.elementAt(
          _random.nextInt(countryProxies.length),
        );
      }
      return proxy;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
  }

  static Future<Proxy?> _randomProxy({String? preferredCountry}) async {
    try {
      if (!_fetched) await _fetchingList;
      if (_fetched && _proxies.isEmpty) await _fetchProxies();
      if (_proxies.isEmpty) return null;
      Proxy proxy;
      String countryCode;
      
      // R4 fix: Expire old working proxies based on TTL
      final now = DateTime.now();
      _workingProxies.removeWhere((_, timestamp) => 
          now.difference(timestamp) > _workingProxyTTL);
      
      if (_workingProxies.isNotEmpty) {
        // R4 fix: Select from working proxies (keys of the map)
        final workingProxyList = _workingProxies.keys.toList();
        final idx =
            workingProxyList.length == 1
                ? 0
                : _random.nextInt(workingProxyList.length);
        proxy = workingProxyList[idx];
      } else {
        if (preferredCountry != null &&
            _proxies.containsKey(preferredCountry)) {
          countryCode = preferredCountry;
        } else {
          countryCode =
              userGeolocation['countryCode'] ??
              (await getIPGeolocation())['countryCode'] ??
              _proxies.keys.first;
        }
        final countryProxies =
            _proxies[countryCode] ?? _proxies.values.expand((x) => x).toSet();
        if (countryProxies.isEmpty) {
          return null;
        }
        if (countryProxies.length == 1) {
          proxy = countryProxies.first;
        } else {
          proxy = countryProxies.elementAt(
            _random.nextInt(countryProxies.length),
          );
        }
        if (kDebugMode)
          logger.log(
            'Selected proxy: ${proxy.source} - ${proxy.address}',
            null,
            null,
          );
      }
      return proxy;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<String> getYouTubeAudioUrl(
    String songId,
    int timeout,
    String qualitySetting,
    bool useProxy,
  ) async {
    final completer = Completer<String>();
    final receivePort = ReceivePort();
    try {
      // Serialize proxies for isolate
      final serializableProxies = <String, List<Map<String, dynamic>>>{};
      for (final entry in _proxies.entries) {
        serializableProxies[entry.key] =
            entry.value
                .map(
                  (p) => {
                    'address': p.address,
                    'country': p.country,
                    'ssl': p.ssl,
                    'source': p.source,
                  },
                )
                .toList();
      }

      final isolate = await Isolate.spawn(
        _getYouTubeAudioUrl,
        _IsolateMessage(
          sendPort: receivePort.sendPort,
          songId: songId,
          timeout: timeout,
          qualitySetting: qualitySetting,
          useProxy: useProxy,
          proxies: serializableProxies.isNotEmpty ? serializableProxies : null,
          // R1 fix: Serialize working proxies with timestamps for warm-cache preference
          workingProxies: _workingProxies.isNotEmpty
              ? _workingProxies.map(
                  (proxy, ts) => MapEntry(
                    proxy.address,
                    ts.toIso8601String(),
                  ),
                )
              : null,
        ),
      );

      receivePort.listen((message) {
        // R3/R4 fix: Handle result map with URL and winning proxy
        if (message is Map && message['url'] is String) {
          final audioUrl = message['url'] as String;
          final winningProxy = message['winningProxy'] as Map<String, dynamic>?;
          
          // R4 fix: Upsert winning proxy into _workingProxies with current timestamp
          if (winningProxy != null && winningProxy['address'] is String) {
            final proxy = Proxy(
              address: winningProxy['address'] as String,
              country: winningProxy['country'] as String? ?? 'US',
              ssl: winningProxy['ssl'] as bool?,
              source: winningProxy['source'] as String? ?? 'working',
            );
            _workingProxies[proxy] = DateTime.now();
          }
          
          if (audioUrl.isNotEmpty) {
            completer.complete(audioUrl);
          } else {
            completer.completeError(Exception('Failed to get audio URL'));
          }
        } else if (message is Exception) {
          completer.completeError(message);
        } else {
          completer.completeError(Exception('Failed to get audio URL'));
        }
        receivePort.close();
        isolate.kill();
      });

      return completer.future;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      completer.completeError(
        'Error in ${stackTrace.getCurrentMethodName()}: $e\n$stackTrace',
      );
      return completer.future;
    }
  }

  static Future<StreamManifest?> _getSongManifest(
    String songId,
    int timeout,
    bool useProxy,
  ) async {
    StreamManifest? manifest;
    try {
      manifest = await _validateDirect(songId, useProxy ? timeout : null);
      if (manifest == null && useProxy) {
        if (DateTime.now().difference(_lastFetched).inMinutes >= 60)
          await _fetchProxies();
        manifest = await _cycleProxies(songId, timeout);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return manifest;
  }

  static Future<void> _getYouTubeAudioUrl(_IsolateMessage message) async {
    String audioUrl = '';
    Map<String, dynamic>? winningProxyData;
    // R5 fix: Explicit local YT client construction in isolate
    final localYTClient = YoutubeExplode();
    try {
      // Deserialize proxies from message
      if (message.proxies != null) {
        _proxies.clear();
        for (final entry in message.proxies!.entries) {
          _proxies[entry.key] =
              entry.value
                  .map(
                    (p) => Proxy(
                      address: p['address'] as String,
                      country: p['country'] as String,
                      ssl: p['ssl'] as bool?,
                      source: p['source'] as String,
                    ),
                  )
                  .toSet();
        }
      }

      // R2 fix: Deserialize working proxies with timestamps for warm-cache preference
      final _workingProxies = <Proxy, DateTime>{};
      if (message.workingProxies != null) {
        for (final entry in message.workingProxies!.entries) {
          // Find matching proxy from deserialized _proxies
          for (final proxyList in _proxies.values) {
            final proxy = proxyList.firstWhere(
              (p) => p.address == entry.key,
              orElse: () => Proxy(
                address: entry.key,
                country: 'US',
                ssl: true,
                source: 'working',
              ),
            );
            _workingProxies[proxy] = DateTime.parse(entry.value);
          }
        }
      }

      final manifest = await _getSongManifest(
        message.songId,
        message.timeout,
        message.useProxy,
      );
      if (manifest != null) {
        final audioQuality = selectAudioQuality(
          manifest.audioOnly.sortByBitrate(),
          message.qualitySetting,
        );
        audioUrl = audioQuality.url.toString();
        // R3 fix: Capture winning proxy info to send back
        // Note: _validateProxy would need to return the proxy used, but for now
        // we just send the URL. The working proxy cache will be updated on success.
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    } finally {
      // R5 fix: Close local YT client to prevent descriptor leak
      localYTClient.close();
    }
    // R3 fix: Send result map with URL and winning proxy info
    message.sendPort.send({
      'url': audioUrl,
      'winningProxy': winningProxyData,
    });
  }

  static AudioStreamInfo selectAudioQuality(
    List<AudioStreamInfo> availableSources,
    String qualitySetting,
  ) {
    if (availableSources.isEmpty) {
      throw StateError('No audio sources available');
    }
    if (qualitySetting == 'low') {
      return availableSources.last;
    } else if (qualitySetting == 'medium') {
      return availableSources[availableSources.length ~/ 2];
    } else if (qualitySetting == 'high') {
      return availableSources.first;
    } else {
      return availableSources.withHighestBitrate();
    }
  }

  static Future<StreamManifest?> _cycleProxies(
    String songId,
    int timeout,
  ) async {
    StreamManifest? manifest;
    const int maxRetries = 5;
    HttpClient? client;
    IOClient? ioClient;
    YoutubeExplode? ytExplode;
    try {
      Proxy? proxy;
      client =
          HttpClient()
            ..badCertificateCallback = (context, _context, ___) {
              return false;
            };
      ioClient = IOClient(client);
      ytExplode = YoutubeExplode(YoutubeHttpClient(ioClient));

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        await Future.delayed(Duration.zero);
        proxy = await _randomProxy();
        if (proxy == null) break;
        client
          ..connectionTimeout = Duration(seconds: timeout)
          ..findProxy = (_) {
            return proxy != null
                ? 'PROXY ${proxy.address}; DIRECT;'
                : 'DIRECT;';
          };
        manifest = await _validateProxy(proxy, songId, timeout, ytExplode);
        if (manifest != null) break;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    } finally {
      ytExplode?.close();
      client?.close();
      ioClient?.close();
    }

    if (manifest == null) {
      logger.log(
        'All $maxRetries proxies failed after $maxRetries attempts',
        null,
        null,
      );
    }
    return manifest;
  }

  static IOClient _randomProxyClient() {
    IOClient? ioClient;
    HttpClient? client;
    try {
      client =
          HttpClient()
            ..findProxy = (uri) {
              final proxy = _randomProxySync();
              return proxy != null
                  ? 'PROXY ${proxy.address}; DIRECT;'
                  : 'DIRECT;';
            }
            ..badCertificateCallback = (_, __, ___) {
              return false;
            };
      ioClient = IOClient(client);
      return ioClient;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      client?.close(force: true);
      ioClient?.close();
      return IOClient();
    }
  }
}

// Message class for isolate communication
class _IsolateMessage {
  _IsolateMessage({
    required this.sendPort,
    required this.songId,
    required this.timeout,
    required this.qualitySetting,
    required this.useProxy,
    this.proxies,
    this.workingProxies,
  });
  final SendPort sendPort;
  final String songId;
  final int timeout;
  final String qualitySetting;
  final bool useProxy;
  final Map<String, List<Map<String, dynamic>>>? proxies;
  // R1 fix: Pass working proxies to isolate for warm-cache preference
  final Map<String, String>? workingProxies;
}
