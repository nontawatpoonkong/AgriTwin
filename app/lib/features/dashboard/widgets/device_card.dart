import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/sensor_catalog.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models.dart';
import 'sensor_tile.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.device, required this.serverTime});

  final DeviceLatest device;
  final DateTime serverTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readings = [...device.readings]
      ..sort((a, b) => sensorRank(a.sensorType).compareTo(sensorRank(b.sensorType)));

    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.space4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusCard)),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors),
                const SizedBox(width: AppTokens.space2),
                Expanded(child: Text(device.title, style: theme.textTheme.titleMedium)),
                _StatusChip(online: device.isOnline),
              ],
            ),
            const SizedBox(height: AppTokens.space2),
            Wrap(
              spacing: AppTokens.space2,
              runSpacing: AppTokens.space1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'อัปเดตล่าสุด ${formatAge(serverTime.difference(device.lastSeenAt))}',
                  style: theme.textTheme.bodySmall,
                ),
                if (device.isSimulated) const _SimulatedBadge(),
              ],
            ),
            const SizedBox(height: AppTokens.space3),
            if (readings.isEmpty)
              const Text('ยังไม่มีค่าจากเซนเซอร์')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= AppTokens.wideBreakpoint ? 3 : 2;
                  final tileWidth =
                      (constraints.maxWidth - AppTokens.space2 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: AppTokens.space2,
                    runSpacing: AppTokens.space2,
                    children: [
                      for (final r in readings)
                        SizedBox(width: tileWidth, child: SensorTile(reading: r)),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTokens.online : AppTokens.offline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space2, vertical: AppTokens.space1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: AppTokens.space1),
          Text(online ? 'ออนไลน์' : 'ออฟไลน์', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _SimulatedBadge extends StatelessWidget {
  const _SimulatedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space2, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.simulatedBadgeBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, size: 14, color: AppTokens.simulatedBadgeFg),
          SizedBox(width: AppTokens.space1),
          Text(
            'ข้อมูลจำลอง',
            style: TextStyle(
              color: AppTokens.simulatedBadgeFg,
              fontSize: AppTokens.captionFontSize,
            ),
          ),
        ],
      ),
    );
  }
}
