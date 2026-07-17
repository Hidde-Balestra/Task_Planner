import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/task.dart';

class TransferService {
  static HttpServer? _server;

  /// Starts a local HTTP server on the current wifi network that serves
  /// [tasks] as JSON to exactly one requester carrying the right token,
  /// then stops itself. Returns the QR payload to display, or null if no
  /// local network address could be found (e.g. no wifi connection).
  static Future<String?> startSendServer(
    List<Task> tasks, {
    required void Function() onTransferred,
  }) async {
    final ip = await localIPv4Address();
    if (ip == null) return null;

    final token = _generateToken();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;

    final body = jsonEncode(tasks.map((t) => t.toMap()).toList());

    server.listen((request) async {
      final requestToken = request.uri.queryParameters['token'];
      if (request.uri.path == '/tasks' && requestToken == token) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(body);
        await request.response.close();
        onTransferred();
        await stopSendServer();
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
      }
    });

    return jsonEncode({'ip': ip, 'port': server.port, 'token': token});
  }

  static Future<void> stopSendServer() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  /// Returns the device's local wifi/LAN IPv4 address, or null if none is
  /// available (e.g. no wifi connection).
  static Future<String?> localIPv4Address() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return null;
  }

  static String _generateToken() {
    final rand = Random.secure();
    return List.generate(
      16,
      (_) => rand.nextInt(16).toRadixString(16),
    ).join();
  }

  /// Parses a scanned QR payload and fetches tasks from the sending device
  /// over the local network. Throws a [FormatException] for malformed QR
  /// data, or an [Exception] on network/HTTP failure.
  static Future<List<Task>> receiveFromQrPayload(String payload) async {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final ip = data['ip'] as String;
    final port = data['port'] as int;
    final token = data['token'] as String;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(
        Uri.parse('http://$ip:$port/tasks?token=$token'),
      );
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Overdracht mislukt (${response.statusCode})');
      }
      final responseBody = await response.transform(utf8.decoder).join();
      final jsonList = jsonDecode(responseBody) as List<dynamic>;
      return jsonList
          .map((e) => Task.fromMap(e as Map<String, dynamic>))
          .toList();
    } finally {
      client.close();
    }
  }
}
