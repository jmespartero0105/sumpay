import 'package:flutter/material.dart';

/// Centralised colour palette for SUMPAY.
///
/// The palette follows a "modern government app" language: a strong red
/// emergency identity, neutral greys for chrome and generous white surfaces.
class AppColors {
  const AppColors._();

  // Brand
  static const Color primary = Color(0xFFEB0102);
  static const Color secondary = Color(0xFFFF3131);
  static const Color emergency = Color(0xFFFF1111);

  // Neutrals
  static const Color background = Color(0xFFF6F6F6);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFFDF3F3);
  static const Color outline = Color(0xFFE2E2E2);

  // Text
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textDisabled = Color(0xFFA5A5A5);
  static const Color onPrimary = Colors.white;

  // Semantic
  static const Color success = Color(0xFF1B9E4B);
  static const Color successSoft = Color(0xFFE6F5EC);
  static const Color warning = Color(0xFFF08C00);
  static const Color warningSoft = Color(0xFFFDF1DE);
  static const Color info = Color(0xFF1668C1);
  static const Color infoSoft = Color(0xFFE7F0FA);
  static const Color danger = Color(0xFFD32029);
  static const Color dangerSoft = Color(0xFFFCE8E8);
  static const Color neutralSoft = Color(0xFFEDEDED);

  // Dark theme neutrals
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1D1D1D);
  static const Color darkSurfaceAlt = Color(0xFF262626);
  static const Color darkOutline = Color(0xFF3A3A3A);
  static const Color darkTextPrimary = Color(0xFFF2F2F2);
  static const Color darkTextSecondary = Color(0xFFB5B5B5);

  /// Signal strength ramp used by the IoT and dashboard modules.
  static const List<Color> signalRamp = <Color>[
    danger,
    warning,
    success,
  ];
}
