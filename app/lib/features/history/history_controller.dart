import 'package:flutter/foundation.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';

/// Time windows offered by the history chart (APP-1).
enum HistoryRange {
  day(Duration(hours: 24), '24 ชม.'),
  week(Duration(days: 7), '7 วัน');

  const HistoryRange(this.span, this.label);

  final Duration span;
  final String label;
}

/// Loads one sensor's history for the selected range and keeps the last good data when a refresh
/// fails (stale/offline state). A response that arrives after the range changed is ignored.
class SensorHistoryController extends ChangeNotifier {
  SensorHistoryController(
    this._source, {
    required this.deviceId,
    required this.sensorType,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final HistorySource _source;
  final String deviceId;
  final String sensorType;
  final DateTime Function() _clock;

  HistoryRange range = HistoryRange.day;
  ReadingHistory? data;
  String? error;
  bool loading = false;
  DateTime? lastSuccessAt;

  int _request = 0;
  bool _disposed = false;

  void selectRange(HistoryRange next) {
    if (next == range) return;
    range = next;
    data = null; // never show one range's data under another range's label
    error = null;
    load();
  }

  Future<void> load() async {
    if (_disposed) return;
    final request = ++_request;
    loading = true;
    _notify();
    try {
      final result = await _source.fetchHistory(
        deviceId: deviceId,
        sensorType: sensorType,
        from: _clock().toUtc().subtract(range.span),
      );
      if (request != _request) return;
      data = result;
      error = null;
      lastSuccessAt = _clock();
    } on ApiException catch (e) {
      if (request != _request) return;
      error = e.message;
    } on Object catch (e) {
      if (request != _request) return;
      error = 'เกิดข้อผิดพลาด: $e';
    } finally {
      if (request == _request) {
        loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
