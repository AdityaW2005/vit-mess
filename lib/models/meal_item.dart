import 'package:flutter/foundation.dart';

/// The veg / non-veg marking on a single item.
///
/// A non-null variant means the item is one half of a *paired alternative*:
/// the mess serves either the veg or the non-veg option depending on tier.
enum ItemVariant {
  /// Green-dot item.
  veg('veg'),

  /// Brown-dot item.
  nonVeg('nonveg');

  const ItemVariant(this.jsonValue);

  /// The literal used in the data contract.
  final String jsonValue;

  /// Parses a contract value, returning `null` for `null` or anything
  /// unrecognised rather than throwing.
  static ItemVariant? fromJson(Object? raw) {
    if (raw is! String) return null;
    final normalized = raw.trim().toLowerCase();
    for (final variant in ItemVariant.values) {
      if (variant.jsonValue == normalized) return variant;
    }
    // Tolerate the hyphenated spelling seen in some hand-edited files.
    if (normalized == 'non-veg' || normalized == 'non_veg') {
      return ItemVariant.nonVeg;
    }
    return null;
  }
}

/// One dish on a meal's list.
@immutable
class MealItem {
  /// Creates an item.
  const MealItem({required this.name, this.variant});

  /// Dish name as printed on the mess board.
  final String name;

  /// `null` for a plain item; set when the item is half of a paired
  /// alternative.
  final ItemVariant? variant;

  /// True when this item participates in a veg/non-veg pair.
  bool get isPaired => variant != null;

  /// Parses one item, returning `null` when there is nothing renderable.
  ///
  /// Never throws: a malformed entry is simply dropped by the caller.
  static MealItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final rawName = json['name'];
    if (rawName is! String) return null;
    final name = rawName.trim();
    if (name.isEmpty) return null;
    return MealItem(name: name, variant: ItemVariant.fromJson(json['variant']));
  }

  /// Serialises back to the data contract shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'variant': variant?.jsonValue,
  };

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass [clearVariant] to explicitly drop an existing variant, since a
  /// `null` [variant] argument is indistinguishable from "unchanged".
  MealItem copyWith({
    String? name,
    ItemVariant? variant,
    bool clearVariant = false,
  }) => MealItem(
    name: name ?? this.name,
    variant: clearVariant ? null : (variant ?? this.variant),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealItem && name == other.name && variant == other.variant);

  @override
  int get hashCode => Object.hash(name, variant);

  @override
  String toString() => 'MealItem($name, ${variant?.jsonValue})';
}
