import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale for SUMPAY.
///
/// Uses Plus Jakarta Sans for display / headline text and Inter for body copy,
/// producing a clean institutional feel with excellent legibility at large
/// accessibility text sizes.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color primary, Color secondary) {
    final TextTheme display = GoogleFonts.plusJakartaSansTextTheme();
    final TextTheme body = GoogleFonts.interTextTheme();

    return TextTheme(
      displayLarge: display.displayLarge?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: primary,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: primary,
      ),
      displaySmall: display.displaySmall?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: display.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: display.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        color: primary,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontSize: 14.5,
        height: 1.5,
        color: secondary,
      ),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.45,
        color: secondary,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: primary,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: secondary,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: secondary,
      ),
    );
  }
}
