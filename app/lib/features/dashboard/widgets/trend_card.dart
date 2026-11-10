import 'package:flutter/material.dart';

import '../../../core/sensor_catalog.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../../core/widgets/ui_parts.dart';
import '../../../data/api_client.dart';
import '../../../data/models.dart';
import '../../history/widgets/history_chart.dart';

/// "sensor · 24 ชม." card on the dashboard (design: TrendCard). Loads the last 24 hours of one
/// sensor from the History API once, and again whenever [reloadToken] changes (pull to refresh),
/// not on every 5-second dashboard poll. Tapping it opens the sensor page.
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
  ReadingHistory? _data;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TrendCard old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken ||
        old.device.deviceId != widget.device.deviceId ||
        old.sensorType != widget.sensorType) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final now = (widget.clock ?? DateTime.now)();
    try {
      final result = await widget.source.fetchHistory(
        deviceId: widget.device.deviceId,
        sensorType: widget.sensorType,
        from: now.toUtc().subtract(const Duration(hours: 24)),
      );
      if (!mounted || request != _request) return;
      setState(() {
        _data = result;
        _error = null;
      });
    } on Object catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = e is ApiException ? e.message : '$e');
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
        ],
      ),
    );
  }
}
