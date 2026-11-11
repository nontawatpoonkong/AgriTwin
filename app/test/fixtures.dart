import 'package:agritwin_app/data/api_client.dart';
import 'package:agritwin_app/data/models.dart';
import 'package:flutter/foundation.dart';

/// Runs [body] with `debugPrint` writing into the returned list instead of the console, and
/// restores it afterwards (also when [body] throws).
Future<List<String>> withCapturedLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

/// JSON shaped exactly like GET /api/v1/dashboard/latest (captured from the real API).
/// [measuredAt] is the time of both readings.
Map<String, dynamic> dashboardJson({
  String status = 'online',
  String source = 'simulator',
  double soilMoisture = 41.2,
  String quality = 'ok',
  bool withDevice = true,
  String measuredAt = '2026-11-09T13:35:28Z',
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
                'measured_at': measuredAt,
              },
              {
                'sensor_type': 'air_temperature',
                'value': 28.3,
                'unit': '°C',
                'quality': 'ok',
                'source': source,
                'measured_at': measuredAt,
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

/// JSON shaped like GET /api/v1/devices/{id}/readings (BE-1): soil_moisture every 10 minutes
/// from [start] (default 10 Nov 2026 09:00 UTC).
Map<String, dynamic> historyJson({
  List<double> values = const [40.0, 41.5, 43.0],
  String source = 'simulator',
  List<String>? qualities,
  bool truncated = false,
  int limit = 5000,
  DateTime? start,
}) =>
    {
      'device_id': 'sim-node-01',
      'sensor_type': 'soil_moisture',
      'from': '2026-11-09T12:00:00Z',
      'to': null,
      'limit': limit,
      'count': values.length,
      'truncated': truncated,
      'readings': [
        for (var i = 0; i < values.length; i++)
          {
            'sensor_type': 'soil_moisture',
            'value': values[i],
            'unit': '%',
            'quality': qualities?[i] ?? 'ok',
            'source': source,
            'measured_at':
                (start ?? DateTime.utc(2026, 11, 10, 9)).add(Duration(minutes: 10 * i)).toIso8601String(),
          },
      ],
    };

typedef HistoryRequest = ({String deviceId, String sensorType, DateTime from, DateTime? to, int? limit});

class FakeHistorySource implements HistorySource {
  /// [device] is what fetchDeviceLatest returns: by default sim-node-01 from [dashboardJson]
  /// (soil moisture and air temperature, simulator data).
  FakeHistorySource(this.handler, {DeviceLatest? device, this.deviceFails = false})
      : device = device ?? DashboardLatest.fromJson(dashboardJson()).devices.single;

  final Future<ReadingHistory> Function(int call) handler;
  final DeviceLatest device;
  final bool deviceFails;
  final List<HistoryRequest> requests = [];
  int deviceCalls = 0;

  int get calls => requests.length;

  @override
  Future<DeviceLatest> fetchDeviceLatest(String deviceId) async {
    deviceCalls++;
    if (deviceFails) throw const ApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (test)');
    return device;
  }

  @override
  Future<ReadingHistory> fetchHistory({
    required String deviceId,
    required String sensorType,
    required DateTime from,
    DateTime? to,
    int? limit,
  }) {
    requests.add((deviceId: deviceId, sensorType: sensorType, from: from, to: to, limit: limit));
    return handler(requests.length - 1);
  }
}
