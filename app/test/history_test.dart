import 'dart:async';
import 'dart:convert';

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
  group('AgriTwinApi.fetchHistory', () {
    test('asks for one sensor from a UTC start time and parses the readings', () async {
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

    test('HTTP errors and contract breaks become ApiException', () async {
      for (final response in [http.Response('{"detail": "nope"}', 404), http.Response('{"readings": 1}', 200)]) {
        final api = AgriTwinApi(baseUrl: 'http://api.test', client: MockClient((_) async => response));
        await expectLater(
          api.fetchHistory(deviceId: 'x', sensorType: 'soil_moisture', from: _now),
          throwsA(isA<ApiException>()),
        );
      }
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
    testWidgets('shows a spinner while loading, then summary, chart and simulated badge', (tester) async {
      final pending = Completer<ReadingHistory>();
      await tester.pumpWidget(_page(FakeHistorySource((_) => pending.future)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(_history());
      await tester.pump();

      expect(find.byType(HistoryChart), findsOneWidget);
      expect(find.text('ข้อมูลจำลอง'), findsOneWidget);
      expect(find.text('ล่าสุด'), findsOneWidget);
      expect(find.text('40.0 %'), findsOneWidget); // lowest
      expect(find.text('43.0 %'), findsNWidgets(2)); // latest and highest
      expect(find.textContaining('3 ค่า'), findsOneWidget);
    });

    testWidgets('real gateway history has no simulated badge', (tester) async {
      await tester.pumpWidget(_page(FakeHistorySource((_) async => _history(source: 'gateway'))));
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

    testWidgets('error state offers a retry', (tester) async {
      final source = FakeHistorySource((call) async {
        if (call == 0) throw const ApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (test)');
        return _history();
      });
      await tester.pumpWidget(_page(source));
      await tester.pump();
      expect(find.text('โหลดข้อมูลย้อนหลังไม่ได้'), findsOneWidget);

      await tester.tap(find.text('ลองใหม่'));
      await tester.pump();
      expect(source.calls, 2);
      expect(find.byType(HistoryChart), findsOneWidget);
    });

    testWidgets('asks for the last 24 hours, then 7 days after switching', (tester) async {
      final source = FakeHistorySource((_) async => _history());
      await tester.pumpWidget(_page(source));
      await tester.pump();

      await tester.tap(find.text('7 วัน'));
      await tester.pump();

      expect(source.requests.map((r) => r.from), [
        _now.subtract(const Duration(hours: 24)),
        _now.subtract(const Duration(days: 7)),
      ]);
      expect(source.requests.every((r) => r.sensorType == 'soil_moisture' && r.deviceId == 'sim-node-01'), isTrue);
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

    testWidgets('keeps the chart and shows a banner when a refresh fails', (tester) async {
      final source = FakeHistorySource((call) async {
        if (call == 0) return _history();
        throw const ApiException('เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)');
      });
      await tester.pumpWidget(_page(source));
      await tester.pump();

      await tester.tap(find.byTooltip('รีเฟรช'));
      await tester.pump();

      expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsOneWidget);
      expect(find.byType(HistoryChart), findsOneWidget);
    });
  });

  testWidgets('tapping a sensor tile on the dashboard opens its history', (tester) async {
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
    expect(history.requests.single.sensorType, 'soil_moisture');
    expect(find.byType(HistoryChart), findsOneWidget);
  });
}
