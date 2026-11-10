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

Widget _wrap(DashboardSource source, {HistorySource? history}) => MaterialApp(
      home: DashboardPage(
        source: source,
        historySource: history,
        pollInterval: const Duration(seconds: 5),
      ),
    );

Finder _inDevice(Finder matching) => find.descendant(of: find.byType(DeviceCard), matching: matching);
Finder _inSummary(Finder matching) => find.descendant(of: find.byType(StatusHero), matching: matching);

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

  testWidgets('error state with retry when the first load fails', (tester) async {
    final source = FakeSource((_) async => throw const ApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (test)'));
    await tester.pumpWidget(_wrap(source));
    await tester.pump();
    expect(find.text('ลองใหม่'), findsOneWidget);

    await tester.tap(find.text('ลองใหม่'));
    await tester.pump();
    expect(source.calls, 2);
  });

  testWidgets('keeps last data and shows a banner when a later poll fails', (tester) async {
    final source = FakeSource((call) async {
      if (call == 0) return DashboardLatest.fromJson(dashboardJson());
      throw const ApiException('เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)');
    });
    await tester.pumpWidget(_wrap(source));
    await tester.pump();
    expect(find.textContaining('41.2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5)); // next poll
    await tester.pump();
    expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsOneWidget);
    expect(find.textContaining('41.2'), findsOneWidget);
  });

  testWidgets('trend card loads 24 hours once, not on every poll, and opens the sensor page', (tester) async {
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
}
