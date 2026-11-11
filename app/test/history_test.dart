import 'dart:async';
import 'dart:convert';

import 'package:agritwin_app/core/format.dart';
import 'package:agritwin_app/data/api_client.dart';
import 'package:agritwin_app/data/models.dart';
import 'package:agritwin_app/features/dashboard/dashboard_page.dart';
import 'package:agritwin_app/features/history/history_page.dart';
import 'package:agritwin_app/features/history/widgets/history_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

final _now = DateTime.utc(2026, 11, 10, 12);

ReadingHistory _history({
  List<double> values = const [40.0, 41.5, 43.0],
  String source = 'simulator',
  List<String>? qualities,
  bool truncated = false,
}) =>
    ReadingHistory.fromJson(
      historyJson(values: values, source: source, qualities: qualities, truncated: truncated),
    );

DeviceLatest _gatewayDevice() => DashboardLatest.fromJson(dashboardJson(source: 'gateway')).devices.single;

Widget _page(HistorySource source) => MaterialApp(
      home: SensorHistoryPage(
        source: source,
        deviceId: 'sim-node-01',
        deviceTitle: 'sim-node-01',
        sensorType: 'soil_moisture',
        clock: () => _now,
      ),
    );

LatestReading _reading(int minute, {double value = 40}) => LatestReading(
      sensorType: 'soil_moisture',
      value: value,
      unit: '%',
      quality: 'ok',
      source: 'simulator',
      measuredAt: DateTime.utc(2026, 11, 10, 9).add(Duration(minutes: minute)),
    );

void main() {
  group('AgriTwinApi', () {
    test('fetchHistory asks for one sensor from a UTC start time and parses the readings', () async {
      late Uri asked;
      final api = AgriTwinApi(
        baseUrl: 'http://api.test',
        client: MockClient((request) async {
          asked = request.url;
          return http.Response.bytes(utf8.encode(jsonEncode(historyJson())), 200);
        }),
      );

      final history = await api.fetchHistory(
        deviceId: 'sim-node-01',
        sensorType: 'soil_moisture',
        from: DateTime.utc(2026, 11, 9, 12),
      );

      expect(asked.path, '/api/v1/devices/sim-node-01/readings');
      expect(asked.queryParameters, {
        'sensor_type': 'soil_moisture',
        'from': '2026-11-09T12:00:00.000Z',
        'limit': '5000',
      });
      expect(history.readings.map((r) => r.value), [40.0, 41.5, 43.0]);
      expect(history.truncated, isFalse);
      expect(history.hasSimulated, isTrue);
    });

    test('fetchDeviceLatest reads the existing latest endpoint', () async {
      late Uri asked;
      final device = (dashboardJson()['devices'] as List).single as Map<String, dynamic>;
      final api = AgriTwinApi(
        baseUrl: 'http://api.test',
        client: MockClient((request) async {
          asked = request.url;
          return http.Response.bytes(utf8.encode(jsonEncode(device)), 200);
        }),
      );

      final latest = await api.fetchDeviceLatest('sim-node-01');

      expect(asked.path, '/api/v1/devices/sim-node-01/latest');
      expect(latest.readings.length, 2);
      expect(latest.isOnline, isTrue);
    });

    test('HTTP errors and contract breaks become ApiException', () async {
      for (final response in [http.Response('{"detail": "nope"}', 404), http.Response('{"readings": 1}', 200)]) {
        final api = AgriTwinApi(baseUrl: 'http://api.test', client: MockClient((_) async => response));
        await expectLater(
          api.fetchHistory(deviceId: 'x', sensorType: 'soil_moisture', from: _now),
          throwsA(isA<ApiException>()),
        );
        await expectLater(api.fetchDeviceLatest('x'), throwsA(isA<ApiException>()));
      }
    });
  });

  group('ReadingHistory.extendedWith', () {
    test('appends only readings after the newest one and drops those before the window', () {
      final newer = ReadingHistory.fromJson(
        historyJson(values: [43.0, 44.0, 45.5], start: DateTime.utc(2026, 11, 10, 9, 20)), // 09:20 again, 09:30, 09:40
      );
      final merged = _history().extendedWith(newer, since: DateTime.utc(2026, 11, 10, 9, 5));

      expect(merged.readings.map((r) => r.measuredAt), [
        for (final m in [10, 20, 30, 40]) DateTime.utc(2026, 11, 10, 9, m),
      ]);
      expect(merged.readings.map((r) => r.value), [41.5, 43.0, 44.0, 45.5]);
      expect(merged.deviceId, 'sim-node-01');
    });

    test('an empty history takes every newer reading in the window', () {
      final merged = _history(values: []).extendedWith(_history(), since: DateTime.utc(2026, 11, 9));
      expect(merged.readings.map((r) => r.value), [40.0, 41.5, 43.0]);
    });
  });

  group('splitAtGaps', () {
    test('breaks the line where data is missing for much longer than usual', () {
      final readings = [for (final m in [0, 10, 20, 200, 210]) _reading(m)];
      expect(splitAtGaps(readings).map((s) => s.length), [3, 2]);
    });

    test('keeps a steady series in one piece', () {
      expect(splitAtGaps([for (final m in [0, 10, 20, 30]) _reading(m)]).length, 1);
      expect(splitAtGaps([_reading(0)]).single.length, 1);
      expect(splitAtGaps(const []), isEmpty);
    });
  });

  group('SensorHistoryPage', () {
    testWidgets('shows a spinner while loading, then value, range, chart and simulated badge', (tester) async {
      final pending = Completer<ReadingHistory>();
      await tester.pumpWidget(_page(FakeHistorySource((_) => pending.future)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(_history());
      await tester.pump();

      expect(find.byType(HistoryChart), findsOneWidget);
      expect(find.text('ความชื้นดิน (Soil Moisture)'), findsOneWidget);
      expect(find.text('43.0 %'), findsOneWidget); // newest value
      expect(find.text('ต่ำสุด 40.0 % · สูงสุด 43.0 %'), findsOneWidget);
      expect(find.textContaining('3 ค่า'), findsOneWidget);
      expect(find.text('ข้อมูลจำลอง'), findsWidgets);
    });

    testWidgets('shows the device status, data source and latest values', (tester) async {
      await tester.pumpWidget(_page(FakeHistorySource((_) async => _history())));
      await tester.pump();

      expect(find.text('ออนไลน์'), findsOneWidget);
      expect(find.text('Simulator'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('อุณหภูมิอากาศ'), 200); // the grid sits below the chart
      expect(find.text('ค่าล่าสุดจาก sim-node-01'), findsOneWidget);
      expect(find.text('อุณหภูมิอากาศ'), findsOneWidget);
    });

    testWidgets('a last-seen time from an earlier day shows its date', (tester) async {
      final json = dashboardJson();
      final raw = (json['devices'] as List).single as Map<String, dynamic>;
      raw['last_seen_at'] = '2026-11-08T12:00:00Z'; // two days before the clock, in any time zone
      final device = DashboardLatest.fromJson(json).devices.single;
      await tester.pumpWidget(_page(FakeHistorySource((_) async => _history(), device: device)));
      await tester.pump();
      expect(find.text('อัปเดต ${formatDayTime(device.lastSeenAt)} น.'), findsOneWidget);
    });

    testWidgets('real gateway data has no simulated badge', (tester) async {
      await tester.pumpWidget(
        _page(FakeHistorySource((_) async => _history(source: 'gateway'), device: _gatewayDevice())),
      );
      await tester.pump();
      expect(find.byType(HistoryChart), findsOneWidget);
      expect(find.text('ข้อมูลจำลอง'), findsNothing);
    });

    testWidgets('a single reading still draws', (tester) async {
      await tester.pumpWidget(_page(FakeHistorySource((_) async => _history(values: [42.0]))));
      await tester.pump();
      expect(find.byType(HistoryChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty range says there is no data', (tester) async {
      await tester.pumpWidget(_page(FakeHistorySource((_) async => _history(values: []))));
      await tester.pump();
      expect(find.text('ไม่มีข้อมูลในช่วง 24 ชม. ล่าสุด'), findsOneWidget);
      expect(find.byType(HistoryChart), findsNothing);
    });

    testWidgets('error state shows the short reason only and offers a retry', (tester) async {
      final source = FakeHistorySource((call) async {
        if (call == 0) {
          throw const ApiException(
            'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้',
            detail: 'ClientException with SocketException: Connection refused, '
                'uri=http://10.0.2.2:8000/api/v1/devices/sim-node-01/readings?sensor_type=soil_moisture',
          );
        }
        return _history();
      }, deviceFails: true);
      await tester.pumpWidget(_page(source));
      await tester.pump();
      expect(find.text('โหลดข้อมูลย้อนหลังไม่ได้'), findsOneWidget);
      expect(find.text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('sensor_type='), findsNothing);

      await tester.tap(find.text('ลองใหม่'));
      await tester.pump();
      expect(source.calls, 2);
      expect(find.byType(HistoryChart), findsOneWidget);
    });

    testWidgets('asks for the last 24 hours, 7 days and 30 days', (tester) async {
      final source = FakeHistorySource((_) async => _history());
      await tester.pumpWidget(_page(source));
      await tester.pump();

      await tester.tap(find.text('7 วัน'));
      await tester.pump();
      await tester.tap(find.text('30 วัน'));
      await tester.pump();

      expect(source.requests.map((r) => r.from), [
        _now.subtract(const Duration(hours: 24)),
        _now.subtract(const Duration(days: 7)),
        _now.subtract(const Duration(days: 30)),
      ]);
      expect(source.requests.every((r) => r.sensorType == 'soil_moisture' && r.deviceId == 'sim-node-01'), isTrue);
    });

    testWidgets('tapping a latest value switches the chart to that sensor', (tester) async {
      final source = FakeHistorySource((_) async => _history());
      await tester.pumpWidget(_page(source));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('อุณหภูมิอากาศ'), 200); // the grid sits below the chart
      await tester.tap(find.text('อุณหภูมิอากาศ'));
      await tester.pump();

      expect(source.requests.last.sensorType, 'air_temperature');
      await tester.scrollUntilVisible(find.text('อุณหภูมิอากาศ (Air Temperature)'), -200);
      expect(find.text('อุณหภูมิอากาศ (Air Temperature)'), findsOneWidget);
    });

    testWidgets('a late answer for the old range does not replace the new one', (tester) async {
      final day = Completer<ReadingHistory>();
      final source = FakeHistorySource((call) => call == 0 ? day.future : Future.value(_history(values: [])));
      await tester.pumpWidget(_page(source));
      await tester.tap(find.text('7 วัน'));
      await tester.pump();
      expect(find.text('ไม่มีข้อมูลในช่วง 7 วัน ล่าสุด'), findsOneWidget);

      day.complete(_history());
      await tester.pump();
      expect(find.text('ไม่มีข้อมูลในช่วง 7 วัน ล่าสุด'), findsOneWidget);
      expect(find.byType(HistoryChart), findsNothing);
    });

    testWidgets('truncated history says only the newest readings are shown', (tester) async {
      await tester.pumpWidget(_page(FakeHistorySource((_) async => _history(truncated: true))));
      await tester.pump();
      expect(find.text('ช่วงนี้มีข้อมูลมากกว่า 5000 ค่า จึงแสดงเฉพาะ 3 ค่าล่าสุด'), findsOneWidget);
    });

    testWidgets('suspect values are counted', (tester) async {
      await tester.pumpWidget(
        _page(FakeHistorySource((_) async => _history(qualities: ['ok', 'suspect', 'ok']))),
      );
      await tester.pump();
      expect(find.text('มีค่าผิดปกติ 1 ค่า ทำเครื่องหมายไว้ในกราฟ'), findsOneWidget);
    });

    testWidgets('keeps the chart and shows the reason in a banner when a refresh fails', (tester) async {
      final source = FakeHistorySource((call) async {
        if (call == 0) return _history();
        throw const ApiException('เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)', detail: 'no response within 8 s');
      });
      await tester.pumpWidget(_page(source));
      await tester.pump();

      await tester.tap(find.byTooltip('รีเฟรช'));
      await tester.pump();

      expect(find.text('เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)'), findsOneWidget);
      expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsOneWidget);
      expect(find.textContaining('no response'), findsNothing);
      expect(find.byType(HistoryChart), findsOneWidget);
    });

    testWidgets('an unexpected error shows a generic Thai message; the details go to the log', (tester) async {
      final logs = await withCapturedLogs(() async {
        await tester.pumpWidget(_page(FakeHistorySource((_) async => throw const FormatException('bad number'))));
        await tester.pump();
      });
      expect(find.text(unexpectedErrorMessage), findsOneWidget);
      expect(find.textContaining('bad number'), findsNothing);
      expect(logs.join('\n'), allOf(contains('SensorHistoryController'), contains('bad number')));
    });
  });

  testWidgets('tapping a sensor card on the dashboard opens its sensor page', (tester) async {
    final history = FakeHistorySource((_) async => _history());
    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(
        source: FakeSource((_) async => DashboardLatest.fromJson(dashboardJson())),
        historySource: history,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('ความชื้นดิน'));
    await tester.pumpAndSettle();

    expect(find.byType(SensorHistoryPage), findsOneWidget);
    expect(history.requests.last.sensorType, 'soil_moisture');
    expect(find.byType(HistoryChart), findsOneWidget);
  });
}
