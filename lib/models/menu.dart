import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'mess.dart';

/// The whole monthly document.
@immutable
class Menu {
  /// Creates a menu. [messes] is made immutable.
  Menu({
    required this.schemaVersion,
    required this.month,
    required this.campus,
    required List<Mess> messes,
  }) : messes = List<Mess>.unmodifiable(messes);

  /// Contract version the document was written against.
  final int schemaVersion;

  /// `yyyy-MM` the document covers.
  final String month;

  /// Campus the document belongs to.
  final String campus;

  /// Subscription tiers. Immutable.
  final List<Mess> messes;

  /// The tier with [id], or `null` when the document does not carry it.
  Mess? messById(String id) {
    for (final mess in messes) {
      if (mess.id == id) return mess;
    }
    return null;
  }

  /// The tier with [id], falling back to the first available tier so the UI
  /// always has something to render even after an id is retired.
  Mess? messByIdOrFirst(String id) =>
      messById(id) ?? (messes.isEmpty ? null : messes.first);

  /// True when [month] matches the month containing [now].
  bool coversMonthOf(DateTime now) => month == monthKeyOf(now);

  /// `yyyy-MM` key for [date].
  static String monthKeyOf(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';

  /// Parses a decoded document, returning `null` when it is not a usable menu.
  ///
  /// Missing scalar fields degrade to sensible defaults; only a completely
  /// unusable shape (not a map, or no parseable tier) yields `null`.
  static Menu? fromJson(Object? json) {
    if (json is! Map) return null;

    final rawMesses = json['messes'];
    final messes = <Mess>[];
    if (rawMesses is List) {
      for (final raw in rawMesses) {
        final mess = Mess.fromJson(raw);
        if (mess != null) messes.add(mess);
      }
    }
    if (messes.isEmpty) return null;

    final rawVersion = json['schemaVersion'];
    final schemaVersion = rawVersion is int
        ? rawVersion
        : (rawVersion is String ? int.tryParse(rawVersion) ?? 1 : 1);

    final rawMonth = json['month'];
    final month = rawMonth is String && rawMonth.trim().isNotEmpty
        ? rawMonth.trim()
        : _inferMonth(messes);

    final rawCampus = json['campus'];
    final campus = rawCampus is String && rawCampus.trim().isNotEmpty
        ? rawCampus.trim()
        : '';

    return Menu(
      schemaVersion: schemaVersion,
      month: month,
      campus: campus,
      messes: messes,
    );
  }

  /// Parses a raw JSON string. Returns `null` on malformed JSON.
  static Menu? decode(String source) {
    try {
      return Menu.fromJson(jsonDecode(source));
    } on FormatException {
      return null;
    }
  }

  /// Serialises back to the data contract shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'month': month,
    'campus': campus,
    'messes': messes.map((mess) => mess.toJson()).toList(growable: false),
  };

  /// Serialises to a JSON string suitable for the cache.
  String encode() => jsonEncode(toJson());

  /// Returns a copy with the given fields replaced.
  Menu copyWith({
    int? schemaVersion,
    String? month,
    String? campus,
    List<Mess>? messes,
  }) => Menu(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    month: month ?? this.month,
    campus: campus ?? this.campus,
    messes: messes ?? this.messes,
  );

  /// Falls back to the month of the earliest day present.
  static String _inferMonth(List<Mess> messes) {
    for (final mess in messes) {
      if (mess.days.isNotEmpty) return monthKeyOf(mess.days.first.date);
    }
    return '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Menu &&
          schemaVersion == other.schemaVersion &&
          month == other.month &&
          campus == other.campus &&
          listEquals(messes, other.messes));

  @override
  int get hashCode =>
      Object.hash(schemaVersion, month, campus, Object.hashAll(messes));

  @override
  String toString() => 'Menu($month, $campus, ${messes.length} messes)';
}

/// Where the menu currently in hand came from.
enum MenuSource {
  /// Read from local storage.
  cache('cache'),

  /// Freshly downloaded.
  network('network'),

  /// Hand-imported by the student.
  imported('imported');

  const MenuSource(this.storageValue);

  /// Persisted form.
  final String storageValue;

  /// Parses a persisted value, defaulting to [MenuSource.cache].
  static MenuSource fromStorage(Object? raw) {
    if (raw is! String) return MenuSource.cache;
    for (final source in MenuSource.values) {
      if (source.storageValue == raw) return source;
    }
    return MenuSource.cache;
  }
}

/// A menu plus the provenance the UI needs to explain itself.
@immutable
class MenuSnapshot {
  /// Creates a snapshot.
  const MenuSnapshot({
    required this.menu,
    required this.source,
    this.lastUpdated,
  });

  /// The document.
  final Menu menu;

  /// Where it came from.
  final MenuSource source;

  /// When it was last successfully fetched or imported.
  final DateTime? lastUpdated;

  /// True when the document does not cover the month containing [now], which
  /// means the UI should be asking for a refresh.
  bool isStaleFor(DateTime now) => !menu.coversMonthOf(now);

  /// Returns a copy with the given fields replaced.
  MenuSnapshot copyWith({
    Menu? menu,
    MenuSource? source,
    DateTime? lastUpdated,
  }) => MenuSnapshot(
    menu: menu ?? this.menu,
    source: source ?? this.source,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuSnapshot &&
          menu == other.menu &&
          source == other.source &&
          lastUpdated == other.lastUpdated);

  @override
  int get hashCode => Object.hash(menu, source, lastUpdated);

  @override
  String toString() => 'MenuSnapshot(${menu.month}, $source)';
}
