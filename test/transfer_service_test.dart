import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:task_planner/models/task.dart';
import 'package:task_planner/services/transfer_service.dart';

void main() {
  group('TransferService - startSendServer / token validation', () {
    tearDown(() async {
      await TransferService.stopSendServer();
    });

    test('serves tasks to a client with the correct token', () async {
      final tasks = [
        Task(title: 'Task A', repeatDays: []),
        Task(title: 'Task B', repeatDays: [1, 3]),
      ];

      var transferredCalled = false;
      final payload = await TransferService.startSendServer(
        tasks,
        onTransferred: () => transferredCalled = true,
      );

      if (payload == null) {
        // No non-loopback network interface available in this environment.
        return;
      }

      final data = jsonDecode(payload) as Map<String, dynamic>;
      final port = data['port'] as int;
      final token = data['token'] as String;

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/tasks?token=$token'),
      );
      final response = await request.close();
      expect(response.statusCode, 200);
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final list = jsonDecode(body) as List<dynamic>;
      expect(list.length, 2);

      // onTransferred/stopSendServer run in the server's handler after the
      // response is flushed, which is a separate async chain from the
      // client's read above -- give it a turn of the event loop.
      await Future.delayed(const Duration(milliseconds: 50));
      expect(transferredCalled, isTrue);
    });

    test('rejects a request with the wrong token', () async {
      final tasks = [Task(title: 'Task A', repeatDays: [])];
      final payload = await TransferService.startSendServer(
        tasks,
        onTransferred: () {},
      );

      if (payload == null) return;

      final data = jsonDecode(payload) as Map<String, dynamic>;
      final port = data['port'] as int;

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/tasks?token=wrong-token'),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.forbidden);
      client.close();
    });

    test('stops accepting requests after a successful transfer', () async {
      final tasks = [Task(title: 'Task A', repeatDays: [])];
      final payload = await TransferService.startSendServer(
        tasks,
        onTransferred: () {},
      );

      if (payload == null) return;

      final data = jsonDecode(payload) as Map<String, dynamic>;
      final port = data['port'] as int;
      final token = data['token'] as String;
      final uri = Uri.parse('http://127.0.0.1:$port/tasks?token=$token');

      final client = HttpClient();
      final firstResponse = await (await client.getUrl(uri)).close();
      expect(firstResponse.statusCode, 200);
      await firstResponse.drain<void>();

      await expectLater(
        client.getUrl(uri).then((r) => r.close()),
        throwsA(anything),
      );
      client.close();
    });
  });

  group('TransferService - receiveFromQrPayload', () {
    tearDown(() async {
      await TransferService.stopSendServer();
    });

    test('parses and fetches tasks from a valid payload', () async {
      final tasks = [Task(title: 'Solo task', repeatDays: [])];
      final payload = await TransferService.startSendServer(
        tasks,
        onTransferred: () {},
      );

      if (payload == null) return;

      final received = await TransferService.receiveFromQrPayload(payload);
      expect(received.length, 1);
      expect(received.first.title, 'Solo task');
    });

    test('throws FormatException for malformed QR data', () {
      expect(
        () => TransferService.receiveFromQrPayload('not valid json'),
        throwsFormatException,
      );
    });

    test('throws for a payload pointing at an unreachable address', () {
      final payload = jsonEncode({
        'ip': '127.0.0.1',
        'port': 1, // Reserved/unlikely-to-be-listening port.
        'token': 'x',
      });
      expect(
        () => TransferService.receiveFromQrPayload(payload),
        throwsA(anything),
      );
    });
  });
}
