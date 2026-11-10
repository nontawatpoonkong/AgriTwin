import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/sensor_catalog.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/simulated_badge.dart';
import '../../core/widgets/stale_banner.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import 'history_controller.dart';
import 'widgets/history_chart.dart';

/// History of one sensor on one device: 24-hour or 7-day chart from the History API (APP-1).
class SensorHistoryPage extends StatefulWidget {
  const SensorHistoryPage({
    super.key,
    required this.source,
    required this.deviceId,
    required this.deviceTitle,
    required this.sensorType,
    this.clock,
  });

  final HistorySource source;
  final String deviceId;
  final String deviceTitle;
  final String sensorType;

  /// "Now" for the time window; tests pass a fixed clock.
  final DateTime Function()? clock;

  @override
  State<SensorHistoryPage> createState() => _SensorHistoryPageState();
}

class _SensorHistoryPageState extends State<SensorHistoryPage> {
  late final SensorHistoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SensorHistoryController(
      widget.source,
      deviceId: widget.deviceId,
      sensorType: widget.sensorType,
      clock: widget.clock,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = sensorInfo(widget.sensorType);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.labelTh),
            Text(widget.deviceTitle, style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            icon: const Icon(Icons.refresh),
            onPressed: _controller.load,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppTokens.space4),
          children: [
            SegmentedButton<HistoryRange>(
              segments: [
                for (final r in HistoryRange.values) ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {_controller.range},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _controller.selectRange(selection.first),
            ),
            const SizedBox(height: AppTokens.space4),
            ..._content(context, info),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, SensorInfo info) {
    final theme = Theme.of(context);
    final data = _controller.data;
    final error = _controller.error;

    if (data == null) {
      if (error != null) return [_LoadError(message: error, onRetry: _controller.load)];
      return const [
        Padding(
          padding: EdgeInsets.all(AppTokens.space6),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final readings = data.readings;
    return [
      if (_controller.loading) const LinearProgressIndicator(),
      if (error != null) StaleBanner(error: error, lastSuccessAt: _controller.lastSuccessAt),
      if (readings.isEmpty)
        _Empty(range: _controller.range)
      else ...[
        Wrap(
          spacing: AppTokens.space2,
          runSpacing: AppTokens.space1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${readings.length} ค่า · ${formatDayTime(readings.first.measuredAt)} '
              'ถึง ${formatDayTime(readings.last.measuredAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (data.hasSimulated) const SimulatedBadge(),
          ],
        ),
        const SizedBox(height: AppTokens.space3),
        _Summary(readings: readings, decimals: info.decimals),
        const SizedBox(height: AppTokens.space4),
        HistoryChart(readings: readings, decimals: info.decimals),
        if (data.truncated)
          _Note(
            icon: Icons.content_cut,
            text: 'ช่วงนี้มีข้อมูลมากกว่า ${data.limit} ค่า จึงแสดงเฉพาะ ${readings.length} ค่าล่าสุด',
          ),
        if (data.suspectCount > 0)
          _Note(
            icon: Icons.warning_amber,
            text: 'มีค่าผิดปกติ ${data.suspectCount} ค่า ทำเครื่องหมายไว้ในกราฟ',
            color: AppTokens.suspect,
          ),
      ],
    ];
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.readings, required this.decimals});

  final List<LatestReading> readings;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = readings.map((r) => r.value);
    String show(double v) => '${v.toStringAsFixed(decimals)} ${readings.last.unit}';
    final items = {
      'ล่าสุด': show(readings.last.value),
      'ต่ำสุด': show(values.reduce(math.min)),
      'สูงสุด': show(values.reduce(math.max)),
    };
    return Wrap(
      spacing: AppTokens.space6,
      runSpacing: AppTokens.space2,
      children: [
        for (final item in items.entries)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.key, style: theme.textTheme.labelMedium),
              Text(item.value, style: theme.textTheme.titleMedium),
            ],
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: AppTokens.space1),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: tint))),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.range});

  final HistoryRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space6),
      child: Column(
        children: [
          Icon(Icons.show_chart, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: AppTokens.space3),
          Text('ไม่มีข้อมูลในช่วง ${range.label} ล่าสุด', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTokens.space2),
          Text(
            'ลองเลือกช่วงเวลาอื่น หรือตรวจว่าอุปกรณ์ยังส่งข้อมูลอยู่',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTokens.space6),
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: AppTokens.space3),
          Text('โหลดข้อมูลย้อนหลังไม่ได้', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTokens.space2),
          Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppTokens.space4),
          FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}
