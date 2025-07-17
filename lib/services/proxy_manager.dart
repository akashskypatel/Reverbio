import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

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
      logger.log('Fetching proxies...', null, null);
      final futures =
          <Future>[]
            ..add(_fetchSpysMe())
            ..add(_fetchProxyScrape())
            ..add(_fetchOpenProxyList());
      _fetchingList = Future.wait(futures);
      await _fetchingList?.whenComplete(() {
        _fetched = true;
        logger.log(
          'Done fetching Proxies. Fetched: ${_proxies.length}',
          null,
          null,
        );
        _lastFetched = DateTime.now();
      });
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _fetchProxiesIsolate() async {
    logger.log('Fetching proxies...', null, null);
    final receivePort = ReceivePort();
    final isolates =
        <Future>[]
          ..add(Isolate.spawn(_fetchOpenProxyListIsolate, receivePort.sendPort))
          ..add(Isolate.spawn(_fetchSpysMeIsolate, receivePort.sendPort))
          ..add(Isolate.spawn(_fetchProxyScrapeIsolate, receivePort.sendPort));
    final expectedMessages = isolates.length;
    int receivedMessages = 0;

    await Future.wait(isolates);
    _fetchingList =
        receivePort.listen((message) {
          (message as Map).forEach((country, list) {
            _proxies[country] = _proxies[country] ?? [];
            for (final proxyMap in list) {
              final proxy = Proxy(
                address: proxyMap['address'],
                country: proxyMap['country'],
                ssl: proxyMap['ssl'],
                source: proxyMap['source'],
              );
              if (!_proxies[country]!.contains(proxy)) {
                _proxies[country]!.add(proxy);
              }
            }
          });
          receivedMessages += 1;
          if (receivedMessages >= expectedMessages) {
            receivePort.close();
          }
        }).asFuture();
    await _fetchingList?.whenComplete(() {
      _fetched = true;
      logger.log(
        'Done fetching Proxies. Fetched: ${_proxies.values.fold(0, (v, e) => v + e.length)}',
        null,
        null,
      );
      _lastFetched = DateTime.now();
    });
  }

  void _fetchOpenProxyListIsolate(SendPort sendPort) async {
    final proxies = <String, List<dynamic>>{};
    try {
      logger.log('Fetching from openproxylist...', null, null);
      const url =
          'https://raw.githubusercontent.com/roosterkid/openproxylist/main/HTTPS.txt';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch from openproxylist');
      }
      response.body.split('\n').fold(proxies, (v, e) {
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
          v[d['country']]!.add({
            'source': 'openproxylist',
            'address': '${d['ip']}:${d['port']}',
            'country': d['country'],
            'ssl': true,
          });
        }
        return v;
      });
      logger.log(
        'Proxies fetched: ${proxies.values.fold(0, (v, e) => v + e.length)} from openproxylist',
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
    sendPort.send(proxies);
  }

  Future<void> _fetchOpenProxyList() async {
    try {
      logger.log('Fetching from openproxylist...', null, null);
      const url =
          'https://raw.githubusercontent.com/roosterkid/openproxylist/main/HTTPS.txt';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        logger.log('Failed to fetch from spys.me', null, null);
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
      logger.log('Proxies fetched: ${_proxies.length}', null, null);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  void _fetchSpysMeIsolate(SendPort sendPort) async {
    final proxies = <String, List<dynamic>>{};
    try {
      logger.log('Fetching from spys.me...', null, null);
      const url = 'https://spys.me/proxy.txt';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch from spys.me');
      }
      response.body.split('\n').fold(proxies, (v, e) {
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
          v[d['country']]!.add({
            'source': 'spys.me',
            'address': '${d['ip']}:${d['port']}',
            'country': d['country'],
            'ssl': d['ssl'],
          });
        }
        return v;
      });
      logger.log(
        'Proxies fetched: ${proxies.values.fold(0, (v, e) => v + e.length)} from spys.me',
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
    sendPort.send(proxies);
  }

  Future<void> _fetchSpysMe() async {
    try {
      logger.log('Fetching from spys.me...', null, null);
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
      logger.log('Proxies fetched: ${_proxies.length}', null, null);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  void _fetchProxyScrapeIsolate(SendPort sendPort) async {
    final proxies = <String, List<dynamic>>{};
    try {
      logger.log('Fetching from proxyscrape.com...', null, null);
      const url =
          'https://api.proxyscrape.com/v4/free-proxy-list/get?request=display_proxies&proxy_format=protocolipport&format=json';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch from proxyscrape');
      }
      final result = jsonDecode(response.body);
      (result['proxies'] as List).fold(proxies, (v, e) {
        if (e['ip_data'] != null &&
            (e['alive'] ?? false) &&
            e['ip_data']['countryCode'] != null &&
            (e['ssl'] ?? false)) {
          v[e['ip_data']['countryCode']] = v[e['ip_data']['countryCode']] ?? [];
          v[e['ip_data']['countryCode']]!.add({
            'source': 'proxyscrape.com',
            'address': '${e['ip']}:${e['port']}',
            'country': e['ip_data']['countryCode'],
            'ssl': e['ssl'],
          });
        }
        return v;
      });
      logger.log(
        'Proxies fetched: ${proxies.values.fold(0, (v, e) => v + e.length)} from proxyscrape.com',
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
    sendPort.send(proxies);
  }

  Future<void> _fetchProxyScrape() async {
    try {
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
      logger.log('Validating direct connection...', null, null);
      final manifest = await yt.videos.streams
          .getManifest(songId)
          .timeout(Duration(seconds: timeout));
      logger.log('Direct connection succeeded. Proxy not needed.', null, null);
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
    logger.log('Validating proxy...', null, null);
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

  Future<StreamManifest?> getSongManifest(String songId) async {
    try {
      StreamManifest? manifest = await _validateDirect(songId, 5);
      if (manifest != null) return manifest;
      if (DateTime.now().difference(_lastFetched).inMinutes >= 60)
        await _fetchProxies();
      manifest = await _cycleProxies(songId);
      return manifest;
    } catch (_) {
      return null;
    }
  }

  Future<StreamManifest?> _cycleProxies(String songId) async {
    StreamManifest? manifest;
    do {
      final proxy = await _randomProxy();
      if (proxy == null) break;
      manifest = await _validateProxy(proxy, songId, 5);
    } while (manifest == null);
    return manifest;
  }

  void _cycleProxiesIsolate(dynamic params) async {
    final SendPort? sendPort = params['sendPort'];
    final String? songId = params['songId'];
    if (sendPort == null || songId == null) throw Exception('Invalid params.');
    StreamManifest? manifest;
    do {
      final proxy = await _randomProxy();
      if (proxy == null) break;
      manifest = await _validateProxy(proxy, songId, 5);
    } while (manifest == null);
    return sendPort.send(manifest);
  }
}
