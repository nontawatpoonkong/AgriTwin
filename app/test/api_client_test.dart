import 'dart:async';
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

  group('redactForLog', () {
    test('masks credentials in URLs and the values of credential-like query parameters', () {
      expect(
        redactForLog(
          'GET https://agritwin:change-me@farm.test/api/v1/x?api_key=change-me&sensor_type=soil_moisture&limit=5000',
        ),
        'GET https://***@farm.test/api/v1/x?api_key=***&sensor_type=soil_moisture&limit=5000',
      );
    });

    test('keeps ordinary text and cuts long text', () {
      const url = 'http://10.0.2.2:8000/api/v1/devices/sim-node-01/readings?sensor_type=soil_moisture&limit=5000';
      expect(redactForLog(url), url);
      expect(redactForLog('x' * 1000), hasLength(301)); // 300 characters and "…"
    });
  });

  test('a user name and password in the API address never reach the log or the exception', () async {
    final api = AgriTwinApi(
      baseUrl: 'http://agritwin:change-me@api.test',
      client: MockClient((request) async => throw http.ClientException('Connection refused', request.url)),
    );
    ApiException? error;
    final logs = await withCapturedLogs(() async {
      try {
        await api.fetchDashboard();
      } on ApiException catch (e) {
        error = e;
      }
    });
    expect(logs.single, contains('GET http://***@api.test/api/v1/dashboard/latest failed'));
    for (final text in [logs.single, error!.detail!]) {
      expect(text, isNot(contains('change-me')));
      expect(text, isNot(contains('agritwin:')));
    }
  });

  test('an error page that is not the API\'s JSON is not copied into the log', () async {
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) async => http.Response(
            '<html><body>Wi-Fi login for the guest in room 1203</body></html>',
            502,
            headers: {'content-type': 'text/html'},
          )),
    );
    final logs = await withCapturedLogs(() async {
      await expectLater(
        api.fetchDashboard(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'เซิร์ฟเวอร์ตอบกลับรหัส 502')),
      );
    });
    expect(logs.single, allOf(contains('HTTP 502'), contains('text/html')));
    expect(logs.single, isNot(contains('room 1203')));
  });

  test('a 200 answer that is not JSON is not copied into the log either', () async {
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) async => http.Response('<html>guest in room 1203</html>', 200)),
    );
    final logs = await withCapturedLogs(() async {
      await expectLater(
        api.fetchDashboard(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'อ่านข้อมูลจากเซิร์ฟเวอร์ไม่ได้')),
      );
    });
    expect(logs.single, contains('FormatException'));
    expect(logs.single, isNot(contains('room 1203')));
  });

  test('an HTTP error keeps the status code in the message and the API\'s error detail in the log', () async {
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) async => http.Response('{"detail": "database unavailable"}', 500)),
    );
    final logs = await withCapturedLogs(() async {
      await expectLater(
        api.fetchDashboard(),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'เซิร์ฟเวอร์ตอบกลับรหัส 500')
            .having((e) => e.detail, 'detail', contains('database unavailable'))),
      );
    });
    expect(logs, [
      allOf(contains('GET http://api.test/api/v1/dashboard/latest failed'), contains('database unavailable')),
    ]);
  });

  test('payload that breaks the contract gives a short message; the parse error is logged', () async {
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) async => http.Response('{"devices": "nope"}', 200)),
    );
    final logs = await withCapturedLogs(() async {
      await expectLater(
        api.fetchDashboard(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'ข้อมูลจากเซิร์ฟเวอร์ไม่ตรงกับสัญญา API')),
      );
    });
    expect(logs.single, contains('GET http://api.test/api/v1/dashboard/latest failed'));
  });

  testWidgets('a server that never answers times out with a short message', (tester) async {
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) => Completer<http.Response>().future),
    );
    Object? error;
    final logs = await withCapturedLogs(() async {
      unawaited(api.fetchDashboard().then<void>((_) {}, onError: (Object e) => error = e));
      await tester.pump(const Duration(seconds: 9)); // past the 8 s timeout
    });
    expect(error, isA<ApiException>().having((e) => e.message, 'message', 'เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)'));
    expect(logs.single, contains('no response within 8 s'));
  });

  test('a dropped connection is retried once and the data still arrives', () async {
    var calls = 0;
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) async {
        calls++;
        if (calls == 1) {
          throw http.ClientException('Connection closed before full header was received');
        }
        return http.Response.bytes(utf8.encode(jsonEncode(dashboardJson())), 200);
      }),
    );

    final data = await api.fetchDashboard();

    expect(calls, 2);
    expect(data.devices.single.deviceId, 'sim-node-01');
  });

  test('a connection that keeps failing gives a short Thai message after one retry; the reason is logged',
      () async {
    var calls = 0;
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        calls++;
        throw http.ClientException('SocketException: Connection refused (OS Error: errno = 111)', request.url);
      }),
    );

    final logs = await withCapturedLogs(() async {
      await expectLater(
        api.fetchDashboard(),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้')
            .having((e) => e.detail, 'detail', contains('Connection refused'))),
      );
    });
    expect(calls, 2);
    expect(logs, hasLength(1)); // one line per failed call, not per attempt
    expect(logs.single, allOf(contains('api/v1/dashboard/latest'), contains('Connection refused')));
  });

  test('an HTTP error status is not retried', () async {
    var calls = 0;
    final api = AgriTwinApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) async {
        calls++;
        return http.Response('boom', 500);
      }),
    );

    await expectLater(api.fetchDashboard(), throwsA(isA<ApiException>()));
    expect(calls, 1);
  });
}
