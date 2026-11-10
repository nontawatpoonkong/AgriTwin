import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What the dashboard needs. Tests provide a fake implementation.
abstract class DashboardSource {
  Future<DashboardLatest> fetchDashboard();
}

/// What the sensor page needs: history (BE-1 History API) and one device's latest values.
/// Tests provide a fake implementation.
abstract class HistorySource {
  /// Readings of [sensorType] on [deviceId] measured at or after [from] (and before [to] if given),
  /// oldest first. [limit] defaults to the largest page the API accepts.
  Future<ReadingHistory> fetchHistory({
    required String deviceId,
    required String sensorType,
    required DateTime from,
    DateTime? to,
    int? limit,
  });

  /// Status and latest value per sensor of one device (GET /api/v1/devices/{id}/latest).
  Future<DeviceLatest> fetchDeviceLatest(String deviceId);
}

class AgriTwinApi implements DashboardSource, HistorySource {
  AgriTwinApi({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 8);

  /// Largest page the History API accepts (docs/DATA_CONTRACT.md).
  static const int maxHistoryLimit = 5000;

  @override
  Future<DashboardLatest> fetchDashboard() async {
    final json = await _getJson(Uri.parse('$baseUrl/api/v1/dashboard/latest'));
    try {
      return DashboardLatest.fromJson(json);
    } on Object {
      throw const ApiException('ข้อมูลจากเซิร์ฟเวอร์ไม่ตรงกับสัญญา API');
    }
  }

  @override
  Future<ReadingHistory> fetchHistory({
    required String deviceId,
    required String sensorType,
    required DateTime from,
    DateTime? to,
    int? limit,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/devices/${Uri.encodeComponent(deviceId)}/readings').replace(
      queryParameters: {
        'sensor_type': sensorType,
        'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        'limit': '${limit ?? maxHistoryLimit}',
      },
    );
    final json = await _getJson(uri);
    try {
      return ReadingHistory.fromJson(json);
    } on Object {
      throw const ApiException('ข้อมูลจากเซิร์ฟเวอร์ไม่ตรงกับสัญญา API');
    }
  }

  @override
  Future<DeviceLatest> fetchDeviceLatest(String deviceId) async {
    final json = await _getJson(Uri.parse('$baseUrl/api/v1/devices/${Uri.encodeComponent(deviceId)}/latest'));
    try {
      return DeviceLatest.fromJson(json);
    } on Object {
      throw const ApiException('ข้อมูลจากเซิร์ฟเวอร์ไม่ตรงกับสัญญา API');
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw ApiException('เซิร์ฟเวอร์ตอบกลับรหัส ${res.statusCode}');
    }
    try {
      // Decode bytes as UTF-8 explicitly: the server sends "°C" and may omit the charset.
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on Object {
      throw const ApiException('อ่านข้อมูลจากเซิร์ฟเวอร์ไม่ได้');
    }
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _getRetryingOnce(uri);
    } on TimeoutException {
      throw const ApiException('เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)');
    } on Object catch (e) {
      throw ApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ($e)');
    }
  }

  /// GET is idempotent, so one connection-level failure is retried on a new connection.
  ///
  /// The app polls every 5 s and uvicorn closes idle keep-alive connections after 5 s, so a
  /// poll can go out on a connection the server is closing ("Connection closed before full
  /// header was received"). Browsers retry this case on their own; dart:io (Android, desktop)
  /// does not. Timeouts and HTTP error statuses are not retried.
  Future<http.Response> _getRetryingOnce(Uri uri) async {
    try {
      return await _client.get(uri).timeout(_timeout);
    } on http.ClientException {
      return await _client.get(uri).timeout(_timeout);
    }
  }

  void close() => _client.close();
}
