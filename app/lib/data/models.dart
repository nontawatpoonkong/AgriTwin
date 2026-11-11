/// Models for the REST API v1 (see docs/DATA_CONTRACT.md).
///
/// One sensor reading. The dashboard's latest values and the History API use the same JSON shape.
class LatestReading {
  const LatestReading({
    required this.sensorType,
    required this.value,
    required this.unit,
    required this.quality,
    required this.source,
    required this.measuredAt,
  });

  final String sensorType;
  final double value;
  final String unit;

  /// "ok" or "suspect" (value outside the plausible physical range).
  final String quality;

  /// "gateway" = real field data; "simulator" / "test" = not real.
  final String source;
  final DateTime measuredAt;

  bool get isSuspect => quality == 'suspect';
  bool get isSimulated => source != 'gateway';

  factory LatestReading.fromJson(Map<String, dynamic> json) => LatestReading(
        sensorType: json['sensor_type'] as String,
        value: (json['value'] as num).toDouble(),
        unit: json['unit'] as String,
        quality: json['quality'] as String,
        source: json['source'] as String,
        measuredAt: DateTime.parse(json['measured_at'] as String),
      );
}

class DeviceLatest {
  const DeviceLatest({
    required this.deviceId,
    required this.displayName,
    required this.status,
    required this.lastSeenAt,
    required this.lastSource,
    required this.readings,
  });

  final String deviceId;
  final String? displayName;

  /// "online" or "offline" (computed by the server).
  final String status;
  final DateTime lastSeenAt;
  final String lastSource;
  final List<LatestReading> readings;

  bool get isOnline => status == 'online';
  bool get isSimulated => lastSource != 'gateway' || readings.any((r) => r.isSimulated);
  String get title => displayName ?? deviceId;

  factory DeviceLatest.fromJson(Map<String, dynamic> json) => DeviceLatest(
        deviceId: json['device_id'] as String,
        displayName: json['display_name'] as String?,
        status: json['status'] as String,
        lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
        lastSource: json['last_source'] as String,
        readings: (json['readings'] as List<dynamic>)
            .map((e) => LatestReading.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DashboardLatest {
  const DashboardLatest({
    required this.serverTime,
    required this.offlineAfterSeconds,
    required this.devices,
  });

  final DateTime serverTime;
  final int offlineAfterSeconds;
  final List<DeviceLatest> devices;

  factory DashboardLatest.fromJson(Map<String, dynamic> json) => DashboardLatest(
        serverTime: DateTime.parse(json['server_time'] as String),
        offlineAfterSeconds: json['offline_after_seconds'] as int,
        devices: (json['devices'] as List<dynamic>)
            .map((e) => DeviceLatest.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// GET /api/v1/devices/{device_id}/readings (BE-1): readings oldest first.
class ReadingHistory {
  const ReadingHistory({
    required this.deviceId,
    required this.sensorType,
    required this.limit,
    required this.truncated,
    required this.readings,
  });

  final String deviceId;
  final String? sensorType;
  final int limit;

  /// True when the range held more than [limit] readings; [readings] then holds only the newest ones.
  final bool truncated;
  final List<LatestReading> readings;

  bool get isEmpty => readings.isEmpty;
  bool get hasSimulated => readings.any((r) => r.isSimulated);
  int get suspectCount => readings.where((r) => r.isSuspect).length;

  /// This history with the readings of [newer] measured after its newest one appended, and every
  /// reading measured before [since] dropped. Lets a chart keep up by fetching only new readings.
  ReadingHistory extendedWith(ReadingHistory newer, {required DateTime since}) {
    final newest = readings.isEmpty ? null : readings.last.measuredAt;
    return ReadingHistory(
      deviceId: deviceId,
      sensorType: sensorType,
      limit: limit,
      truncated: truncated,
      readings: [
        ...readings,
        ...newer.readings.where((r) => newest == null || r.measuredAt.isAfter(newest)),
      ].where((r) => !r.measuredAt.isBefore(since)).toList(),
    );
  }

  factory ReadingHistory.fromJson(Map<String, dynamic> json) => ReadingHistory(
        deviceId: json['device_id'] as String,
        sensorType: json['sensor_type'] as String?,
        limit: json['limit'] as int,
        truncated: json['truncated'] as bool,
        readings: (json['readings'] as List<dynamic>)
            .map((e) => LatestReading.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
