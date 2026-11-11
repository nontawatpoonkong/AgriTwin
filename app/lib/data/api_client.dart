import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// A failed API call. [message] is short Thai text for the screen; [detail] keeps the technical
/// reason (exception text, HTTP status, body) for the log and is never shown to the user.
class ApiException implements Exception {
  const ApiException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => message;
}

/// Shown when something other than an [ApiException] goes wrong while loading data.
const unexpectedErrorMessage = 'เกิดข้อผิดพลาดที่ไม่คาดคิด';

/// Short Thai text to show for [error]. Anything that is not an [ApiException] is written to the
/// log with its stack trace and shown as [unexpectedErrorMessage], so no technical text reaches
/// the screen. [where] names the caller in the log.
String errorMessageFor(Object error, StackTrace stack, {required String where}) {
  if (error is ApiException) return error.message;
  debugPrint('$where: unexpected error: $error\n$stack');
  return unexpectedErrorMessage;
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
    final uri = Uri.parse('$baseUrl/api/v1/dashboard/latest');
    return _parse(uri, await _getJson(uri), DashboardLatest.fromJson);
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
    return _parse(uri, await _getJson(uri), ReadingHistory.fromJson);
  }

  @override
  Future<DeviceLatest> fetchDeviceLatest(String deviceId) async {
    final uri = Uri.parse('$baseUrl/api/v1/devices/${Uri.encodeComponent(deviceId)}/latest');
    return _parse(uri, await _getJson(uri), DeviceLatest.fromJson);
  }

  T _parse<T>(Uri uri, Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    try {
      return fromJson(json);
    } on Object catch (e) {
      throw _failure(uri, 'ข้อมูลจากเซิร์ฟเวอร์ไม่ตรงกับสัญญา API', '$e');
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final res = await _get(uri);
    if (res.statusCode != 200) {
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      throw _failure(
        uri,
        'เซิร์ฟเวอร์ตอบกลับรหัส ${res.statusCode}',
        'HTTP ${res.statusCode}: ${body.length > 300 ? '${body.substring(0, 300)}…' : body}',
      );
    }
    try {
      // Decode bytes as UTF-8 explicitly: the server sends "°C" and may omit the charset.
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on Object catch (e) {
      throw _failure(uri, 'อ่านข้อมูลจากเซิร์ฟเวอร์ไม่ได้', '$e');
    }
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _getRetryingOnce(uri);
    } on TimeoutException {
      throw _failure(uri, 'เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)', 'no response within ${_timeout.inSeconds} s');
    } on Object catch (e) {
      throw _failure(uri, 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้', '$e');
    }
  }

  /// Logs the technical reason of a failed call (console of `flutter run`, or `adb logcat -s flutter`
  /// on Android) and returns the exception whose short [message] the screens show.
  ApiException _failure(Uri uri, String message, String detail) {
    debugPrint('AgriTwinApi: GET $uri failed: $detail');
    return ApiException(message, detail: detail);
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
