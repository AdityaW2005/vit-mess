import 'package:flutter/foundation.dart';

import '../../models/meal.dart';
import '../../models/meal_status.dart';
import '../../models/menu_day.dart';
import '../../models/mess.dart';
import '../config/meal_timings.dart';

/// Resolves where [meal] sits relative to [now], using [now]'s own calendar
/// date for the serving window.
///
/// This is the single source of truth for meal state; every screen derives its
/// appearance from it. Pure and side-effect free, so it is directly unit
/// testable.
///
/// * [MealStatus.servingNow] when `startTime <= now <= endTime`
/// * [MealStatus.upcoming] when `now < startTime`
/// * [MealStatus.closed] when `now > endTime`
MealStatus resolveStatus(Meal meal, DateTime now) =>
    resolveStatusOnDay(meal, now, now);

/// Day-aware variant of [resolveStatus], for screens that show a date other
/// than today.
///
/// A meal on a past day is always [MealStatus.closed]; a meal on a future day
/// is always [MealStatus.upcoming].
MealStatus resolveStatusOnDay(Meal meal, DateTime day, DateTime now) {
  final start = meal.startTime.onDay(day);
  final end = meal.endTime.onDay(day);
  if (now.isBefore(start)) return MealStatus.upcoming;
  if (now.isAfter(end)) return MealStatus.closed;
  return MealStatus.servingNow;
}

/// The meal currently being served on [day], or `null` if none is.
///
/// Exactly one meal can ever be serving: if user timing overrides make two
/// windows overlap, the earliest-starting one wins.
Meal? servingNowOn(List<Meal> meals, DateTime day, DateTime now) {
  Meal? winner;
  for (final meal in meals) {
    if (resolveStatusOnDay(meal, day, now) != MealStatus.servingNow) continue;
    if (winner == null || meal.startTime < winner.startTime) winner = meal;
  }
  return winner;
}

/// The earliest meal on [day] that has not opened yet, or `null` when the day
/// is done.
Meal? nextUpcomingOn(List<Meal> meals, DateTime day, DateTime now) {
  Meal? winner;
  for (final meal in meals) {
    if (resolveStatusOnDay(meal, day, now) != MealStatus.upcoming) continue;
    if (winner == null || meal.startTime < winner.startTime) winner = meal;
  }
  return winner;
}

/// The meal the hero card should be showing, together with everything the UI
/// needs to describe and count down to it.
@immutable
class MealFocus {
  /// Creates a focus.
  const MealFocus({
    required this.day,
    required this.meal,
    required this.status,
    required this.startsAt,
    required this.endsAt,
  });

  /// The day the meal belongs to.
  final MenuDay day;

  /// The meal itself, with any timing overrides already applied.
  final Meal meal;

  /// Either [MealStatus.servingNow] or [MealStatus.upcoming] — a focus is
  /// never on a closed meal.
  final MealStatus status;

  /// Absolute opening instant, in device-local time.
  final DateTime startsAt;

  /// Absolute closing instant, in device-local time.
  final DateTime endsAt;

  /// True when the counter is open right now.
  bool get isServingNow => status.isServing;

  /// The instant the countdown is running towards: closing time while
  /// serving, opening time otherwise.
  DateTime get target => isServingNow ? endsAt : startsAt;

  /// Time left until [target], floored at zero.
  Duration remaining(DateTime now) {
    final delta = target.difference(now);
    return delta.isNegative ? Duration.zero : delta;
  }

  /// Whole days between [now]'s date and this meal's date.
  int daysFrom(DateTime now) => daysBetween(now, day.date);

  /// True when this focus has rolled over to a later calendar day.
  bool isOnLaterDay(DateTime now) => daysFrom(now) > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealFocus &&
          day == other.day &&
          meal == other.meal &&
          status == other.status &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt);

  @override
  int get hashCode => Object.hash(day, meal, status, startsAt, endsAt);

  @override
  String toString() =>
      'MealFocus(${meal.type.jsonValue} on ${day.dateKey}, $status)';
}

/// Picks the meal the home screen should lead with.
///
/// Order of preference:
/// 1. a meal being served right now,
/// 2. the next meal still to open today,
/// 3. the first meal of the next day the document covers — which is how the
///    after-dinner rollover is handled.
///
/// Returns `null` when the month runs out, i.e. it is after dinner on the last
/// day the document covers. Callers render the "next month isn't up yet"
/// state in that case.
///
/// [timings] is applied to every meal considered, so user overrides affect the
/// choice as well as the display.
MealFocus? resolveFocus(
  Mess mess,
  DateTime now, [
  MealTimings timings = MealTimings.defaults,
]) {
  final today = mess.dayFor(now);

  if (today != null) {
    final meals = timings.applyToAll(today.meals);

    final serving = servingNowOn(meals, today.date, now);
    if (serving != null) {
      return MealFocus(
        day: today,
        meal: serving,
        status: MealStatus.servingNow,
        startsAt: serving.startTime.onDay(today.date),
        endsAt: serving.endTime.onDay(today.date),
      );
    }

    final upcoming = nextUpcomingOn(meals, today.date, now);
    if (upcoming != null) {
      return MealFocus(
        day: today,
        meal: upcoming,
        status: MealStatus.upcoming,
        startsAt: upcoming.startTime.onDay(today.date),
        endsAt: upcoming.endTime.onDay(today.date),
      );
    }
  }

  // Everything today is closed (or today is not covered): roll forward to the
  // first meal of the next covered day. Returns null on the last day of the
  // month, where no next day exists.
  final nextDay = mess.dayAfter(now);
  if (nextDay == null) return null;

  final nextMeals = timings.applyToAll(nextDay.meals);
  if (nextMeals.isEmpty) return null;

  final first = nextMeals.reduce(
    (a, b) => a.startTime <= b.startTime ? a : b,
  );
  return MealFocus(
    day: nextDay,
    meal: first,
    status: MealStatus.upcoming,
    startsAt: first.startTime.onDay(nextDay.date),
    endsAt: first.endTime.onDay(nextDay.date),
  );
}

/// Whole calendar days from [from] to [to], ignoring the time of day.
///
/// Negative when [to] is in the past. Computed on normalised dates so daylight
/// saving shifts cannot produce an off-by-one.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// True when [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Strips the time component, returning local midnight.
DateTime startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// `yyyy-MM-dd` key for [date].
String dateKeyOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
