import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Label for anything that is not real field data (source != "gateway"). See AGENTS.md rule 4.
/// Styled like the design's "DEMO DATA" chip, but the text stays Thai.
class SimulatedBadge extends StatelessWidget {
  const SimulatedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space2, vertical: AppTokens.chipPadV),
      decoration: BoxDecoration(
        color: AppTokens.simulatedBadgeBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 12, color: AppTokens.simulatedBadgeFg),
          SizedBox(width: AppTokens.space1),
          Text(
            'ข้อมูลจำลอง',
            style: TextStyle(
              color: AppTokens.simulatedBadgeFg,
              fontSize: AppTokens.fontCaption,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
