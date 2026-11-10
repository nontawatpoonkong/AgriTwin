import 'package:agritwin_app/core/theme/app_theme.dart';
import 'package:agritwin_app/data/api_client.dart';
import 'package:agritwin_app/data/models.dart';
import 'package:agritwin_app/features/dashboard/dashboard_page.dart';
import 'package:agritwin_app/features/history/history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

/// The redesigned screens must fit common phone widths without overflow, also with larger text
/// and a long device name. A RenderFlex overflow is reported as a test exception.
void main() {
  const phones = {'small 320x640': Size(320, 640), 'large 412x915': Size(412, 915)};

  Map<String, dynamic> longNameDashboard() {
    final json = dashboardJson(soilMoisture: 140, quality: 'suspect');
    final device = (json['devices'] as List).single as Map<String, dynamic>;
    device['display_name'] = 'แปลงทดลองมันสำปะหลังหนองบัว จุดตรวจวัดที่ 12 (ฝั่งตะวันออก)';
    return json;
  }

  Future<void> pumpOn(WidgetTester tester, Size size, double textScale, Widget home) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: home,
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  for (final phone in phones.entries) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('dashboard fits a ${phone.key} phone at text scale $scale', (tester) async {
        await pumpOn(
          tester,
          phone.value,
          scale,
          DashboardPage(
            source: FakeSource((_) async => DashboardLatest.fromJson(longNameDashboard())),
            historySource: FakeHistorySource((_) async => ReadingHistory.fromJson(historyJson())),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('แปลงทดลองมันสำปะหลัง'), findsWidgets);
      });

      testWidgets('stale banner with a long error fits a ${phone.key} phone at text scale $scale', (tester) async {
        // The real message from an Android emulator when the API is down.
        const longError = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (ClientException with SocketException: Connection refused '
            '(OS Error: Connection refused, errno = 111), address = 10.0.2.2, port = 59478, '
            'uri=http://10.0.2.2:8000/api/v1/dashboard/latest)';
        await pumpOn(
          tester,
          phone.value,
          scale,
          DashboardPage(
            source: FakeSource((call) async {
              if (call == 0) return DashboardLatest.fromJson(longNameDashboard());
              throw const ApiException(longError);
            }),
            historySource: FakeHistorySource((_) async => ReadingHistory.fromJson(historyJson())),
          ),
        );
        await tester.pump(const Duration(seconds: 5)); // the next poll fails
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('กำลังแสดงข้อมูลล่าสุด'), findsOneWidget);
        expect(tester.widget<Text>(find.text(longError)).maxLines, 2); // detail cut, data stays in view
        expect(find.text('อุปกรณ์ออนไลน์'), findsOneWidget); // the summary card is still shown below it
      });

      testWidgets('sensor page fits a ${phone.key} phone at text scale $scale', (tester) async {
        final device = DashboardLatest.fromJson(longNameDashboard()).devices.single;
        await pumpOn(
          tester,
          phone.value,
          scale,
          SensorHistoryPage(
            source: FakeHistorySource(
              (_) async => ReadingHistory.fromJson(historyJson(truncated: true)),
              device: device,
            ),
            deviceId: device.deviceId,
            deviceTitle: device.title,
            sensorType: 'soil_moisture',
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('30 วัน'), findsOneWidget);
      });
    }
  }
}
