import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/sensor_catalog.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/simulated_badge.dart';
import '../../core/widgets/stale_banner.dart';
import '../../core/widgets/ui_parts.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import 'history_controller.dart';
import 'widgets/history_chart.dart';

/// One device's sensor page (APP-1), laid out like the design's "IoT Sensor Monitoring" screen:
/// device status, a 24 h / 7 d / 30 d chart of the selected sensor and the device's latest values,
/// where tapping a value switches the chart to that sensor.
class SensorHistoryPage extends StatefulWidget {
  const SensorHistoryPage({
    super.key,
    required this.source,
    required this.deviceId,
    required this.deviceTitle,
    required this.sensorType,
    this.initialDevice,
    this.clock,
  });

  final HistorySource source;
  final String deviceId;
  final String deviceTitle;
  final String sensorType;

  /// The dashboard's copy of the device, shown until the page has loaded its own.
  final DeviceLatest? initialDevice;

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
      device: widget.initialDevice,
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
    return Scaffold(
      appBar: AppBar(
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
        builder: (context, _) {
          final device = _controller.device;
          final now = (widget.clock ?? DateTime.now)();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.screenPadding,
              0,
              AppTokens.screenPadding,
              AppTokens.space6,
            ),
            children: [
              Row(
                children: [
                  Expanded(child: Text('ข้อมูลเซนเซอร์', style: theme.textTheme.headlineSmall)),
                  const SizedBox(width: AppTokens.space2),
                  Flexible(child: _DeviceChip(title: widget.deviceTitle)),
                ],
              ),
              const SizedBox(height: AppTokens.space3),
              if (device != null) ...[
                _DeviceStatusCard(device: device, now: now),
                const SizedBox(height: AppTokens.space3),
              ],
              PillSegmented<HistoryRange>(
                segments: [for (final r in HistoryRange.values) (r, r.label)],
                selected: _controller.range,
                onChanged: _controller.selectRange,
              ),
              const SizedBox(height: AppTokens.space3),
              if (_controller.error != null && _controller.data != null)
                StaleBanner(error: _controller.error!, lastSuccessAt: _controller.lastSuccessAt, now: now),
              _ChartCard(controller: _controller),
              if (device != null && device.readings.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space4),
                _LatestValues(
                  device: device,
                  selected: _controller.sensorType,
                  onSelect: _controller.selectSensor,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space3, vertical: AppTokens.space2),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusSegment),
        border: Border.all(color: AppTokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors, size: 15, color: AppTokens.primary),
          const SizedBox(width: AppTokens.gapTight),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: AppTokens.fontBodySmall, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({required this.device, required this.now});

  final DeviceLatest device;
  final DateTime now;

  static String _sourceLabel(String source) => switch (source) {
        'gateway' => 'Gateway (ข้อมูลจริง)',
        'simulator' => 'Simulator',
        'test' => 'ทดสอบระบบ',
        _ => source,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceBlock = _StatusBlock(
      icon: Icons.sensors,
      label: device.title,
      value: StatusDotLabel(online: device.isOnline),
    );
    final sourceBlock = _StatusBlock(
      icon: Icons.router_outlined,
      label: 'แหล่งข้อมูล',
      value: Text(
        _sourceLabel(device.lastSource),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: AppTokens.fontBodySmall, fontWeight: FontWeight.w500),
      ),
    );
    const divider = Padding(
      padding: EdgeInsets.symmetric(vertical: AppTokens.space2),
      child: Divider(height: AppTokens.hairline, color: AppTokens.border),
    );
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Side by side like the design; stacked on narrow phones so labels keep their room.
              if (constraints.maxWidth < 300) {
                return Column(children: [deviceBlock, divider, sourceBlock]);
              }
              return Row(
                children: [
                  Expanded(child: deviceBlock),
                  Container(width: AppTokens.hairline, height: AppTokens.statusBadgeSize, color: AppTokens.border),
                  const SizedBox(width: AppTokens.space3),
                  Expanded(child: sourceBlock),
                ],
              );
            },
          ),
          divider,
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppTokens.textSecondary),
              const SizedBox(width: AppTokens.space1),
              Expanded(
                child: Text(
                  'อัปเดต ${formatClockOrDay(device.lastSeenAt, now)} น.',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          if (device.isSimulated) ...[
            const SizedBox(height: AppTokens.space2),
            const SimulatedBadge(),
          ],
        ],
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(
          icon: icon,
          color: AppTokens.primary,
          tint: AppTokens.primaryTint,
          size: AppTokens.statusBadgeSize,
        ),
        const SizedBox(width: AppTokens.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              value,
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.controller});

  final SensorHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = sensorInfo(controller.sensorType);
    final data = controller.data;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The badge wraps under the title when the card is narrow; it is never shortened.
          Wrap(
            spacing: AppTokens.space2,
            runSpacing: AppTokens.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${info.labelTh} (${info.labelEn})',
                style: const TextStyle(fontSize: AppTokens.fontCardTitle, fontWeight: FontWeight.w500),
              ),
              if (data != null && data.hasSimulated) const SimulatedBadge(),
            ],
          ),
          ..._body(theme, info, data),
        ],
      ),
    );
  }

  List<Widget> _body(ThemeData theme, SensorInfo info, ReadingHistory? data) {
    if (data == null) {
      final error = controller.error;
      if (error != null) return [_LoadError(message: error, onRetry: controller.load)];
      return const [
        SizedBox(height: AppTokens.chartHeight, child: Center(child: CircularProgressIndicator())),
      ];
    }
    final readings = data.readings;
    if (readings.isEmpty) return [_Empty(range: controller.range)];

    final values = readings.map((r) => r.value);
    final unit = readings.last.unit;
    String show(double v) => '${v.toStringAsFixed(info.decimals)} $unit';
    return [
      if (controller.loading) ...[
        const SizedBox(height: AppTokens.space1),
        const LinearProgressIndicator(minHeight: 2),
      ],
      const SizedBox(height: AppTokens.space1),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: readings.last.value.toStringAsFixed(info.decimals),
              style: valueStyle(AppTokens.fontValueL),
            ),
            TextSpan(text: ' $unit', style: theme.textTheme.bodyMedium?.copyWith(color: AppTokens.textSecondary)),
          ],
        ),
      ),
      const SizedBox(height: AppTokens.space1),
      Text(
        'ต่ำสุด ${show(values.reduce(math.min))} · สูงสุด ${show(values.reduce(math.max))}',
        style: theme.textTheme.labelSmall,
      ),
      const SizedBox(height: AppTokens.space3),
      HistoryChart(readings: readings, decimals: info.decimals),
      const SizedBox(height: AppTokens.space2),
      Text(
        '${readings.length} ค่า · ${formatDayTime(readings.first.measuredAt)} '
        'ถึง ${formatDayTime(readings.last.measuredAt)}',
        style: theme.textTheme.labelSmall,
      ),
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
    ];
  }
}

class _LatestValues extends StatelessWidget {
  const _LatestValues({required this.device, required this.selected, required this.onSelect});

  final DeviceLatest device;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readings = [...device.readings]
      ..sort((a, b) => sensorRank(a.sensorType).compareTo(sensorRank(b.sensorType)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'ค่าล่าสุดจาก ${device.title}',
          hint: 'แตะเพื่อดูกราฟ',
          titleStyle: theme.textTheme.titleMedium?.copyWith(fontSize: AppTokens.fontBody),
        ),
        const SizedBox(height: AppTokens.space2),
        LayoutBuilder(
          builder: (context, constraints) {
            // Three per row like the design; two on very narrow phones so values never get cut.
            final columns = constraints.maxWidth < 300 ? 2 : 3;
            final width = (constraints.maxWidth - AppTokens.space2 * (columns - 1)) / columns;
            return Wrap(
              spacing: AppTokens.space2,
              runSpacing: AppTokens.space2,
              children: [
                for (final r in readings)
                  SizedBox(
                    width: width,
                    child: _ValueTile(
                      reading: r,
                      selected: r.sensorType == selected,
                      onTap: () => onSelect(r.sensorType),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.reading, required this.selected, required this.onTap});

  final LatestReading reading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = sensorInfo(reading.sensorType);
    final radius = BorderRadius.circular(AppTokens.radiusTile);
    final borderColor = selected
        ? AppTokens.primary
        : reading.isSuspect
            ? AppTokens.suspect
            : AppTokens.border;
    return Semantics(
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? AppTokens.selectedTile : AppTokens.surface,
              borderRadius: radius,
              border: Border.all(
                color: borderColor,
                width: selected || reading.isSuspect ? AppTokens.selectedTileBorder : AppTokens.hairline,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space3 - 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(info.icon, size: 18, color: info.color),
                  const SizedBox(height: AppTokens.space1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: reading.value.toStringAsFixed(info.decimals),
                            style: valueStyle(AppTokens.fontValueS),
                          ),
                          TextSpan(
                            text: ' ${reading.unit}',
                            style: const TextStyle(
                              fontSize: AppTokens.fontCaption,
                              color: AppTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    info.labelTh,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppTokens.fontTileLabel, color: AppTokens.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final tint = color ?? AppTokens.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: AppTokens.space1),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: AppTokens.fontBodySmall, color: tint, height: 1.45)),
          ),
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
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.show_chart, size: 40, color: AppTokens.textMuted),
            const SizedBox(height: AppTokens.space2),
            Text(
              'ไม่มีข้อมูลในช่วง ${range.label} ล่าสุด',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.space1),
            Text(
              'ลองเลือกช่วงเวลาอื่น หรือตรวจว่าอุปกรณ์ยังส่งข้อมูลอยู่',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space4),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppTokens.error),
            const SizedBox(height: AppTokens.space2),
            Text('โหลดข้อมูลย้อนหลังไม่ได้', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.space1),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTokens.space3),
            FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}
