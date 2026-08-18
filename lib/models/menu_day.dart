import 'package:flutter/foundation.dart';

import 'meal.dart';

/// One calendar day of service.
///
/// The document is a flat, date-keyed list covering every day of the month, so
/// looking up a day is a direct match — there is no weekday-rotation logic.
@immutable
class MenuDay {
  /// Creates a day. [meals] is sorted into serving order and made immutable.
  MenuDay({required this.date, required this.weekday, required List<Meal> meals})
    : meals = List<Meal>.unmodifiable(
        List<Meal>.from(meals)
          ..sort((a, b) => a.type.index.compareTo(b.type.index)),
      );

  /// Local calendar date, normalised to midnight.
  final DateTime date;

  /// Short weekday label straight from the document (e.g. `Mon`).
  final String weekday;

  /// The four meals, in serving order. Immutable.
  final List<Meal> meals;

  /// `yyyy-MM-dd` key for this day.
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// The meal for [type], or `null` if the document omits it.
  Meal? mealFor(MealType type) {
    for (final meal in meals) {
      if (meal.type == type) return meal;
    }
    return null;
  }

  /// Every dish served across the day.
  int get totalItemCount =>
      meals.fold<int>(0, (sum, meal) => sum + meal.itemCount);

  /// Parses one day, returning `null` when the date is missing or unusable.
  ///
  /// Meals that fail to parse are dropped rather than failing the whole day.
  static MenuDay? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = _parseDate(json['date']);
    if (date == null) return null;

    final rawMeals = json['meals'];
    final meals = <Meal>[];
    if (rawMeals is List) {
      for (final raw in rawMeals) {
        final meal = Meal.fromJson(raw);
        if (meal != null) meals.add(meal);
      }
    }

    final rawWeekday = json['weekday'];
    final weekday = rawWeekday is String && rawWeekday.trim().isNotEmpty
        ? rawWeekday.trim()
        : _weekdayLabels[date.weekday - 1];

    return MenuDay(date: date, weekday: weekday, meals: meals);
  }

  /// Serialises back to the data contract shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': dateKey,
    'weekday': weekday,
    'meals': meals.map((meal) => meal.toJson()).toList(growable: false),
  };

  /// Returns a copy with the given fields replaced.
  MenuDay copyWith({DateTime? date, String? weekday, List<Meal>? meals}) =>
      MenuDay(
        date: date ?? this.date,
        weekday: weekday ?? this.weekday,
        meals: meals ?? this.meals,
      );

  static const List<String> _weekdayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    // Normalise to local midnight so date comparisons are exact.
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuDay &&
          date == other.date &&
          weekday == other.weekday &&
          listEquals(meals, other.meals));

  @override
  int get hashCode => Object.hash(date, weekday, Object.hashAll(meals));

  @override
  String toString() => 'MenuDay($dateKey, ${meals.length} meals)';
}
