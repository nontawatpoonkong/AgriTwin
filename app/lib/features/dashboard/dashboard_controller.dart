import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/config.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';

/// Polls the API and keeps the last good data when a refresh fails (stale/offline state).
class DashboardController extends ChangeNotifier {
  DashboardController(this._source, {this.pollInterval = AppConfig.pollInterval});

  final DashboardSource _source;
  final Duration pollInterval;

  DashboardLatest? data;
  String? error;
  bool loading = false;
  DateTime? lastSuccessAt;

  Timer? _timer;
  bool _disposed = false;

  void start() {
    refresh();
    _timer = Timer.periodic(pollInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    if (loading || _disposed) return;
    loading = true;
    _notify();
    try {
      data = await _source.fetchDashboard();
      error = null;
      lastSuccessAt = DateTime.now();
    } on Object catch (e, stack) {
      error = errorMessageFor(e, stack, where: 'DashboardController');
    } finally {
      loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
