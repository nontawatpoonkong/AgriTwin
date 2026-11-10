import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material theme built only from [AppTokens], so the look changes by editing tokens.dart.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppTokens.primary).copyWith(
    primary: AppTokens.primary,
    onPrimary: AppTokens.onPrimary,
    secondary: AppTokens.secondary,
    surface: AppTokens.surface,
    onSurface: AppTokens.textPrimary,
    onSurfaceVariant: AppTokens.textSecondary,
    surfaceContainerHighest: AppTokens.primaryTint,
    outline: AppTokens.textSecondary,
    outlineVariant: AppTokens.border,
    error: AppTokens.error,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme).textTheme;
  final text = base
      .apply(bodyColor: AppTokens.textPrimary, displayColor: AppTokens.textPrimary)
      .copyWith(
        headlineSmall: base.headlineSmall?.copyWith(
          fontSize: AppTokens.fontH1,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: AppTokens.textPrimary,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontSize: AppTokens.fontGreeting,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: AppTokens.textPrimary,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontSize: AppTokens.fontSection,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: AppTokens.textPrimary,
        ),
        bodyLarge: base.bodyLarge?.copyWith(fontSize: AppTokens.fontBody, height: 1.45),
        bodyMedium: base.bodyMedium?.copyWith(fontSize: AppTokens.fontBody, height: 1.45),
        bodySmall: base.bodySmall?.copyWith(
          fontSize: AppTokens.fontBodySmall,
          height: 1.45,
          color: AppTokens.textSecondary,
        ),
        labelLarge: base.labelLarge?.copyWith(fontSize: AppTokens.fontBody, fontWeight: FontWeight.w500),
        labelMedium: base.labelMedium?.copyWith(
          fontSize: AppTokens.fontBodySmall,
          fontWeight: FontWeight.w500,
          color: AppTokens.textPrimary,
        ),
        labelSmall: base.labelSmall?.copyWith(
          fontSize: AppTokens.fontCaption,
          fontWeight: FontWeight.w400,
          height: 1.4,
          letterSpacing: 0,
          color: AppTokens.textSecondary,
        ),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: AppTokens.background,
    dividerColor: AppTokens.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppTokens.background,
      foregroundColor: AppTokens.textPrimary,
      surfaceTintColor: AppTokens.background,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppTokens.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        side: const BorderSide(color: AppTokens.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppTokens.primary,
        foregroundColor: AppTokens.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSegment)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppTokens.primary),
  );
}
