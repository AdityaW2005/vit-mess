import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/models/meal.dart';
import 'package:vit_mess/models/meal_item.dart';
import 'package:vit_mess/services/excel_menu_parser.dart';

/// Parses the actual workbook the VIT-AP mess office publishes.
///
/// This is the format students really receive: a `Day` column whose merged
/// cells carry a weekday plus the dates that repeat it, one dish per row under
/// each meal column, and a block of service instructions after the last day.
void main() {
  const parser = ExcelMenuParser();

  final fixture = File('test/fixtures/vitap_august_2026.xlsx');
  if (!fixture.existsSync()) {
    // The fixture is a real published menu and is optional: drop it in to run
    // these checks against the genuine article. The rotation format itself is
    // covered synthetically in excel_menu_parser_test.dart either way.
    test('real workbook fixture is absent — skipping', () {}, skip: true);
    return;
  }
  final bytes = fixture.readAsBytesSync();

  test('parses both tiers for the whole month', () {
    final menu = parser.parse(bytes, now: DateTime(2026, 8, 18));

    expect(menu.month, '2026-08');
    expect(menu.messes, hasLength(2));
    expect(menu.messById('veg-nonveg'), isNotNull);
    expect(menu.messById('special'), isNotNull);

    for (final mess in menu.messes) {
      expect(mess.days, hasLength(31), reason: mess.id);
      expect(mess.days.first.date, DateTime(2026, 8, 1));
      expect(mess.days.last.date, DateTime(2026, 8, 31));
    }
  });

  test('recovers the year from the weekday labels alone', () {
    // The title says "AUGUST" with no year; 1, 15 and 29 are Saturdays only
    // in 2026.
    final menu = parser.parse(bytes, now: DateTime(2026, 8, 18));
    final first = menu.messById('veg-nonveg')!.days.first;
    expect(first.date.year, 2026);
    expect(first.weekday, 'Sat');
  });

  test('every day carries all four meals with dishes', () {
    final menu = parser.parse(bytes, now: DateTime(2026, 8, 18));

    for (final mess in menu.messes) {
      for (final day in mess.days) {
        expect(day.meals, hasLength(4), reason: '${mess.id} ${day.dateKey}');
        for (final meal in day.meals) {
          expect(
            meal.items,
            isNotEmpty,
            reason: '${mess.id} ${day.dateKey} ${meal.type.jsonValue}',
          );
        }
      }
    }
  });

  test('repeats a rotation day across each of its dates', () {
    final menu = parser.parse(bytes, now: DateTime(2026, 8, 18));
    final mess = menu.messById('veg-nonveg')!;

    // "Sat 1, 15, 29" — the same menu on all three.
    final first = mess.dayFor(DateTime(2026, 8, 1))!;
    final second = mess.dayFor(DateTime(2026, 8, 15))!;
    final third = mess.dayFor(DateTime(2026, 8, 29))!;

    expect(
      second.mealFor(MealType.breakfast)!.items,
      first.mealFor(MealType.breakfast)!.items,
    );
    expect(
      third.mealFor(MealType.dinner)!.items,
      first.mealFor(MealType.dinner)!.items,
    );
  });

  test('reads real dishes into the right meals', () {
    final menu = parser.parse(bytes, now: DateTime(2026, 8, 18));
    final day = menu.messById('veg-nonveg')!.dayFor(DateTime(2026, 8, 1))!;

    expect(
      day.mealFor(MealType.breakfast)!.items.map((item) => item.name),
      contains('Masala Ghee Roast Dosa'),
    );
    expect(
      day.mealFor(MealType.lunch)!.items.map((item) => item.name),
      contains('Mudda Pappu'),
    );
    expect(
      day.mealFor(MealType.snacks)!.items.map((item) => item.name),
      contains('Punugulu 10 Pcs Std Size'),
    );
    expect(
      day.mealFor(MealType.dinner)!.items.map((item) => item.name),
      contains('Mango Dal'),
    );
  });

  test('turns inline (Non-Veg)/(Veg) markers into a pair', () {
    final menu = parser.parse(bytes, now: DateTime(2026, 8, 18));
    // Mon 3, 17, 31 — dinner offers Telangana Chicken Curry or Achari Paneer.
    final dinner = menu
        .messById('veg-nonveg')!
        .dayFor(DateTime(2026, 8, 3))!
        .mealFor(MealType.dinner)!;

    final names = dinner.items.map((item) => item.name).toList();
    expect(names, contains('Telangana Chicken Curry'));
    expect(names, contains('Achari Paneer'));

    final chicken = dinner.items.firstWhere(
      (item) => item.name == 'Telangana Chicken Curry',
    );
    final paneer = dinner.items.firstWhere(
      (item) => item.name == 'Achari Paneer',
    );
    expect(chicken.variant, ItemVariant.nonVeg);
    expect(paneer.variant, ItemVariant.veg);

    // Adjacent, which is what the UI folds into a single "or" tile.
    expect(
      dinner.items.indexOf(paneer) - dinner.items.indexOf(chicken),
      1,
    );
    expect(dinner.variantPairs, isNotEmpty);
  });

  test('keeps slash choices as one dish rather than inventing dishes', () {
    final menu = parser.parse(bytes, now: DateTime(2026, 8, 18));
    final breakfast = menu
        .messById('veg-nonveg')!
        .dayFor(DateTime(2026, 8, 1))!
        .mealFor(MealType.breakfast)!;

    expect(
      breakfast.items.map((item) => item.name),
      contains('Tea/Coffee/Milk'),
    );
  });

  test('excludes the trailing service instructions', () {
    final menu = parser.parse(bytes, now: DateTime(2026, 8, 18));

    for (final mess in menu.messes) {
      for (final day in mess.days) {
        for (final meal in day.meals) {
          for (final item in meal.items) {
            expect(
              item.name.toLowerCase(),
              isNot(contains('instruction')),
              reason: '${day.dateKey} ${meal.type.jsonValue}',
            );
            expect(item.name.length, lessThan(120), reason: item.name);
          }
        }
      }
    }
  });
}
