import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/config/meal_timings.dart';
import 'meal.dart';

/// Which of the two themes the app should wear.
///
/// Kept as an app-level enum rather than Flutter's `ThemeMode` so the model
/// layer stays free of widget imports; `app.dart` maps it across.
enum AppThemeMode {
  /// Follow the device setting. The default.
  system('system'),

  /// Always the warm light theme.
  light('light'),

  /// Always the dark-first theme.
  dark('dark');

  const AppThemeMode(this.storageValue);

  /// Persisted form.
  final String storageValue;

  /// Parses a stored value, defaulting to [AppThemeMode.system].
  static AppThemeMode fromStorage(Object? raw) {
    if (raw is! String) return AppThemeMode.system;
    for (final mode in AppThemeMode.values) {
      if (mode.storageValue == raw) return mode;
    }
    return AppThemeMode.system;
  }
}

/// Everything the student has chosen, persisted across launches.
@immutable
class AppSettings {
  /// Creates a settings snapshot. [reminderMeals] is made immutable.
  AppSettings({
    required this.messId,
    required this.onboardingCompleted,
    required this.remindersEnabled,
    required Set<MealType> reminderMeals,
    required this.timings,
    this.themeMode = AppThemeMode.system,
  }) : reminderMeals = Set<MealType>.unmodifiable(reminderMeals);

  /// The state a fresh install starts in: onboarding pending, reminders off.
  factory AppSettings.initial() => AppSettings(
    messId: AppConfig.defaultMessId,
    onboardingCompleted: false,
    remindersEnabled: false,
    reminderMeals: MealType.values.toSet(),
    timings: MealTimings.defaults,
  );

  /// Selected subscription tier.
  final String messId;

  /// Whether onboarding has been dismissed. Onboarding shows exactly once.
  final bool onboardingCompleted;

  /// Master switch for meal reminders.
  final bool remindersEnabled;

  /// Which slots fire a reminder when [remindersEnabled] is true. Immutable.
  final Set<MealType> reminderMeals;

  /// Student overrides for the placeholder meal windows.
  final MealTimings timings;

  /// Light, dark, or follow the device.
  final AppThemeMode themeMode;

  /// True when a reminder should be scheduled for [type].
  bool remindsFor(MealType type) =>
      remindersEnabled && reminderMeals.contains(type);

  /// Returns a copy with the given fields replaced.
  AppSettings copyWith({
    String? messId,
    bool? onboardingCompleted,
    bool? remindersEnabled,
    Set<MealType>? reminderMeals,
    MealTimings? timings,
    AppThemeMode? themeMode,
  }) => AppSettings(
    messId: messId ?? this.messId,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderMeals: reminderMeals ?? this.reminderMeals,
    timings: timings ?? this.timings,
    themeMode: themeMode ?? this.themeMode,
  );

  /// Returns a copy with the reminder for [type] switched on or off.
  AppSettings withReminderFor(MealType type, bool enabled) {
    final next = Set<MealType>.from(reminderMeals);
    if (enabled) {
      next.add(type);
    } else {
      next.remove(type);
    }
    return copyWith(reminderMeals: next);
  }

  /// Parses stored settings, falling back to defaults for anything missing or
  /// unrecognised.
  static AppSettings fromJson(Object? json) {
    final fallback = AppSettings.initial();
    if (json is! Map) return fallback;

    final rawMessId = json['messId'];
    final messId = rawMessId is String && rawMessId.trim().isNotEmpty
        ? rawMessId.trim()
        : fallback.messId;

    final rawMeals = json['reminderMeals'];
    final meals = <MealType>{};
    if (rawMeals is List) {
      for (final raw in rawMeals) {
        final type = MealType.fromJson(raw);
        if (type != null) meals.add(type);
      }
    }

    return AppSettings(
      messId: messId,
      onboardingCompleted: json['onboardingCompleted'] == true,
      remindersEnabled: json['remindersEnabled'] == true,
      reminderMeals: meals.isEmpty ? fallback.reminderMeals : meals,
      timings: MealTimings.fromJson(json['timings']),
      themeMode: AppThemeMode.fromStorage(json['themeMode']),
    );
  }

  /// Serialises for local storage.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'messId': messId,
    'onboardingCompleted': onboardingCompleted,
    'remindersEnabled': remindersEnabled,
    'reminderMeals': reminderMeals
        .map((type) => type.jsonValue)
        .toList(growable: false),
    'timings': timings.toJson(),
    'themeMode': themeMode.storageValue,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettings &&
          messId == other.messId &&
          onboardingCompleted == other.onboardingCompleted &&
          remindersEnabled == other.remindersEnabled &&
          setEquals(reminderMeals, other.reminderMeals) &&
          timings == other.timings &&
          themeMode == other.themeMode);

  @override
  int get hashCode => Object.hash(
    messId,
    onboardingCompleted,
    remindersEnabled,
    Object.hashAllUnordered(reminderMeals),
    timings,
    themeMode,
  );

  @override
  String toString() =>
      'AppSettings($messId, onboarded=$onboardingCompleted, '
      'reminders=$remindersEnabled)';
}
