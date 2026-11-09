import 'dart:convert';

import 'package:agritwin_app/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

void main() {
  test('parses dashboard JSON and decodes UTF-8 units without a charset header', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://api.test/api/v1/dashboard/latest');
      return http.Response.bytes(
        utf8.encode(jsonEncode(dashboardJson())),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = AgriTwinApi(baseUrl: 'http://api.test', client: client);

    final data = await api.fetchDashboard();

    expect(data.devices.single.deviceId, 'sim-node-01');
    expect(data.devices.single.isSimulated, isTrue);
    final temp = data.devices.single.readings.firstWhere((r) => r.sensorType == 'air_temperature');
    expect(temp.unit, '°C');
    expect(temp.value, 28.3);
  });

  test('non-200 becomes ApiException', () async {
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) async => http.Response('boom', 500)),
    );
    await expectLater(api.fetchDashboard(), throwsA(isA<ApiException>()));
  });

  test('payload that breaks the contract becomes ApiException', () async {
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) async => http.Response('{"devices": "nope"}', 200)),
    );
    await expectLater(api.fetchDashboard(), throwsA(isA<ApiException>()));
  });
}
