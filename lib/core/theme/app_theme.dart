import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Semantic colours that Material's own scheme has no slot for.
///
/// Meal state is the app's central idea, so it gets first-class colour roles
/// rather than ad-hoc opacity tweaks scattered through widgets.
@immutable
class MessColors extends ThemeExtension<MessColors> {
  /// Creates a colour set.
  const MessColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.hairline,
    required this.accent,
    required this.onAccent,
    required this.accentTint,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.closedSurface,
    required this.closedText,
    required this.veg,
    required this.nonVeg,
    required this.danger,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  /// Dark-first palette. This is the app's default look.
  static const MessColors dark = MessColors(
    canvas: AppColors.darkCanvas,
    surface: AppColors.darkSurface,
    surfaceRaised: AppColors.darkSurfaceRaised,
    hairline: AppColors.darkHairline,
    accent: AppColors.saffron,
    onAccent: AppColors.onSaffron,
    accentTint: Color(0x1AF59E14),
    heroGradientStart: AppColors.saffronLight,
    heroGradientEnd: AppColors.amberDeep,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    closedSurface: Color(0xFF1B1511),
    closedText: AppColors.darkTextMuted,
    veg: AppColors.vegGreenDark,
    nonVeg: AppColors.nonVegBrownDark,
    danger: AppColors.danger,
    shimmerBase: AppColors.darkShimmerBase,
    shimmerHighlight: AppColors.darkShimmerHighlight,
  );

  /// Light palette, kept just as warm as the dark one.
  static const MessColors light = MessColors(
    canvas: AppColors.lightCanvas,
    surface: AppColors.lightSurface,
    surfaceRaised: AppColors.lightSurfaceRaised,
    hairline: AppColors.lightHairline,
    accent: AppColors.saffronLightMode,
    onAccent: Color(0xFFFFFFFF),
    accentTint: Color(0x14C2660A),
    heroGradientStart: AppColors.saffron,
    heroGradientEnd: AppColors.amberDeep,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    closedSurface: Color(0xFFF4ECE3),
    closedText: AppColors.lightTextMuted,
    veg: AppColors.vegGreen,
    nonVeg: AppColors.nonVegBrown,
    danger: AppColors.danger,
    shimmerBase: AppColors.lightShimmerBase,
    shimmerHighlight: AppColors.lightShimmerHighlight,
  );

  /// Page background.
  final Color canvas;

  /// Resting card surface.
  final Color surface;

  /// Raised surface for chips and expanded content.
  final Color surfaceRaised;

  /// Hairline borders.
  final Color hairline;

  /// The saffron accent, used only for the meal being served.
  final Color accent;

  /// Foreground on top of [accent].
  final Color onAccent;

  /// A faint wash of [accent] for backgrounds.
  final Color accentTint;

  /// Top-left of the now-serving gradient.
  final Color heroGradientStart;

  /// Bottom-right of the now-serving gradient.
  final Color heroGradientEnd;

  /// Primary reading colour.
  final Color textPrimary;

  /// Supporting copy.
  final Color textSecondary;

  /// De-emphasised copy.
  final Color textMuted;

  /// Surface for a meal that has closed.
  final Color closedSurface;

  /// Text on a closed meal.
  final Color closedText;

  /// Vegetarian marker.
  final Color veg;

  /// Non-vegetarian marker.
  final Color nonVeg;

  /// Error affordances.
  final Color danger;

  /// Shimmer trough.
  final Color shimmerBase;

  /// Shimmer crest.
  final Color shimmerHighlight;

  @override
  MessColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? hairline,
    Color? accent,
    Color? onAccent,
    Color? accentTint,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? closedSurface,
    Color? closedText,
    Color? veg,
    Color? nonVeg,
    Color? danger,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) => MessColors(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    hairline: hairline ?? this.hairline,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentTint: accentTint ?? this.accentTint,
    heroGradientStart: heroGradientStart ?? this.heroGradientStart,
    heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    closedSurface: closedSurface ?? this.closedSurface,
    closedText: closedText ?? this.closedText,
    veg: veg ?? this.veg,
    nonVeg: nonVeg ?? this.nonVeg,
    danger: danger ?? this.danger,
    shimmerBase: shimmerBase ?? this.shimmerBase,
    shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
  );

  @override
  MessColors lerp(ThemeExtension<MessColors>? other, double t) {
    if (other is! MessColors) return this;
    return MessColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      heroGradientStart: Color.lerp(
        heroGradientStart,
        other.heroGradientStart,
        t,
      )!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      closedSurface: Color.lerp(closedSurface, other.closedSurface, t)!,
      closedText: Color.lerp(closedText, other.closedText, t)!,
      veg: Color.lerp(veg, other.veg, t)!,
      nonVeg: Color.lerp(nonVeg, other.nonVeg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
    );
  }
}

/// Convenient access to [MessColors] from any build method.
extension MessColorsContext on BuildContext {
  /// The active semantic palette.
  MessColors get mess =>
      Theme.of(this).extension<MessColors>() ?? MessColors.dark;
}

/// Builds the app's light and dark themes.
class AppTheme {
  const AppTheme._();

  /// Corner radius used by cards and sheets.
  static const double cardRadius = 22;

  /// Corner radius used by chips and small controls.
  static const double chipRadius = 14;

  /// Standard page padding.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20);

  /// The dark theme — the app's default.
  static ThemeData dark() => _build(MessColors.dark, Brightness.dark);

  /// The light theme.
  static ThemeData light() => _build(MessColors.light, Brightness.light);

  static ThemeData _build(MessColors colors, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.saffron,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: colors.onAccent,
          surface: colors.surface,
          onSurface: colors.textPrimary,
          error: colors.danger,
        );

    final baseTheme = ThemeData(brightness: brightness);
    final textTheme = AppTypography.textTheme(
      base: baseTheme.textTheme,
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.hairline,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.accentTint,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? colors.accent : colors.textMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? colors.accent : colors.textMuted,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(chipRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(chipRadius),
          borderSide: BorderSide(color: colors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(chipRadius),
          borderSide: BorderSide(color: colors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(chipRadius),
          borderSide: BorderSide(color: colors.accent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(chipRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.hairline),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(chipRadius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onAccent
              : colors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.surfaceRaised,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.hairline,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
      iconTheme: IconThemeData(color: colors.textSecondary),
    );
  }
}
