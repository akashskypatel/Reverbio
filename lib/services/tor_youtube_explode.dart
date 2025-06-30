// Tor-enabled YoutubeExplode with circuit refresh
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class TorYoutubeExplode extends YoutubeExplode {

  TorYoutubeExplode() : super() {
    _torHttpClient = _createTorHttpClient();
  }
  final String torHost = '127.0.0.1';
  final int torPort = 9050; // SOCKS5 proxy port
  final int controlPort = 9051; // Control port for circuit refresh
  late final http.Client _torHttpClient;

  http.Client _createTorHttpClient() {
    final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30) 
    ..findProxy = (uri) => 'SOCKS5 $torHost:$torPort';
    return IOClient(client);
  }
  
  http.Client get httpClient => _torHttpClient;
  
  // Refresh Tor circuit to get a new IP
  Future refreshTorCircuit() async {
    try {
      print('Connecting to Tor control port at $torHost:$controlPort...');
      final socket = await Socket.connect(torHost, controlPort);
      print('Connected to Tor control port successfully');
      print('Sending AUTHENTICATE command...');
      socket.write('AUTHENTICATE\r\n');
      await socket.flush();

      // Read response
      final authResponse =
          await socket.listen((data) {
            print('Authentication response: ${utf8.decode(data)}');
          }).asFuture();
      print('Authentication completed');

      print('Requesting new Tor circuit...');
      socket.write('SIGNAL NEWNYM\r\n');
      await socket.flush();

      // Read response
      final newNymResponse =
          await socket.listen((data) {
            print('New circuit response: ${utf8.decode(data)}');
          }).asFuture();
      print('New circuit requested');

      // Get current IP address
      try {
        final response = await http.get(
          Uri.parse('https://api.ipify.org?format=json'),
        );
        if (response.statusCode == 200) {
          final ipData = json.decode(response.body);
          print('New IP Address: ${ipData['ip']}');
        }
      } catch (e) {
        print('Failed to get IP address: $e');
      }

      print('Closing Tor control connection...');
      socket.write('QUIT\r\n');
      await socket.flush();
      await Future.delayed(const Duration(seconds: 3)); // Wait for new circuit
      await socket.close();
      print('Tor circuit refresh completed successfully');
    } catch (e) {
      print('Failed to refresh Tor circuit: $e');
      print('Error details: ${e.toString()}');
    }
  }
}
