import 'package:flutter/foundation.dart';

import '../models/meal.dart';
import '../models/meal_status.dart';
import '../models/menu_day.dart';

/// A meal paired with the state the UI should draw it in.
///
/// ViewModels resolve status once and hand the answer down, so no widget ever
/// recomputes time logic during a build.
@immutable
class MealPresentation {
  /// Creates a presentation.
  const MealPresentation({
    required this.meal,
    required this.day,
    required this.status,
  });

  /// The meal, with any timing overrides already applied.
  final Meal meal;

  /// The day it belongs to.
  final MenuDay day;

  /// How it should be drawn.
  final MealStatus status;

  /// Absolute opening instant.
  DateTime get startsAt => meal.startTime.onDay(day.date);

  /// Absolute closing instant.
  DateTime get endsAt => meal.endTime.onDay(day.date);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealPresentation &&
          meal == other.meal &&
          day == other.day &&
          status == other.status);

  @override
  int get hashCode => Object.hash(meal, day, status);

  @override
  String toString() =>
      'MealPresentation(${meal.type.jsonValue} on ${day.dateKey}, $status)';
}
