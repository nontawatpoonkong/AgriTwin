import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/sensor_catalog.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models.dart';

class SensorTile extends StatelessWidget {
  const SensorTile({super.key, required this.reading});

  final LatestReading reading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = sensorInfo(reading.sensorType);

    return Container(
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusTile),
        border: reading.isSuspect ? Border.all(color: AppTokens.suspect, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(info.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppTokens.space1),
              Expanded(
                child: Text(
                  info.labelTh,
                  style: theme.textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: reading.value.toStringAsFixed(info.decimals),
                  style: const TextStyle(
                    fontSize: AppTokens.valueFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: ' ${reading.unit}', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space1),
          Text(
            'วัดเมื่อ ${formatClock(reading.measuredAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (reading.isSuspect)
            const Padding(
              padding: EdgeInsets.only(top: AppTokens.space1),
              child: Text(
                'ค่าผิดปกติ ตรวจสอบเซนเซอร์',
                style: TextStyle(color: AppTokens.suspect, fontSize: AppTokens.captionFontSize),
              ),
            ),
        ],
      ),
    );
  }
}
