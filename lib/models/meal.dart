import 'package:flutter/foundation.dart';

import 'meal_item.dart';

/// A wall-clock time of day, stored as minutes since midnight so it is always
/// compared numerically and never as a string.
@immutable
class MinuteOfDay implements Comparable<MinuteOfDay> {
  /// Creates a time from [hour] (0-23) and [minute] (0-59).
  const MinuteOfDay(this.hour, this.minute);

  /// Creates a time from raw [minutes] since midnight, clamped to one day.
  factory MinuteOfDay.fromMinutes(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    return MinuteOfDay(clamped ~/ 60, clamped % 60);
  }

  /// Hour in 24-hour form.
  final int hour;

  /// Minute within the hour.
  final int minute;

  /// Minutes elapsed since midnight — the comparable form.
  int get minutesSinceMidnight => hour * 60 + minute;

  /// Parses an `"HH:mm"` contract string, returning `null` when it is missing
  /// or malformed rather than throwing.
  static MinuteOfDay? tryParse(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return MinuteOfDay(hour, minute);
  }

  /// Formats back to the `"HH:mm"` contract form.
  String toJson() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Combines this time with the calendar date of [day], in device-local time.
  DateTime onDay(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  @override
  int compareTo(MinuteOfDay other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  /// True when this time is strictly before [other].
  bool operator <(MinuteOfDay other) =>
      minutesSinceMidnight < other.minutesSinceMidnight;

  /// True when this time is at or before [other].
  bool operator <=(MinuteOfDay other) =>
      minutesSinceMidnight <= other.minutesSinceMidnight;

  /// True when this time is strictly after [other].
  bool operator >(MinuteOfDay other) =>
      minutesSinceMidnight > other.minutesSinceMidnight;

  /// True when this time is at or after [other].
  bool operator >=(MinuteOfDay other) =>
      minutesSinceMidnight >= other.minutesSinceMidnight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MinuteOfDay &&
          hour == other.hour &&
          minute == other.minute);

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => toJson();
}

/// The four fixed meal slots, in serving order.
///
/// Each carries the canonical window from the data contract. `MealTimings`
/// treats these as its defaults, so the fallback lives in exactly one place.
enum MealType {
  /// 07:00 – 09:00 Tuesday to Saturday. Sunday and Monday run 15 minutes
  /// later — see [startOn].
  breakfast('breakfast', MinuteOfDay(7, 0), MinuteOfDay(9, 0)),

  /// 12:30 – 14:15.
  lunch('lunch', MinuteOfDay(12, 30), MinuteOfDay(14, 15)),

  /// 16:30 – 18:15.
  snacks('snacks', MinuteOfDay(16, 30), MinuteOfDay(18, 15)),

  /// 19:15 – 21:00.
  dinner('dinner', MinuteOfDay(19, 15), MinuteOfDay(21, 0));

  const MealType(this.jsonValue, this.defaultStart, this.defaultEnd);

  /// The literal used in the data contract.
  final String jsonValue;

  /// Default opening time before any user override.
  final MinuteOfDay defaultStart;

  /// Default closing time before any user override.
  final MinuteOfDay defaultEnd;

  /// The canonical opening time on [date].
  ///
  /// Breakfast is the one slot the mess runs on two clocks: 7:00 Tuesday to
  /// Saturday, and 7:15 on Sunday and Monday. Every other slot keeps the same
  /// window all week.
  MinuteOfDay startOn(DateTime date) => _windowOn(date).$1;

  /// The canonical closing time on [date].
  MinuteOfDay endOn(DateTime date) => _windowOn(date).$2;

  /// True when [date] falls on a day this slot runs to a different clock.
  bool hasWeekdayException(DateTime date) =>
      startOn(date) != defaultStart || endOn(date) != defaultEnd;

  /// True when this slot runs to more than one clock across the week.
  bool get hasWeekdayVariants => this == MealType.breakfast;

  (MinuteOfDay, MinuteOfDay) _windowOn(DateTime date) {
    if (this == MealType.breakfast && _isLateBreakfastDay(date)) {
      return (lateBreakfastStart, lateBreakfastEnd);
    }
    return (defaultStart, defaultEnd);
  }

  static bool _isLateBreakfastDay(DateTime date) =>
      date.weekday == DateTime.sunday || date.weekday == DateTime.monday;

  /// Breakfast opening time on Sunday and Monday.
  static const MinuteOfDay lateBreakfastStart = MinuteOfDay(7, 15);

  /// Breakfast closing time on Sunday and Monday.
  static const MinuteOfDay lateBreakfastEnd = MinuteOfDay(9, 15);

  /// Parses a contract value, returning `null` when unrecognised.
  static MealType? fromJson(Object? raw) {
    if (raw is! String) return null;
    final normalized = raw.trim().toLowerCase();
    for (final type in MealType.values) {
      if (type.jsonValue == normalized) return type;
    }
    return null;
  }
}

/// One serving window and the dishes offered in it.
@immutable
class Meal {
  /// Creates a meal. [items] is copied into an unmodifiable list.
  Meal({
    required this.type,
    required this.startTime,
    required this.endTime,
    required List<MealItem> items,
  }) : items = List<MealItem>.unmodifiable(items);

  /// Which of the four slots this is.
  final MealType type;

  /// When the counter opens.
  final MinuteOfDay startTime;

  /// When the counter closes.
  final MinuteOfDay endTime;

  /// Dishes served, in menu order. Immutable.
  final List<MealItem> items;

  /// Items that stand alone (no veg/non-veg pairing).
  List<MealItem> get plainItems =>
      items.where((item) => !item.isPaired).toList(growable: false);

  /// Paired alternatives, grouped two-by-two in menu order.
  ///
  /// The contract lists a non-veg option immediately followed by its veg
  /// counterpart; an unmatched trailing item is returned as a pair of one so
  /// nothing is silently dropped.
  List<List<MealItem>> get variantPairs {
    final paired = items.where((item) => item.isPaired).toList(growable: false);
    final pairs = <List<MealItem>>[];
    for (var i = 0; i < paired.length; i += 2) {
      final end = (i + 2 <= paired.length) ? i + 2 : paired.length;
      pairs.add(List<MealItem>.unmodifiable(paired.sublist(i, end)));
    }
    return List<List<MealItem>>.unmodifiable(pairs);
  }

  /// Total dish count, used for layout decisions and previews.
  int get itemCount => items.length;

  /// Parses one meal, returning `null` when the slot cannot be identified.
  ///
  /// Missing or malformed times fall back to the slot's canonical window, and
  /// unparseable items are dropped, so a partially broken document still
  /// renders.
  static Meal? fromJson(Object? json) {
    if (json is! Map) return null;
    final type = MealType.fromJson(json['type']);
    if (type == null) return null;

    final start = MinuteOfDay.tryParse(json['startTime']) ?? type.defaultStart;
    var end = MinuteOfDay.tryParse(json['endTime']) ?? type.defaultEnd;
    // A window that ends before it starts is unusable; fall back rather than
    // letting every status query report `closed`.
    if (end <= start) end = type.defaultEnd;

    final rawItems = json['items'];
    final items = <MealItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        final item = MealItem.fromJson(raw);
        if (item != null) items.add(item);
      }
    }

    return Meal(type: type, startTime: start, endTime: end, items: items);
  }

  /// Serialises back to the data contract shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.jsonValue,
    'startTime': startTime.toJson(),
    'endTime': endTime.toJson(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };

  /// Returns a copy with the given fields replaced.
  Meal copyWith({
    MealType? type,
    MinuteOfDay? startTime,
    MinuteOfDay? endTime,
    List<MealItem>? items,
  }) => Meal(
    type: type ?? this.type,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    items: items ?? this.items,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meal &&
          type == other.type &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          listEquals(items, other.items));

  @override
  int get hashCode =>
      Object.hash(type, startTime, endTime, Object.hashAll(items));

  @override
  String toString() =>
      'Meal(${type.jsonValue} $startTime-$endTime, ${items.length} items)';
}
