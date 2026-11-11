import 'package:agritwin_app/data/api_client.dart';
import 'package:agritwin_app/data/models.dart';
import 'package:agritwin_app/features/dashboard/dashboard_page.dart';
import 'package:agritwin_app/features/dashboard/widgets/device_card.dart';
import 'package:agritwin_app/features/dashboard/widgets/status_hero.dart';
import 'package:agritwin_app/features/dashboard/widgets/trend_card.dart';
import 'package:agritwin_app/features/history/history_page.dart';
import 'package:agritwin_app/features/history/widgets/history_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Widget _wrap(DashboardSource source, {HistorySource? history, DateTime Function()? clock}) => MaterialApp(
      home: DashboardPage(
        source: source,
        historySource: history,
        pollInterval: const Duration(seconds: 5),
        clock: clock,
      ),
    );

Finder _inDevice(Finder matching) => find.descendant(of: find.byType(DeviceCard), matching: matching);
Finder _inSummary(Finder matching) => find.descendant(of: find.byType(StatusHero), matching: matching);
Finder get _trendChart => find.descendant(of: find.byType(TrendCard), matching: find.byType(HistoryChart));
List<LatestReading> _trendReadings(WidgetTester tester) => tester.widget<HistoryChart>(_trendChart).readings;

/// "Now" for the trend tests: the fixture readings (10 Nov 2026 09:00–09:40 UTC) are within 24 hours.
DateTime _noon() => DateTime.utc(2026, 11, 10, 12);

/// The dashboard response with both readings measured at [time] (10 Nov 2026, UTC).
DashboardLatest _latestAt(String time) => DashboardLatest.fromJson(dashboardJson(measuredAt: '2026-11-10T${time}Z'));

/// Lets one 5-second dashboard poll run, and whatever it starts finish.
Future<void> _nextPoll(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows latest readings, online status and simulated-data badge', (tester) async {
    await tester.pumpWidget(_wrap(FakeSource((_) async => DashboardLatest.fromJson(dashboardJson()))));
    await tester.pump();

    expect(find.text('sim-node-01'), findsOneWidget);
    expect(_inDevice(find.text('ออนไลน์')), findsOneWidget);
    expect(_inDevice(find.text('ข้อมูลจำลอง')), findsOneWidget);
    expect(_inSummary(find.text('ข้อมูลจำลอง')), findsOneWidget);
    expect(find.text('ความชื้นดิน'), findsOneWidget);
    expect(find.textContaining('41.2'), findsOneWidget);
    expect(find.textContaining('°C'), findsOneWidget);
    expect(find.text('อัปเดตล่าสุด 12 วินาทีที่แล้ว'), findsOneWidget);
  });

  testWidgets('real gateway data has no simulated badge', (tester) async {
    await tester.pumpWidget(
      _wrap(FakeSource((_) async => DashboardLatest.fromJson(dashboardJson(source: 'gateway')))),
    );
    await tester.pump();
    expect(find.text('ข้อมูลจำลอง'), findsNothing);
  });

  testWidgets('offline device and suspect value are shown', (tester) async {
    await tester.pumpWidget(_wrap(FakeSource(
      (_) async => DashboardLatest.fromJson(
        dashboardJson(status: 'offline', soilMoisture: 140, quality: 'suspect'),
      ),
    )));
    await tester.pump();
    expect(_inDevice(find.text('ออฟไลน์')), findsOneWidget);
    expect(find.text('ค่าผิดปกติ ตรวจสอบเซนเซอร์'), findsOneWidget);
  });

  testWidgets('summary card counts devices, offline devices and suspect values', (tester) async {
    await tester.pumpWidget(_wrap(FakeSource(
      (_) async => DashboardLatest.fromJson(
        dashboardJson(status: 'offline', soilMoisture: 140, quality: 'suspect'),
      ),
    )));
    await tester.pump();
    expect(_inSummary(find.text('0/1')), findsOneWidget);
    expect(_inSummary(find.text('อุปกรณ์ออนไลน์')), findsOneWidget);
    expect(_inSummary(find.text('1 ค่า')), findsOneWidget);
    expect(find.textContaining('ภาพรวมฟาร์มวันนี้'), findsOneWidget);
  });

  testWidgets('empty state when no devices', (tester) async {
    await tester.pumpWidget(
      _wrap(FakeSource((_) async => DashboardLatest.fromJson(dashboardJson(withDevice: false)))),
    );
    await tester.pump();
    expect(find.text('ยังไม่มีข้อมูลจากอุปกรณ์'), findsOneWidget);
    expect(find.byType(StatusHero), findsNothing);
  });

  testWidgets('first-load error shows the short reason only, and retry brings the data', (tester) async {
    final source = FakeSource((call) async {
      if (call == 0) {
        throw const ApiException(
          'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้',
          detail: 'ClientException with SocketException: Connection refused (OS Error: Connection refused, '
              'errno = 111), uri=http://10.0.2.2:8000/api/v1/dashboard/latest',
        );
      }
      return DashboardLatest.fromJson(dashboardJson());
    });
    await tester.pumpWidget(_wrap(source));
    await tester.pump();
    expect(find.text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.textContaining('errno'), findsNothing);

    await tester.tap(find.text('ลองใหม่'));
    await tester.pump();
    expect(source.calls, 2);
    expect(find.textContaining('41.2'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsNothing);
  });

  testWidgets('an unexpected error shows a generic Thai message; the details go to the log', (tester) async {
    final logs = await withCapturedLogs(() async {
      await tester.pumpWidget(_wrap(FakeSource((_) async => throw StateError('parser exploded'))));
      await tester.pump();
    });
    expect(find.text(unexpectedErrorMessage), findsOneWidget);
    expect(find.textContaining('parser exploded'), findsNothing);
    expect(logs.join('\n'), allOf(contains('DashboardController'), contains('parser exploded')));
  });

  testWidgets('keeps last data and shows the reason in a banner when a later poll fails', (tester) async {
    final source = FakeSource((call) async {
      if (call == 0) return DashboardLatest.fromJson(dashboardJson());
      throw const ApiException('เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)', detail: 'no response within 8 s');
    });
    await tester.pumpWidget(_wrap(source));
    await tester.pump();
    expect(find.textContaining('41.2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5)); // next poll
    await tester.pump();
    expect(find.text('เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)'), findsOneWidget);
    expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsOneWidget);
    expect(find.textContaining('no response'), findsNothing);
    expect(find.textContaining('41.2'), findsOneWidget);
  });

  testWidgets('the banner goes away and new values show when a later poll succeeds', (tester) async {
    final source = FakeSource((call) async {
      if (call == 1) throw const ApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
      return DashboardLatest.fromJson(dashboardJson(soilMoisture: call == 0 ? 41.2 : 39.6));
    });
    await tester.pumpWidget(_wrap(source));
    await tester.pump();
    await _nextPoll(tester); // fails
    expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsOneWidget);

    await _nextPoll(tester); // succeeds
    expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsNothing);
    expect(find.textContaining('39.6'), findsOneWidget);
    expect(find.textContaining('41.2'), findsNothing);
  });

  testWidgets('trend card loads 24 hours, skips polls that bring nothing new, and opens the sensor page',
      (tester) async {
    final history = FakeHistorySource((_) async => ReadingHistory.fromJson(historyJson()));
    await tester.pumpWidget(_wrap(
      FakeSource((_) async => DashboardLatest.fromJson(dashboardJson())),
      history: history,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('ความชื้นดิน · 24 ชม. · sim-node-01'), findsOneWidget);
    expect(find.descendant(of: find.byType(TrendCard), matching: find.byType(HistoryChart)), findsOneWidget);
    expect(history.requests.single.sensorType, 'soil_moisture');

    await tester.pump(const Duration(seconds: 5)); // dashboard poll
    await tester.pump();
    expect(history.calls, 1);

    await tester.tap(find.text('ดูทั้งหมด'));
    await tester.pumpAndSettle();
    expect(find.byType(SensorHistoryPage), findsOneWidget);
  });

  testWidgets('trend card keeps its chart, without reloading, when a later poll fails', (tester) async {
    final history = FakeHistorySource((_) async => ReadingHistory.fromJson(historyJson()));
    await tester.pumpWidget(_wrap(
      FakeSource((call) async {
        if (call == 0) return DashboardLatest.fromJson(dashboardJson());
        throw const ApiException('เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)');
      }),
      history: history,
    ));
    await tester.pump();
    await tester.pump();
    expect(find.descendant(of: find.byType(TrendCard), matching: find.byType(HistoryChart)), findsOneWidget);

    await tester.pump(const Duration(seconds: 5)); // the poll fails and the banner appears above the cards
    await tester.pump();
    expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsOneWidget);
    expect(find.descendant(of: find.byType(TrendCard), matching: find.byType(HistoryChart)), findsOneWidget);
    expect(history.calls, 1);
  });

  testWidgets('trend card fetches only the readings after its newest point when a poll brings a newer one',
      (tester) async {
    final history = FakeHistorySource((call) async => call == 0
        ? ReadingHistory.fromJson(historyJson()) // 09:00, 09:10, 09:20
        : ReadingHistory.fromJson(historyJson(values: [43.0, 44.5], start: DateTime.utc(2026, 11, 10, 9, 20))));
    final source = FakeSource((call) async => _latestAt(call == 0 ? '09:20:00' : '09:30:00'));
    await tester.pumpWidget(_wrap(source, history: history, clock: _noon));
    await tester.pump();
    await tester.pump();
    expect(_trendReadings(tester).map((r) => r.value), [40.0, 41.5, 43.0]);

    await _nextPoll(tester); // the dashboard now has 09:30
    expect(history.calls, 2);
    expect(history.requests.last.from, DateTime.utc(2026, 11, 10, 9, 20)); // from the chart's newest point
    expect(_trendReadings(tester).map((r) => r.value), [40.0, 41.5, 43.0, 44.5]); // 09:20 not doubled

    await _nextPoll(tester); // still 09:30: nothing to fetch
    expect(history.calls, 2);
  });

  testWidgets('trend card keeps its last chart and says so when catching up fails', (tester) async {
    final history = FakeHistorySource((call) async {
      if (call == 0) return ReadingHistory.fromJson(historyJson());
      throw const ApiException('เซิร์ฟเวอร์ตอบกลับรหัส 500');
    });
    final source = FakeSource((call) async => _latestAt(call == 0 ? '09:20:00' : '09:30:00'));
    await tester.pumpWidget(_wrap(source, history: history, clock: _noon));
    await tester.pump();
    await tester.pump();

    await _nextPoll(tester);
    expect(history.calls, 2);
    expect(_trendReadings(tester).map((r) => r.value), [40.0, 41.5, 43.0]);
    expect(find.textContaining('อัปเดตกราฟไม่ได้'), findsOneWidget);
  });

  testWidgets('trend card makes no request while polls fail, then catches up when the API is back',
      (tester) async {
    final history = FakeHistorySource((call) async => call == 0
        ? ReadingHistory.fromJson(historyJson())
        : ReadingHistory.fromJson(historyJson(values: [43.0, 44.0, 45.0], start: DateTime.utc(2026, 11, 10, 9, 20))));
    final source = FakeSource((call) async {
      if (call == 1 || call == 2) throw const ApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
      return _latestAt(call == 0 ? '09:20:00' : '09:40:00');
    });
    await tester.pumpWidget(_wrap(source, history: history, clock: _noon));
    await tester.pump();
    await tester.pump();

    await _nextPoll(tester); // fails
    await _nextPoll(tester); // fails
    expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsOneWidget);
    expect(history.calls, 1);
    expect(_trendReadings(tester), hasLength(3)); // the last good chart stays

    await _nextPoll(tester); // the API is back with 09:40
    expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsNothing);
    expect(history.requests.last.from, DateTime.utc(2026, 11, 10, 9, 20)); // fills the gap
    expect(_trendReadings(tester).map((r) => r.value), [40.0, 41.5, 43.0, 44.0, 45.0]);
    expect(find.textContaining('อัปเดตกราฟไม่ได้'), findsNothing);
  });
}
