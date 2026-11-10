import 'package:flutter/material.dart';

/// Design tokens — the ONLY place for colours, spacing, radii and type sizes.
///
/// Values come from the "Design Tokens" frame and the screens of the Figma file
/// "AgriTwin — Mobile UI Concept | Research Proposal" (file key hGwFuniaKYJQpuV7QEtS9E, read 10 Nov 2026).
/// Tokens marked "derived" are not in that file; they fill states the concept does not show
/// (errors, suspect values) or keep small text readable. This is NOT the Kaset App design (task UI-1).
class AppTokens {
  AppTokens._();

  // ---- Colours: design tokens frame ----
  static const Color primary = Color(0xFF176B4D); // Forest Green
  static const Color secondary = Color(0xFF48A878); // Fresh Green
  static const Color background = Color(0xFFF7FAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F3028);
  static const Color textSecondary = Color(0xFF728178);
  static const Color border = Color(0xFFE3ECE6);
  static const Color warning = Color(0xFFE5A23B);
  static const Color error = Color(0xFFD85A5A);

  // ---- Colours: used on the screens ----
  static const Color textMuted = Color(0xFF94A39A); // chart axis values
  static const Color primaryTint = Color(0xFFE6F2EC); // icon badges, active states
  static const Color segmentTrack = Color(0xFFEAF1EC);
  static const Color selectedTile = Color(0xFFF0F7F3);
  static const Color demoChipBg = Color(0xFFFDF3E3);
  static const Color demoChipFg = Color(0xFF9A6514);
  static const Color shadow = Color(0x141F3028); // 8 % of textPrimary, segmented thumb
  static const Color onPrimary = surface;
  static const Color onPrimaryMuted = Color(0xCCFFFFFF); // 80 % white on the summary card
  static const Color onPrimaryLabel = Color(0xBFFFFFFF); // 75 % white
  static const Color onPrimaryDivider = Color(0x2EFFFFFF); // 18 % white
  static const Color onPrimaryDecoration = Color(0x14FFFFFF); // 8 % white circle
  static const Color chartFill = Color(0x1F176B4D); // 12 % primary under the line

  // Sensor accents: icon colour and badge tint, sampled from the sensor cards.
  static const Color sensorWater = Color(0xFF2F8FBF);
  static const Color sensorWaterTint = Color(0xFFE5F2F8);
  static const Color sensorAirHeat = Color(0xFFD9822B);
  static const Color sensorAirHeatTint = Color(0xFFFCF0E3);
  static const Color sensorSoilHeat = Color(0xFFB0703A);
  static const Color sensorSoilHeatTint = Color(0xFFF6EDE4); // derived
  static const Color sensorHumidity = primary;
  static const Color sensorHumidityTint = primaryTint;
  static const Color sensorRain = Color(0xFF4E7FC9);
  static const Color sensorRainTint = Color(0xFFE8EFFA);
  static const Color sensorWind = Color(0xFF5E7C8C);
  static const Color sensorWindTint = Color(0xFFE9EFF2); // derived

  // ---- Colours: states the concept does not draw (derived) ----
  static const Color online = secondary;
  static const Color offline = warning;
  static const Color suspect = Color(0xFFB4690E); // darker than warning so small text stays readable
  static const Color staleBannerBg = Color(0xFFFBEAEA);
  static const Color staleBannerFg = Color(0xFF9E3434);
  static const Color simulatedBadgeBg = demoChipBg;
  static const Color simulatedBadgeFg = demoChipFg;
  static const Color seed = primary;

  // ---- Spacing (design: 8 · 12 · 16 · 24, screen padding 20) ----
  static const double chipPadV = 3;
  static const double space1 = 4;
  static const double gapTight = 6; // dot-to-label and icon-to-label gaps inside chips
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double screenPadding = space5;

  // ---- Radii (design: cards 12–18) ----
  static const double radiusHero = 18;
  static const double radiusCard = 16;
  static const double radiusTile = 14;
  static const double radiusSegment = 12;
  static const double radiusSegmentThumb = 9;
  static const double radiusLogo = 12;
  static const double radiusChip = 999;

  // ---- Type (design: Noto Sans Thai for text, Inter for numbers; fonts are not bundled) ----
  static const double fontH1 = 24; // page title
  static const double fontGreeting = 22;
  static const double fontAppName = 19;
  static const double fontSection = 15; // section titles
  static const double fontBody = 14;
  static const double fontCardTitle = 13; // chart card title
  static const double fontBodySmall = 12;
  static const double fontCaption = 11;
  static const double fontTileLabel = 10.5;
  static const double fontAxis = 10;
  static const double fontOverline = 9.5; // "SMART FARM · DIGITAL TWIN"
  static const double overlineTracking = 0.95;
  static const double fontHero = 30; // number on the summary card
  static const double fontValueL = 28; // chart card value
  static const double fontValueM = 20; // sensor card value
  static const double fontValueS = 19; // sensor tile value
  static const double valueFontSize = fontValueM;
  static const double captionFontSize = fontCaption;

  // ---- Sizes ----
  static const double logoSize = 40;
  static const double heroDecorationSize = 150; // soft circle in the summary card's corner
  static const double iconBadgeSize = 36;
  static const double statusBadgeSize = 34; // device status card
  static const double hairline = 1;
  static const double iconInBadge = 18;
  static const double statusDot = 7;
  static const double segmentHeight = 36;
  static const double selectedTileBorder = 1.5;
  static const double minTapTarget = 40;

  // ---- Layout ----
  static const double wideBreakpoint = 720;

  // ---- Charts ----
  static const double chartHeight = 170; // sensor page
  static const double trendChartHeight = 76; // dashboard trend card
  static const double chartLabelWidth = 32; // room for the value labels on the left
  static const double chartLineWidth = 2;
  static const double chartGridLineWidth = 1;
  static const double chartPointRadius = 3;
  static const double chartEndRingRadius = 4.5;
}
