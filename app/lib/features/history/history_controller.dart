import 'package:flutter/foundation.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';

/// Time windows offered by the sensor page (design: "24 ชม. / 7 วัน / 30 วัน").
/// Long windows can exceed the History API's 5000-reading limit; the page then says so.
enum HistoryRange {
  day(Duration(hours: 24), '24 ชม.'),
  week(Duration(days: 7), '7 วัน'),
  month(Duration(days: 30), '30 วัน');

  const HistoryRange(this.span, this.label);

  final Duration span;
  final String label;
}

/// Loads one sensor's history for the selected range plus the device's latest values, and keeps
/// the last good data when a refresh fails (stale/offline state). A response that arrives after
/// the range or sensor changed is ignored.
class SensorHistoryController extends ChangeNotifier {
  SensorHistoryController(
    this._source, {
    required this.deviceId,
    required String sensorType,
    DeviceLatest? device,
    DateTime Function()? clock,
  })  : _sensorType = sensorType,
        _device = device,
        _clock = clock ?? DateTime.now;

  final HistorySource _source;
  final String deviceId;
  final DateTime Function() _clock;

  String _sensorType;
  DeviceLatest? _device;

  String get sensorType => _sensorType;

  /// Latest values and status of the device; starts from the dashboard's copy when there is one.
  DeviceLatest? get device => _device;

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
    _clearAndLoad();
  }

  void selectSensor(String next) {
    if (next == _sensorType) return;
    _sensorType = next;
    _clearAndLoad();
  }

  void _clearAndLoad() {
    data = null; // never show one range's or sensor's data under another's label
    error = null;
    load();
  }

  Future<void> load() async {
    if (_disposed) return;
    final request = ++_request;
    loading = true;
    _notify();
    final latest = _deviceQuietly();
    try {
      final result = await _source.fetchHistory(
        deviceId: deviceId,
        sensorType: _sensorType,
        from: _clock().toUtc().subtract(range.span),
      );
      final device = await latest;
      if (request != _request) return;
      data = result;
      if (device != null) _device = device;
      error = null;
      lastSuccessAt = _clock();
    } on Object catch (e, stack) {
      if (request != _request) return;
      error = errorMessageFor(e, stack, where: 'SensorHistoryController');
    } finally {
      if (request == _request) {
        loading = false;
        _notify();
      }
    }
  }

  /// The latest values only refresh the tiles; when they fail the history decides the state.
  Future<DeviceLatest?> _deviceQuietly() async {
    try {
      return await _source.fetchDeviceLatest(deviceId);
    } on Object {
      return null;
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
