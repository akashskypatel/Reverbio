/*
 * Unit tests for network-dependent functions with mocked HTTP.
 * Tests getSkipSegments, getIPGeolocation, and proxy_manager functions.
 */

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/services/proxy_manager.dart';

import '../../helpers/test_fixtures.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    setUpAllServices();
  });

  tearDownAll(() {
    tearDownAllServices();
  });

  group('getSkipSegments', () {
    test('MockClient returns 200 with segments JSON returns list of segments',
        () async {
      final fixture = loadFixture('sponsorblock_segments.json');
      final mockClient = MockClient((request) async {
        return http.Response(fixture, 200);
      });

      final result = await getSkipSegments('dQw4w9WgXcQ', client: mockClient);

      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.length, equals(2));
      expect(result.first['category'], equals('sponsor'));
    });

    test('MockClient returns 404 returns empty list (R5 regression)',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final result = await getSkipSegments('invalid', client: mockClient);

      expect(result, equals([]));
    });

    test('MockClient returns 200 with empty segments returns empty list',
        () async {
      final fixture = loadFixture('sponsorblock_empty.json');
      final mockClient = MockClient((request) async {
        return http.Response(fixture, 200);
      });

      final result = await getSkipSegments('empty', client: mockClient);

      expect(result, equals([]));
    });

    test('MockClient throws SocketException returns empty list', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Network error');
      });

      final result = await getSkipSegments('error', client: mockClient);

      expect(result, equals([]));
    });

    test('Request URL contains the ytid parameter', () async {
      Uri? capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('[]', 200);
      });

      await getSkipSegments('testYtId', client: mockClient);

      expect(capturedUri, isNotNull);
      expect(capturedUri!.queryParameters['videoID'], equals('testYtId'));
    });
  });

  group('getIPGeolocation', () {
    test('MockClient returns 200 with IP JSON returns non-null Map', () async {
      final fixture = loadFixture('ip_geolocation.json');
      final mockClient = MockClient((request) async {
        return http.Response(fixture, 200);
      });

      final result = await getIPGeolocation(client: mockClient);

      expect(result, isA<Map<String, dynamic>>());
      expect(result['country'], equals('United States'));
      expect(result['countryCode'], equals('US'));
    });

    test('Request uses HTTPS scheme (R6 regression)', () async {
      Uri? capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{"country":"US"}', 200);
      });

      await getIPGeolocation(client: mockClient);

      expect(capturedUri, isNotNull);
      expect(capturedUri!.scheme, equals('https'));
    });

    test('MockClient returns 200 but bad JSON returns empty Map', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not valid json', 200);
      });

      final result = await getIPGeolocation(client: mockClient);

      expect(result, equals({}));
    });

    test('MockClient throws returns empty Map', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Network error');
      });

      final result = await getIPGeolocation(client: mockClient);

      expect(result, equals({}));
    });
  });

  group('proxy_manager.dart — non-network functions', () {
    group('Proxy hashCode and equality (R13 fix)', () {
      test('two proxies with same address+country have same hashCode', () {
        final proxy1 = Proxy(
          address: '192.168.1.1',
          country: 'US',
          source: 'test',
          ssl: true,
        );
        final proxy2 = Proxy(
          address: '192.168.1.1',
          country: 'US',
          source: 'test',
          ssl: true,
        );

        expect(proxy1.hashCode, equals(proxy2.hashCode));
      });

      test('Proxy == operator same address+country are equal', () {
        final proxy1 = Proxy(
          address: '192.168.1.1',
          country: 'US',
          source: 'test',
          ssl: true,
        );
        final proxy2 = Proxy(
          address: '192.168.1.1',
          country: 'US',
          source: 'test',
          ssl: true,
        );

        expect(proxy1, equals(proxy2));
      });

      test('Proxy != operator different address are not equal', () {
        final proxy1 = Proxy(
          address: '192.168.1.1',
          country: 'US',
          source: 'test',
          ssl: true,
        );
        final proxy2 = Proxy(
          address: '192.168.1.2',
          country: 'US',
          source: 'test',
          ssl: true,
        );

        expect(proxy1, isNot(equals(proxy2)));
      });
    });
  });
}
