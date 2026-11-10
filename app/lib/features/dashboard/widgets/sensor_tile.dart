import 'package:flutter/material.dart';

import '../../../core/sensor_catalog.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ui_parts.dart';
import '../../../data/models.dart';

/// Latest value of one sensor, styled like the design's dashboard "SensorCard":
/// round tinted icon badge, small label, large value with its unit.
class SensorTile extends StatelessWidget {
  const SensorTile({super.key, required this.reading, this.onTap});

  final LatestReading reading;

  /// Opens this sensor's chart; the card is not tappable when null.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = sensorInfo(reading.sensorType);
    final radius = BorderRadius.circular(AppTokens.radiusTile);
    final decoration = BoxDecoration(
      color: AppTokens.surface,
      borderRadius: radius,
      border: reading.isSuspect
          ? Border.all(color: AppTokens.suspect, width: AppTokens.selectedTileBorder)
          : Border.all(color: AppTokens.border),
    );
    final body = Padding(
      padding: const EdgeInsets.all(AppTokens.space3 - 1),
      child: Row(
        children: [
          IconBadge(icon: info.icon, color: info.color, tint: info.tint),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.labelTh,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: reading.value.toStringAsFixed(info.decimals),
                          style: valueStyle(AppTokens.fontValueM),
                        ),
                        TextSpan(
                          text: ' ${reading.unit}',
                          style: const TextStyle(
                            fontSize: AppTokens.fontBodySmall,
                            color: AppTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (reading.isSuspect)
                  const Padding(
                    padding: EdgeInsets.only(top: AppTokens.space1 / 2),
                    child: Text(
                      'ค่าผิดปกติ ตรวจสอบเซนเซอร์',
                      style: TextStyle(color: AppTokens.suspect, fontSize: AppTokens.captionFontSize),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return DecoratedBox(decoration: decoration, child: body);
    // Ink draws the card on the Material so the tap ripple stays visible on top of it.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(decoration: decoration, child: body),
      ),
    );
  }
}
