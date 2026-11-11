import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/sensor_catalog.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../../core/widgets/ui_parts.dart';
import '../../../data/api_client.dart';
import '../../../data/models.dart';
import '../../history/widgets/history_chart.dart';

/// "sensor · 24 ชม." card on the dashboard (design: TrendCard). Tapping it opens the sensor page.
///
/// Loads the last 24 hours of one sensor from the History API, then keeps up with the dashboard
/// polls: when [device] carries a reading of the sensor newer than the chart covers, only the
/// readings after the chart's newest point are fetched and appended (anything older than 24 hours
/// is dropped). Polls that bring nothing new, or that fail, cost no request. A failed refresh keeps
/// the last chart and says so under it. [reloadToken] (pull to refresh) loads the 24 hours again.
class TrendCard extends StatefulWidget {
  const TrendCard({
    super.key,
    required this.source,
    required this.device,
    required this.sensorType,
    required this.reloadToken,
    required this.onOpen,
    this.clock,
  });

  final HistorySource source;
  final DeviceLatest device;
  final String sensorType;
  final int reloadToken;
  final VoidCallback onOpen;
  final DateTime Function()? clock;

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  static const _window = Duration(hours: 24);

  ReadingHistory? _data;
  String? _error;
  int _request = 0;
  bool _busy = false;

  /// Measured time of the dashboard's newest reading of this sensor when the chart was last
  /// loaded: a later one means the chart is behind. Server timestamps only, so the phone's clock
  /// does not matter here.
  DateTime? _covered;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  DateTime? get _latestOnDashboard {
    for (final r in widget.device.readings) {
      if (r.sensorType == widget.sensorType) return r.measuredAt;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TrendCard old) {
    super.didUpdateWidget(old);
    if (old.device.deviceId != widget.device.deviceId || old.sensorType != widget.sensorType) {
      _data = null; // never show one sensor's chart under another's title
      _error = null;
      _covered = null;
      _load();
    } else if (old.reloadToken != widget.reloadToken) {
      _load();
    } else if (!identical(old.device, widget.device) && !_busy && _isBehind) {
      // A poll succeeded (each one brings new objects) with a reading the chart does not have.
      // Rebuilds from failed polls keep the same object, so an unreachable API costs no request.
      _catchUp();
    }
  }

  bool get _isBehind {
    final latest = _latestOnDashboard;
    final covered = _covered;
    return latest != null && (covered == null || latest.isAfter(covered));
  }

  Future<ReadingHistory> _fetchWindow() => widget.source.fetchHistory(
        deviceId: widget.device.deviceId,
        sensorType: widget.sensorType,
        from: _now().toUtc().subtract(_window),
      );

  /// Loads the whole 24 hours; the chart on screen stays until the new one arrives.
  Future<void> _load() => _run(_fetchWindow);

  /// Fetches only the readings after the chart's newest point and appends them.
  Future<void> _catchUp() {
    final data = _data;
    if (data == null || data.isEmpty) return _load();
    return _run(() async {
      final newer = await widget.source.fetchHistory(
        deviceId: widget.device.deviceId,
        sensorType: widget.sensorType,
        from: data.readings.last.measuredAt,
      );
      // More new readings than one page holds (a long outage): appending would leave a hole.
      if (newer.truncated) return _fetchWindow();
      return data.extendedWith(newer, since: _now().toUtc().subtract(_window));
    });
  }

  Future<void> _run(Future<ReadingHistory> Function() fetch) async {
    final request = ++_request;
    final latest = _latestOnDashboard;
    _busy = true;
    try {
      final result = await fetch();
      if (!mounted || request != _request) return;
      setState(() {
        _data = result;
        _error = null;
        _covered = latest;
      });
    } on Object catch (e, stack) {
      if (!mounted || request != _request) return;
      // Keeps _data: the last good chart stays on screen.
      setState(() => _error = errorMessageFor(e, stack, where: 'TrendCard'));
    } finally {
      if (request == _request) _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = sensorInfo(widget.sensorType);
    final data = _data;
    return SurfaceCard(
      onTap: widget.onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${info.labelTh} · 24 ชม. · ${widget.device.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Text(
                'ดูทั้งหมด',
                style: theme.textTheme.labelMedium?.copyWith(color: AppTokens.primary),
              ),
              const Icon(Icons.chevron_right, size: 16, color: AppTokens.primary),
            ],
          ),
          // On its own line so it always shows in full, however narrow the phone.
          if (data != null && data.hasSimulated) ...[
            const SizedBox(height: AppTokens.space1),
            const SimulatedBadge(),
          ],
          const SizedBox(height: AppTokens.space2),
          SizedBox(
            height: AppTokens.trendChartHeight,
            child: switch ((data, _error)) {
              (null, null) => const Center(child: LinearProgressIndicator(minHeight: 2)),
              (null, String _) => Center(
                  child: Text('โหลดกราฟไม่ได้ แตะเพื่อเปิดหน้ากราฟ', style: theme.textTheme.bodySmall),
                ),
              (final ReadingHistory d, _) when d.isEmpty => Center(
                  child: Text('ยังไม่มีข้อมูลใน 24 ชม. ล่าสุด', style: theme.textTheme.bodySmall),
                ),
              (final ReadingHistory d, _) => HistoryChart(readings: d.readings, decimals: info.decimals, compact: true),
            },
          ),
          if (data != null && _error != null) ...[
            const SizedBox(height: AppTokens.space1),
            Text(
              data.isEmpty
                  ? 'อัปเดตกราฟไม่ได้'
                  : 'อัปเดตกราฟไม่ได้ · ข้อมูลถึง ${formatClockOrDay(data.readings.last.measuredAt, _now())}',
              maxLines: 2,
              style: theme.textTheme.labelSmall?.copyWith(color: AppTokens.staleBannerFg),
            ),
          ],
        ],
      ),
    );
  }
}
