import 'package:flutter/foundation.dart';

import 'menu_day.dart';

/// A subscription tier.
///
/// Despite the name, the two entries in the document (`veg-nonveg` and
/// `special`) are not different physical messes — they are the tiers a student
/// can be subscribed to. The choice is a persisted setting.
@immutable
class Mess {
  /// Creates a tier. [days] is sorted by date and made immutable.
  Mess({required this.id, required this.name, required List<MenuDay> days})
    : days = List<MenuDay>.unmodifiable(
        List<MenuDay>.from(days)..sort((a, b) => a.date.compareTo(b.date)),
      );

  /// Stable identifier, e.g. `veg-nonveg`.
  final String id;

  /// Display name, e.g. `Veg & Non-Veg`.
  final String name;

  /// Every day of the month, ascending. Immutable.
  final List<MenuDay> days;

  /// The day matching [date] (ignoring time), or `null` if not covered.
  MenuDay? dayFor(DateTime date) {
    for (final day in days) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }

  /// The first day strictly after [date], or `null` at the end of the month.
  MenuDay? dayAfter(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    for (final day in days) {
      if (day.date.isAfter(target)) return day;
    }
    return null;
  }

  /// Parses one tier, returning `null` when it has no usable identity.
  static Mess? fromJson(Object? json) {
    if (json is! Map) return null;
    final rawId = json['id'];
    if (rawId is! String || rawId.trim().isEmpty) return null;
    final id = rawId.trim();

    final rawName = json['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : id;

    final rawDays = json['days'];
    final days = <MenuDay>[];
    if (rawDays is List) {
      for (final raw in rawDays) {
        final day = MenuDay.fromJson(raw);
        if (day != null) days.add(day);
      }
    }

    return Mess(id: id, name: name, days: days);
  }

  /// Serialises back to the data contract shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'days': days.map((day) => day.toJson()).toList(growable: false),
  };

  /// Returns a copy with the given fields replaced.
  Mess copyWith({String? id, String? name, List<MenuDay>? days}) => Mess(
    id: id ?? this.id,
    name: name ?? this.name,
    days: days ?? this.days,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mess &&
          id == other.id &&
          name == other.name &&
          listEquals(days, other.days));

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(days));

  @override
  String toString() => 'Mess($id, ${days.length} days)';
}
