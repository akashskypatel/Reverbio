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
  int get hashCode => address.hashCode ^ country.hashCode;
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
  static final Set<Proxy> _workingProxies = {};
  static final _random = Random();
  static DateTime _lastFetched = DateTime.now();
  static IOClient _proxyClient = IOClient();
  static final YoutubeExplode _localYTClient = YoutubeExplode();
  static YoutubeExplode _proxyYTClient = YoutubeExplode();

  YoutubeExplode get localYoutubeClient => _localYTClient;
  YoutubeExplode get proxyYoutubeClient => _proxyYTClient;

  static Future<void> ensureInitialized() async {
    if (_fetchingList != null)
      await _fetchingList!.then((_) {
        _proxyClient = _randomProxyClient();
        _proxyYTClient = YoutubeExplode(YoutubeHttpClient(_proxyClient));
      });
    else if (_proxies.isEmpty ||
        DateTime.now().difference(_lastFetched).inMinutes >= 60 ||
        !_fetched)
      await _fetchProxies().then((_) {
        _proxyClient = _randomProxyClient();
        _proxyYTClient = YoutubeExplode(YoutubeHttpClient(_proxyClient));
      });
  }

  static Future<void> _fetchProxies() async {
    try {
      if (kDebugMode) logger.log('Fetching proxies...', null, null);
      if (_fetchingList == null ||
          DateTime.now().difference(_lastFetched).inMinutes >= 60) {
        final futures =
            <Future>[]
              //..add(_fetchSpysMe())
              //..add(_fetchOpenProxyListXyz())
              ..add(_fetchProxyScrape())
              ..add(_fetchOpenProxyList())
              ..add(_fetchJetkaiProxyList());
        _fetchingList = Future.wait(futures);
        await _fetchingList?.whenComplete(() {
          _fetched = true;
          if (kDebugMode) logger.log('Done fetching Proxies.', null, null);
          _lastFetched = DateTime.now();
          _fetchingList = null;
        });
      } else {
        await _fetchingList;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
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
          return;
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
      (result as List).fold(_proxies, (v, e) {
        final isSSL = (e['protocols'] as List).any(
          (e) =>
              [
                //'https',
                'socks4', 'socks5',
              ].contains(e['type']) &&
              e['tls'] == true,
        );
        if (e['ip'] != null &&
            e['port'] != null &&
            e['location']['isocode'] != null &&
            isSSL) {
          current++;
          v[e['location']['isocode']] = v[e['location']['isocode']] ?? {};
          v[e['location']['isocode']]!.add(
            Proxy(
              source: 'jetkai/proxy-list',
              address: '${e['ip']}:${e['port']}',
              country: e['location']['isocode'],
              ssl: isSSL,
            ),
          );
        }
        return v;
      });
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
          return;
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
      final result = jsonDecode(response.body);
      (result['proxies'] as List).fold(_proxies, (v, e) {
        if (e['ip_data'] != null &&
            (e['alive'] ?? false) &&
            e['ip_data']['countryCode'] != null &&
            (e['ssl'] ?? false)) {
          current++;
          v[e['ip_data']['countryCode']] = v[e['ip_data']['countryCode']] ?? {};
          v[e['ip_data']['countryCode']]!.add(
            Proxy(
              source: 'proxyscrape.com',
              address: '${e['ip']}:${e['port']}',
              country: e['ip_data']['countryCode'],
              ssl: e['ssl'],
            ),
          );
        }
        return v;
      });
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
    try {
      if (kDebugMode) logger.log('Validating direct connection...', null, null);
      StreamManifest? manifest;
      if (timeout != null)
        manifest = await _localYTClient.videos.streams
            .getManifest(songId)
            .timeout(Duration(seconds: timeout));
      else
        manifest = await _localYTClient.videos.streams.getManifest(songId);
      if (kDebugMode)
        logger.log(
          'Direct connection succeeded. Proxy not needed.',
          null,
          null,
        );
      return manifest;
    } catch (e) {
      logger.log('Direct connection failed', e, null);
      return null;
    }
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
          .getManifest(songId)
          .timeout(Duration(seconds: timeout));
      _workingProxies.add(proxy);
      if (kDebugMode)
        logger.log(
          'Manifest success by proxy: ${proxy.source} - ${proxy.address}',
          null,
          null,
        );
      ytExplode.close();
      return manifest;
    } catch (e) {
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
      if (_workingProxies.isNotEmpty) {
        final idx =
            _workingProxies.length == 1
                ? 0
                : _random.nextInt(_workingProxies.length);
        proxy = _workingProxies.elementAt(idx);
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
      await Isolate.spawn(
        _getYouTubeAudioUrl,
        _IsolateMessage(
          sendPort: receivePort.sendPort,
          songId: songId,
          timeout: timeout,
          qualitySetting: qualitySetting,
          useProxy: useProxy,
        ),
      );

      receivePort.listen((message) {
        if (message is String && message.isNotEmpty) {
          completer.complete(message);
        } else if (message is Exception) {
          completer.completeError(message);
        } else {
          completer.complete('');
        }
        receivePort.close();
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
    try {
      StreamManifest? manifest = await _validateDirect(
        songId,
        useProxy ? timeout : null,
      );
      if (manifest != null) {
        return manifest;
      }
      if (useProxy) {
        if (DateTime.now().difference(_lastFetched).inMinutes >= 60)
          await _fetchProxies();
        manifest = await _cycleProxies(songId, timeout);
        return manifest;
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

  static Future<void> _getYouTubeAudioUrl(_IsolateMessage message) async {
    try {
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
        final audioUrl = audioQuality.url.toString();
        return message.sendPort.send(audioUrl);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return message.sendPort.send('');
    }
  }

  static AudioStreamInfo selectAudioQuality(
    List<AudioStreamInfo> availableSources,
    String qualitySetting,
  ) {
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
    try {
      StreamManifest? manifest;
      Proxy? proxy;
      final client =
          HttpClient()
            ..badCertificateCallback = (context, _context, ___) {
              return false;
            };
      final ioClient = IOClient(client);
      final ytExplode = YoutubeExplode(YoutubeHttpClient(ioClient));
      do {
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
      } while (manifest == null);
      return manifest;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
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
  });
  final SendPort sendPort;
  final String songId;
  final int timeout;
  final String qualitySetting;
  final bool useProxy;
}
