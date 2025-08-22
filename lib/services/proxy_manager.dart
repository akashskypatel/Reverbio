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
  ProxyManager() {
    unawaited(_fetchProxies());
  }

  Future<void>? _fetchingList;
  bool _fetched = false;
  final Map<String, List<Proxy>> _proxies = {};
  final Set<Proxy> _workingProxies = {};
  final _random = Random();
  DateTime _lastFetched = DateTime.now();

  Future<void> _fetchProxies() async {
    try {
      if (kDebugMode) logger.log('Fetching proxies...', null, null);
      if (_fetchingList == null) {
        final futures =
            <Future>[]
              //..add(_fetchSpysMe())
              ..add(_fetchProxyScrape())
              ..add(_fetchOpenProxyList())
              ..add(_fetchJetkaiProxyList());
        _fetchingList = Future.wait(futures);
        await _fetchingList?.whenComplete(() {
          _fetched = true;
          if (kDebugMode)
            logger.log(
              'Done fetching Proxies. Fetched: ${_proxies.length}',
              null,
              null,
            );
          _lastFetched = DateTime.now();
          _fetchingList = null;
        });
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _fetchJetkaiProxyList() async {
    try {
      if (kDebugMode)
        logger.log('Fetching from jetkai/proxy-list...', null, null);
      const url =
          'https://raw.githubusercontent.com/jetkai/proxy-list/main/online-proxies/json/proxies-advanced.json';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        logger.log('Failed to fetch from jetkai/proxy-list', null, null);
        return;
      }
      final result = jsonDecode(response.body);
      (result as List).fold(_proxies, (v, e) {
        final isSSL = (e['protocols'] as List).any((e) => e['type'] == 'https');
        if (e['ip'] != null &&
            e['port'] != null &&
            e['location']['isocode'] != null &&
            isSSL) {
          v[e['location']['isocode']] = v[e['location']['isocode']] ?? [];
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
        logger.log('Proxies fetched: ${_proxies.length}', null, null);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _fetchOpenProxyList() async {
    try {
      if (kDebugMode) logger.log('Fetching from openproxylist...', null, null);
      const url =
          'https://raw.githubusercontent.com/roosterkid/openproxylist/main/HTTPS.txt';
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
          v[d['country']] = v[d['country']] ?? [];
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
      if (kDebugMode)
        logger.log('Proxies fetched: ${_proxies.length}', null, null);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _fetchSpysMe() async {
    try {
      if (kDebugMode) logger.log('Fetching from spys.me...', null, null);
      const url = 'https://spys.me/proxy.txt';
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
          v[d['country']] = v[d['country']] ?? [];
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
        logger.log('Proxies fetched: ${_proxies.length}', null, null);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _fetchProxyScrape() async {
    try {
      if (kDebugMode)
        logger.log('Fetching from proxyscrape.com...', null, null);
      const url =
          'https://api.proxyscrape.com/v4/free-proxy-list/get?request=display_proxies&proxy_format=protocolipport&format=json';
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
          v[e['ip_data']['countryCode']] = v[e['ip_data']['countryCode']] ?? [];
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
        logger.log('Proxies fetched: ${_proxies.length}', null, null);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  Future<StreamManifest?> _validateDirect(String songId, int timeout) async {
    try {
      if (kDebugMode) logger.log('Validating direct connection...', null, null);
      final manifest = await yt.videos.streams
          .getManifest(songId)
          .timeout(Duration(seconds: timeout));
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

  Future<StreamManifest?> _validateProxy(
    Proxy proxy,
    String songId,
    int timeout,
  ) async {
    if (kDebugMode) logger.log('Validating proxy...', null, null);
    IOClient? ioClient;
    HttpClient? client;
    try {
      client =
          HttpClient()
            ..connectionTimeout = Duration(seconds: timeout)
            ..findProxy = (_) {
              return 'PROXY ${proxy.address}; DIRECT';
            }
            ..badCertificateCallback = (context, _context, ___) {
              return false;
            };
      ioClient = IOClient(client);
      final pxyt = YoutubeExplode(YoutubeHttpClient(ioClient));
      final manifest = await pxyt.videos.streams
          .getManifest(songId)
          .timeout(Duration(seconds: timeout));
      _workingProxies.add(proxy);
      return manifest;
    } catch (e) {
      logger.log('Proxy ${proxy.source} - ${proxy.address} failed', e, null);
      client?.close(force: true);
      ioClient?.close();
      return null;
    }
  }

  Proxy? _randomProxySync({String? preferredCountry}) {
    try {
      if (_proxies.isEmpty) return null;
      Proxy proxy;
      String countryCode;
      if (_workingProxies.isNotEmpty) {
        final idx =
            _workingProxies.length == 1
                ? 0
                : _random.nextInt(_workingProxies.length);
        proxy = _workingProxies.elementAt(idx);
        _workingProxies.remove(proxy);
      } else {
        if (preferredCountry != null &&
            _proxies.containsKey(preferredCountry)) {
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
          proxy = countryProxies.removeLast();
        } else {
          proxy = countryProxies.removeAt(
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

  Future<Proxy?> _randomProxy({String? preferredCountry}) async {
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
        _workingProxies.remove(proxy);
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
            _proxies[countryCode] ?? _proxies.values.expand((x) => x).toList();
        if (countryProxies.isEmpty) {
          return null;
        }
        if (countryProxies.length == 1) {
          proxy = countryProxies.removeLast();
        } else {
          proxy = countryProxies.removeAt(
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

  Future<StreamManifest?> getSongManifest(
    String songId, {
    int timeout = 5,
  }) async {
    try {
      StreamManifest? manifest = await _validateDirect(songId, timeout);
      if (manifest != null) return manifest;
      if (DateTime.now().difference(_lastFetched).inMinutes >= 60)
        await _fetchProxies();
      manifest = await _cycleProxies(songId, timeout: timeout);
      return manifest;
    } catch (_) {
      return null;
    }
  }

  Future<StreamManifest?> _cycleProxies(
    String songId, {
    int timeout = 5,
  }) async {
    StreamManifest? manifest;
    do {
      final proxy = await _randomProxy();
      if (proxy == null) break;
      manifest = await _validateProxy(proxy, songId, timeout);
    } while (manifest == null);
    return manifest;
  }

  YoutubeHttpClient randomYoutubeProxyClient() {
    IOClient? ioClient;
    HttpClient? client;
    try {
      if (_workingProxies.isEmpty) unawaited(_fetchProxies());
      client =
          HttpClient()
            ..findProxy = (_) {
              final proxy = _randomProxySync();
              if (kDebugMode && proxy == null)
                logger.log(
                  'Could not find a proxy. Using direct connection.',
                  null,
                  null,
                );
              return proxy != null
                  ? 'PROXY ${proxy.address}; DIRECT;'
                  : 'DIRECT;';
            }
            ..badCertificateCallback = (_, __, ___) {
              return false;
            };
      ioClient = IOClient(client);
      return YoutubeHttpClient(ioClient);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      client?.close(force: true);
      ioClient?.close();
      return YoutubeHttpClient();
    }
  }
}
