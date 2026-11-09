import 'package:agritwin_app/data/api_client.dart';
import 'package:agritwin_app/data/models.dart';

/// JSON shaped exactly like GET /api/v1/dashboard/latest (captured from the real API).
Map<String, dynamic> dashboardJson({
  String status = 'online',
  String source = 'simulator',
  double soilMoisture = 41.2,
  String quality = 'ok',
  bool withDevice = true,
}) =>
    {
      'server_time': '2026-11-09T13:35:40.208065Z',
      'offline_after_seconds': 180,
      'devices': [
        if (withDevice)
          {
            'device_id': 'sim-node-01',
            'display_name': null,
            'status': status,
            'last_seen_at': '2026-11-09T13:35:28.149075Z',
            'last_source': source,
            'readings': [
              {
                'sensor_type': 'soil_moisture',
                'value': soilMoisture,
                'unit': '%',
                'quality': quality,
                'source': source,
                'measured_at': '2026-11-09T13:35:28Z',
              },
              {
                'sensor_type': 'air_temperature',
                'value': 28.3,
                'unit': '°C',
                'quality': 'ok',
                'source': source,
                'measured_at': '2026-11-09T13:35:28Z',
              },
            ],
          },
      ],
    };

class FakeSource implements DashboardSource {
  FakeSource(this.handler);

  final Future<DashboardLatest> Function(int call) handler;
  int calls = 0;

  @override
  Future<DashboardLatest> fetchDashboard() => handler(calls++);
}
