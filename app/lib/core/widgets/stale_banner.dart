import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/tokens.dart';

/// Shown above data that stays on screen after a later request failed (stale/offline state).
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, required this.error, required this.lastSuccessAt});

  final String error;
  final DateTime? lastSuccessAt;

  @override
  Widget build(BuildContext context) {
    final when = lastSuccessAt == null ? '' : ' เมื่อ ${formatClock(lastSuccessAt!)}';
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space4),
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: AppTokens.staleBannerBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusTile),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppTokens.staleBannerFg),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Text(
              'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กำลังแสดงข้อมูลล่าสุด$when\n$error',
              style: const TextStyle(color: AppTokens.staleBannerFg),
            ),
          ),
        ],
      ),
    );
  }
}
