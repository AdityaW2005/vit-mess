import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale for the app.
///
/// Two faces, used consistently: Outfit for display copy and the countdown
/// numerals, Inter for everything a student actually reads word by word. The
/// countdown is deliberately the largest thing on any screen.
class AppTypography {
  const AppTypography._();

  /// Builds the full text theme for a brightness.
  ///
  /// [primary] carries headings and body copy; [secondary] carries supporting
  /// copy such as labels and captions.
  static TextTheme textTheme({
    required TextTheme base,
    required Color primary,
    required Color secondary,
  }) {
    final display = GoogleFonts.outfitTextTheme(base);
    final body = GoogleFonts.interTextTheme(base);

    return base.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.0,
      ),
      displayMedium: display.displayMedium?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.0,
      ),
      displaySmall: display.displaySmall?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.05,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleLarge: display.titleLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: body.titleMedium?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: secondary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: primary, height: 1.4),
      bodyMedium: body.bodyMedium?.copyWith(color: primary, height: 1.4),
      bodySmall: body.bodySmall?.copyWith(color: secondary, height: 1.35),
      labelLarge: body.labelLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: body.labelMedium?.copyWith(
        color: secondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      labelSmall: body.labelSmall?.copyWith(
        color: secondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  /// The hero countdown numerals — the largest type in the app.
  ///
  /// Tabular figures keep the digits from jittering as the seconds tick.
  static TextStyle countdown(Color color) => GoogleFonts.outfit(
    color: color,
    fontSize: 56,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.0,
    height: 1.0,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The smaller countdown used on the "up next" state.
  static TextStyle countdownCompact(Color color) => GoogleFonts.outfit(
    color: color,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.4,
    height: 1.0,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Small all-caps eyebrow above a section or card.
  static TextStyle eyebrow(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  /// The numerals in the day strip.
  static TextStyle dayStripNumber(Color color, {required bool selected}) =>
      GoogleFonts.outfit(
        color: color,
        fontSize: 20,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        height: 1.0,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
}
