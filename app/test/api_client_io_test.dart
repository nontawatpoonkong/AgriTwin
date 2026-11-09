@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:agritwin_app/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures.dart';

/// Uses a real local server that drops the first connection before sending any header.
/// That is what a poll sees when it goes out on a keep-alive connection the server is closing.
void main() {
  late HttpServer server;
  late int requests;

  setUp(() async {
    requests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      if (requests == 1) {
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
        return;
      }
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(dashboardJson()));
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  String baseUrl() => 'http://${server.address.host}:${server.port}';

  test('dart:io reports the dropped connection as a ClientException', () async {
    final client = http.Client();
    addTearDown(client.close);

    await expectLater(
      client.get(Uri.parse('${baseUrl()}/api/v1/dashboard/latest')),
      throwsA(isA<http.ClientException>()
          .having((e) => e.message, 'message', contains('Connection closed'))),
    );
  });

  test('AgriTwinApi retries the dropped connection and gets the data', () async {
    final api = AgriTwinApi(baseUrl: baseUrl());
    addTearDown(api.close);

    final data = await api.fetchDashboard();

    expect(requests, 2);
    expect(data.devices.single.deviceId, 'sim-node-01');
  });
}
