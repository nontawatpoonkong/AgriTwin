import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Label for anything that is not real field data (source != "gateway"). See AGENTS.md rule 4.
class SimulatedBadge extends StatelessWidget {
  const SimulatedBadge({super.key});

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
