import 'package:flutter/painting.dart';

/// The raw palette.
///
/// Warm and food-adjacent, built dark-first: a deep charcoal-brown base with a
/// saffron accent reserved exclusively for the meal being served right now.
/// Semantic roles are assigned in `app_theme.dart`; nothing outside that file
/// should reach for these constants directly.
class AppColors {
  const AppColors._();

  // ------------------------------------------------------------ dark base
  /// Page background — deep charcoal-brown, not a neutral grey.
  static const Color darkCanvas = Color(0xFF15100D);

  /// Resting card surface.
  static const Color darkSurface = Color(0xFF1F1813);

  /// Raised surface: chips, expanded rows, day strip cells.
  static const Color darkSurfaceRaised = Color(0xFF2A211A);

  /// Hairline borders and dividers.
  static const Color darkHairline = Color(0xFF3A2E25);

  /// Primary reading colour.
  static const Color darkTextPrimary = Color(0xFFF6EDE4);

  /// Supporting copy.
  static const Color darkTextSecondary = Color(0xFFBFAE9F);

  /// De-emphasised copy and closed meals.
  static const Color darkTextMuted = Color(0xFF8A7A6C);

  // ----------------------------------------------------------- light base
  /// Page background — warm off-white, never pure white.
  static const Color lightCanvas = Color(0xFFFBF5EE);

  /// Resting card surface.
  static const Color lightSurface = Color(0xFFFFFBF7);

  /// Raised surface.
  static const Color lightSurfaceRaised = Color(0xFFF2E7DA);

  /// Hairline borders and dividers.
  static const Color lightHairline = Color(0xFFE2D3C2);

  /// Primary reading colour.
  static const Color lightTextPrimary = Color(0xFF241A12);

  /// Supporting copy.
  static const Color lightTextSecondary = Color(0xFF6B5847);

  /// De-emphasised copy and closed meals.
  static const Color lightTextMuted = Color(0xFF9B8776);

  // --------------------------------------------------------------- accent
  /// Saffron. The single saturated colour, reserved for the active meal.
  static const Color saffron = Color(0xFFF59E14);

  /// Lighter saffron for gradients and glows.
  static const Color saffronLight = Color(0xFFFFC24D);

  /// Deeper amber for the far end of the hero gradient.
  static const Color amberDeep = Color(0xFFD97706);

  /// Text and icons drawn on top of saffron.
  static const Color onSaffron = Color(0xFF231303);

  /// Accent tuned for light mode, where pure saffron reads as washed out.
  static const Color saffronLightMode = Color(0xFFC2660A);

  // -------------------------------------------------------------- markers
  /// The green of the standard Indian vegetarian mark.
  static const Color vegGreen = Color(0xFF2E9E5B);

  /// A brighter green that keeps contrast on the dark canvas.
  static const Color vegGreenDark = Color(0xFF4CC77E);

  /// The red of the non-vegetarian mark.
  static const Color nonVegRed = Color(0xFFC62828);

  /// A lifted non-veg mark for the dark canvas.
  static const Color nonVegRedDark = Color(0xFFFF6B5C);

  /// Veg mark drawn on the saffron now-serving card, where the usual greens
  /// wash out.
  static const Color vegOnAccent = Color(0xFF14532D);

  /// Non-veg mark drawn on the saffron now-serving card.
  static const Color nonVegOnAccent = Color(0xFF7F1D1D);

  // --------------------------------------------------------------- status
  /// Error and destructive affordances.
  static const Color danger = Color(0xFFD2553D);

  /// Shimmer trough.
  static const Color darkShimmerBase = Color(0xFF241C16);

  /// Shimmer crest.
  static const Color darkShimmerHighlight = Color(0xFF35291F);

  /// Shimmer trough, light mode.
  static const Color lightShimmerBase = Color(0xFFEDE1D3);

  /// Shimmer crest, light mode.
  static const Color lightShimmerHighlight = Color(0xFFF9F2E9);
}
