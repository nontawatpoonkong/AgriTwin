import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../../core/widgets/ui_parts.dart';
import '../../../data/models.dart';

/// Green summary card at the top of the dashboard. The design shows a weather forecast here; the
/// system has no weather source, so the card summarises what it does know: devices online/offline
/// and suspect readings, all from GET /api/v1/dashboard/latest.
class StatusHero extends StatelessWidget {
  const StatusHero({super.key, required this.data});

  final DashboardLatest data;

  @override
  Widget build(BuildContext context) {
    final total = data.devices.length;
    final online = data.devices.where((d) => d.isOnline).length;
    final suspect = data.devices.expand((d) => d.readings).where((r) => r.isSuspect).length;
    final simulated = data.devices.any((d) => d.isSimulated);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusHero),
      child: Container(
        color: AppTokens.primary,
        padding: const EdgeInsets.all(AppTokens.space4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -AppTokens.heroDecorationSize * 0.4,
              top: -AppTokens.heroDecorationSize * 0.57,
              child: Container(
                width: AppTokens.heroDecorationSize,
                height: AppTokens.heroDecorationSize,
                decoration: const BoxDecoration(color: AppTokens.onPrimaryDecoration, shape: BoxShape.circle),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: AppTokens.space1),
                      child: Icon(Icons.sensors, size: 30, color: AppTokens.onPrimary),
                    ),
                    const SizedBox(width: AppTokens.space2),
                    Text('$online/$total', style: valueStyle(AppTokens.fontHero, color: AppTokens.onPrimary)),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'อุปกรณ์ออนไลน์',
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: AppTokens.fontBody,
                              fontWeight: FontWeight.w500,
                              color: AppTokens.onPrimary,
                            ),
                          ),
                          Text(
                            'ข้อมูล ณ ${formatClock(data.serverTime)}',
                            style: const TextStyle(fontSize: AppTokens.fontCaption, color: AppTokens.onPrimaryMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // On its own line so the label always shows in full (AGENTS.md rule 4).
                if (simulated) ...[
                  const SizedBox(height: AppTokens.space2),
                  const SimulatedBadge(),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTokens.space3),
                  child: Divider(height: AppTokens.hairline, color: AppTokens.onPrimaryDivider),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Stat(label: 'อุปกรณ์ทั้งหมด', value: '$total เครื่อง')),
                    Expanded(
                      child: _Stat(label: 'ขาดการติดต่อ', value: '${total - online} เครื่อง', dot: AppTokens.offline),
                    ),
                    Expanded(child: _Stat(label: 'ค่าผิดปกติ', value: '$suspect ค่า', dot: AppTokens.suspect)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.dot});

  final String label;
  final String value;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: AppTokens.fontCaption, color: AppTokens.onPrimaryLabel),
        ),
        Row(
          children: [
            if (dot != null) ...[StatusDot(color: dot!), const SizedBox(width: AppTokens.gapTight)],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTokens.fontSection,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
