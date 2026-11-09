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

class AgriTwinApi implements DashboardSource {
  AgriTwinApi({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 8);

  @override
  Future<DashboardLatest> fetchDashboard() async {
    final json = await _getJson('/api/v1/dashboard/latest');
    try {
      return DashboardLatest.fromJson(json);
    } on Object {
      throw const ApiException('ข้อมูลจากเซิร์ฟเวอร์ไม่ตรงกับสัญญา API');
    }
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final res = await _get(Uri.parse('$baseUrl$path'));
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
      return await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('เซิร์ฟเวอร์ไม่ตอบสนอง (หมดเวลา)');
    } on Object catch (e) {
      throw ApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ($e)');
    }
  }

  void close() => _client.close();
}
