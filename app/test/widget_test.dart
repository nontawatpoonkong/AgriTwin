import 'package:agritwin_app/data/api_client.dart';
import 'package:agritwin_app/data/models.dart';
import 'package:agritwin_app/features/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Widget _wrap(DashboardSource source) => MaterialApp(
      home: DashboardPage(source: source, pollInterval: const Duration(seconds: 5)),
    );

void main() {
  testWidgets('shows latest readings, online status and simulated-data badge', (tester) async {
    await tester.pumpWidget(_wrap(FakeSource((_) async => DashboardLatest.fromJson(dashboardJson()))));
    await tester.pump();

    expect(find.text('sim-node-01'), findsOneWidget);
    expect(find.text('ออนไลน์'), findsOneWidget);
    expect(find.text('ข้อมูลจำลอง'), findsOneWidget);
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
    expect(find.text('ออฟไลน์'), findsOneWidget);
    expect(find.text('ค่าผิดปกติ ตรวจสอบเซนเซอร์'), findsOneWidget);
  });

  testWidgets('empty state when no devices', (tester) async {
    await tester.pumpWidget(
      _wrap(FakeSource((_) async => DashboardLatest.fromJson(dashboardJson(withDevice: false)))),
    );
    await tester.pump();
    expect(find.text('ยังไม่มีข้อมูลจากอุปกรณ์'), findsOneWidget);
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
}
