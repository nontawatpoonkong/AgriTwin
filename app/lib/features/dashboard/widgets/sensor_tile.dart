import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/sensor_catalog.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models.dart';

class SensorTile extends StatelessWidget {
  const SensorTile({super.key, required this.reading, this.onTap});

  final LatestReading reading;

  /// Opens this sensor's history chart; the tile is not tappable when null.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = sensorInfo(reading.sensorType);
    final decoration = BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTokens.radiusTile),
      border: reading.isSuspect ? Border.all(color: AppTokens.suspect, width: 1.5) : null,
    );
    final body = Padding(
      padding: const EdgeInsets.all(AppTokens.space3),
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
              if (onTap != null) Icon(Icons.show_chart, size: 16, color: theme.colorScheme.outline),
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

    if (onTap == null) return DecoratedBox(decoration: decoration, child: body);
    // Ink draws the tile background on the Material so the tap ripple stays visible on top of it.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusTile),
        child: Ink(decoration: decoration, child: body),
      ),
    );
  }
}
