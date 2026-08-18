import 'package:flutter/foundation.dart';

import '../../models/meal.dart';

/// A serving window: when a counter opens and closes.
@immutable
class MealWindow {
  /// Creates a window.
  const MealWindow(this.start, this.end);

  /// Opening time.
  final MinuteOfDay start;

  /// Closing time.
  final MinuteOfDay end;

  /// How long the counter stays open.
  Duration get duration => Duration(
    minutes: end.minutesSinceMidnight - start.minutesSinceMidnight,
  );

  /// True when the window is coherent (opens before it closes).
  bool get isValid => start < end;

  /// Parses a stored window, returning `null` if either bound is unusable.
  static MealWindow? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = MinuteOfDay.tryParse(json['start']);
    final end = MinuteOfDay.tryParse(json['end']);
    if (start == null || end == null || start >= end) return null;
    return MealWindow(start, end);
  }

  /// Serialises for local storage.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'start': start.toJson(),
    'end': end.toJson(),
  };

  /// Returns a copy with the given bounds replaced.
  MealWindow copyWith({MinuteOfDay? start, MinuteOfDay? end}) =>
      MealWindow(start ?? this.start, end ?? this.end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealWindow && start == other.start && end == other.end);

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MealWindow($start-$end)';
}

/// User-overridable meal windows.
///
/// The times shipped in `menu.json` are placeholders. Anything the student
/// overrides in Settings is stored here and applied on top of the document, so
/// correcting a timing never requires editing the data file.
@immutable
class MealTimings {
  /// Creates a timing set from explicit overrides.
  const MealTimings(this.overrides);

  /// No overrides: every slot uses the window from the data document, falling
  /// back to [MealType.defaultStart] / [MealType.defaultEnd].
  static const MealTimings defaults = MealTimings(<MealType, MealWindow>{});

  /// Slots the student has explicitly retimed.
  final Map<MealType, MealWindow> overrides;

  /// True when at least one slot has been retimed.
  bool get hasOverrides => overrides.isNotEmpty;

  /// True when [type] has been retimed.
  bool isOverridden(MealType type) => overrides.containsKey(type);

  /// The window to display for [type] in Settings: the override if present,
  /// otherwise the canonical window for that slot.
  MealWindow windowFor(MealType type) =>
      overrides[type] ?? MealWindow(type.defaultStart, type.defaultEnd);

  /// Applies any override for this meal's slot, leaving the document's own
  /// times in place when the student has not retimed it.
  Meal applyTo(Meal meal) {
    final window = overrides[meal.type];
    if (window == null) return meal;
    return meal.copyWith(startTime: window.start, endTime: window.end);
  }

  /// Applies overrides across a day's meals, preserving serving order.
  List<Meal> applyToAll(Iterable<Meal> meals) =>
      meals.map(applyTo).toList(growable: false);

  /// Returns a copy with [type] retimed to [window].
  MealTimings withWindow(MealType type, MealWindow window) => MealTimings(
    Map<MealType, MealWindow>.unmodifiable(<MealType, MealWindow>{
      ...overrides,
      type: window,
    }),
  );

  /// Returns a copy with the override for [type] removed.
  MealTimings withoutOverride(MealType type) {
    if (!overrides.containsKey(type)) return this;
    final next = Map<MealType, MealWindow>.from(overrides)..remove(type);
    return MealTimings(Map<MealType, MealWindow>.unmodifiable(next));
  }

  /// Returns a copy with every override dropped.
  MealTimings get cleared => defaults;

  /// Parses stored overrides, ignoring anything unrecognised.
  static MealTimings fromJson(Object? json) {
    if (json is! Map) return defaults;
    final parsed = <MealType, MealWindow>{};
    for (final entry in json.entries) {
      final type = MealType.fromJson(entry.key);
      final window = MealWindow.fromJson(entry.value);
      if (type != null && window != null) parsed[type] = window;
    }
    return MealTimings(Map<MealType, MealWindow>.unmodifiable(parsed));
  }

  /// Serialises for local storage.
  Map<String, dynamic> toJson() => <String, dynamic>{
    for (final entry in overrides.entries)
      entry.key.jsonValue: entry.value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealTimings && mapEquals(overrides, other.overrides));

  @override
  int get hashCode => Object.hashAll(
    overrides.entries
        .map((e) => Object.hash(e.key, e.value))
        .toList(growable: false)
      ..sort(),
  );

  @override
  String toString() => 'MealTimings(${overrides.length} overrides)';
}
