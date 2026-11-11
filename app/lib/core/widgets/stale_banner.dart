import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/tokens.dart';

/// Shown above data that stays on screen after a later request failed (stale/offline state):
/// the short reason ([error], an `ApiException.message`) and when the data on screen was loaded.
/// Technical details are only in the log.
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, required this.error, required this.lastSuccessAt, this.now});

  final String error;
  final DateTime? lastSuccessAt;

  /// "Now" for deciding whether [lastSuccessAt] needs its date; defaults to the device clock.
  final DateTime? now;

  static const _style = TextStyle(
    color: AppTokens.staleBannerFg,
    fontSize: AppTokens.fontBodySmall,
    height: 1.45,
  );

  @override
  Widget build(BuildContext context) {
    final when = lastSuccessAt == null ? '' : ' เมื่อ ${formatClockOrDay(lastSuccessAt!, now ?? DateTime.now())}';
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space3),
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: AppTokens.staleBannerBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusTile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off, size: 20, color: AppTokens.staleBannerFg),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _style.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'กำลังแสดงข้อมูลล่าสุด$when',
                  style: _style.copyWith(fontSize: AppTokens.fontCaption),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
