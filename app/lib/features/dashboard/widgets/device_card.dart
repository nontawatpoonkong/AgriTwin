import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/sensor_catalog.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../../core/widgets/ui_parts.dart';
import '../../../data/models.dart';
import 'sensor_tile.dart';

/// One device on the dashboard: name, status, freshness, the "ข้อมูลจำลอง" label when it is not
/// gateway data, and its sensor cards two per row (three on wide screens).
class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.device, required this.serverTime, this.onOpenHistory});

  final DeviceLatest device;
  final DateTime serverTime;

  /// Opens the chart of one reading's sensor; cards are not tappable when null.
  final void Function(LatestReading reading)? onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readings = [...device.readings]
      ..sort((a, b) => sensorRank(a.sensorType).compareTo(sensorRank(b.sensorType)));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, size: 18, color: AppTokens.primary),
              const SizedBox(width: AppTokens.gapTight),
              Expanded(
                flex: 2,
                child: Text(
                  device.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: AppTokens.fontBody),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusDotLabel(online: device.isOnline),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space1),
          Wrap(
            spacing: AppTokens.space2,
            runSpacing: AppTokens.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'อัปเดตล่าสุด ${formatAge(serverTime.difference(device.lastSeenAt))}',
                style: theme.textTheme.labelSmall,
              ),
              if (device.isSimulated) const SimulatedBadge(),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          if (readings.isEmpty)
            Text('ยังไม่มีค่าจากเซนเซอร์', style: theme.textTheme.bodySmall)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= AppTokens.wideBreakpoint ? 3 : 2;
                final tileWidth = (constraints.maxWidth - AppTokens.space2 * (columns - 1)) / columns;
                return Wrap(
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space2,
                  children: [
                    for (final r in readings)
                      SizedBox(
                        width: tileWidth,
                        child: SensorTile(
                          reading: r,
                          onTap: onOpenHistory == null ? null : () => onOpenHistory!(r),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
