import 'package:flutter/material.dart';

/// Design tokens — the ONLY place for colours, spacing, radii and type sizes.
///
/// PLACEHOLDER VALUES. These are a neutral starting point, NOT the Kaset App design.
/// Replace them once Kaset App screenshots/specs are provided (see docs/NEXT_TASKS.md, task UI-1).
class AppTokens {
  AppTokens._();

  // Colours
  static const Color seed = Color(0xFF2E7D32);
  static const Color online = Color(0xFF2E7D32);
  static const Color offline = Color(0xFF757575);
  static const Color simulatedBadgeBg = Color(0xFFFFF3CD);
  static const Color simulatedBadgeFg = Color(0xFF7A5A00);
  static const Color suspect = Color(0xFFC75000);
  static const Color staleBannerBg = Color(0xFFFDECEA);
  static const Color staleBannerFg = Color(0xFF8A1C1C);

  // Spacing
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;

  // Radii
  static const double radiusCard = 12;
  static const double radiusTile = 10;
  static const double radiusChip = 999;

  // Type
  static const double valueFontSize = 26;
  static const double captionFontSize = 12;

  // Layout
  static const double wideBreakpoint = 720;
}
