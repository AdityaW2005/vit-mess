import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/models/meal.dart';
import 'package:vit_mess/models/meal_item.dart';
import 'package:vit_mess/models/menu.dart';
import 'package:vit_mess/services/excel_menu_parser.dart';

import 'excel_helpers.dart';

void main() {
  const parser = ExcelMenuParser();

  group('grid layout', () {
    test('reads days, meals and dishes from meal columns', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Veg & Non-Veg': gridSheet(),
        }),
      );

      expect(menu.messes, hasLength(1));
      final mess = menu.messes.single;
      expect(mess.id, 'veg-nonveg');
      expect(mess.name, 'Veg & Non-Veg');
      expect(mess.days, hasLength(2));

      final day = mess.dayFor(DateTime(2026, 8, 17))!;
      expect(day.weekday, 'Mon');
      expect(day.meals, hasLength(4));

      final breakfast = day.mealFor(MealType.breakfast)!;
      expect(
        breakfast.items.map((item) => item.name),
        <String>['Carrot Idly', 'Medhu Vada'],
      );
    });

    test('pulls inline variant markers off the dish name', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{'Sheet1': gridSheet()}),
      );
      final lunch = menu.messes.single
          .dayFor(DateTime(2026, 8, 17))!
          .mealFor(MealType.lunch)!;

      expect(lunch.items[0].name, 'Steamed Rice');
      expect(lunch.items[0].variant, isNull);
      expect(lunch.items[1].name, 'Chicken Curry');
      expect(lunch.items[1].variant, ItemVariant.nonVeg);
      expect(lunch.items[2].name, 'Paneer Butter Masala');
      expect(lunch.items[2].variant, ItemVariant.veg);
      // The pair stays adjacent, which is what the UI folds into one tile.
      expect(lunch.variantPairs, hasLength(1));
    });

    test('applies the canonical serving windows', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{'Sheet1': gridSheet()}),
      );
      final day = menu.messes.single.dayFor(DateTime(2026, 8, 17))!;

      expect(day.mealFor(MealType.breakfast)!.startTime, const MinuteOfDay(7, 15));
      expect(day.mealFor(MealType.breakfast)!.endTime, const MinuteOfDay(9, 0));
      expect(day.mealFor(MealType.lunch)!.startTime, const MinuteOfDay(12, 30));
      expect(day.mealFor(MealType.lunch)!.endTime, const MinuteOfDay(14, 15));
      expect(day.mealFor(MealType.snacks)!.startTime, const MinuteOfDay(16, 45));
      expect(day.mealFor(MealType.snacks)!.endTime, const MinuteOfDay(18, 15));
      expect(day.mealFor(MealType.dinner)!.startTime, const MinuteOfDay(19, 15));
      expect(day.mealFor(MealType.dinner)!.endTime, const MinuteOfDay(21, 0));
    });

    test('accepts newline separated cells and dd/MM/yyyy dates', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Sheet1': <List<String>>[
            <String>['Date', 'Breakfast'],
            <String>['17/08/2026', 'Idly\nVada\nPongal'],
          ],
        }),
      );
      final day = menu.messes.single.dayFor(DateTime(2026, 8, 17))!;
      expect(
        day.mealFor(MealType.breakfast)!.items.map((item) => item.name),
        <String>['Idly', 'Vada', 'Pongal'],
      );
    });

    test('recognises loose meal column headings', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Sheet1': <List<String>>[
            <String>['Date', 'BREAKFAST ', 'Evening Snacks', 'Supper'],
            <String>['2026-08-17', 'Idly', 'Tea', 'Chapathi'],
          ],
        }),
      );
      final day = menu.messes.single.dayFor(DateTime(2026, 8, 17))!;
      expect(day.mealFor(MealType.breakfast), isNotNull);
      expect(day.mealFor(MealType.snacks), isNotNull);
      expect(day.mealFor(MealType.dinner), isNotNull);
      expect(day.mealFor(MealType.lunch), isNull);
    });

    test('skips title rows above the header', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Sheet1': <List<String>>[
            <String>['VIT-AP Mess Menu — August 2026'],
            <String>[],
            <String>['Date', 'Lunch'],
            <String>['2026-08-17', 'Rice'],
          ],
        }),
      );
      expect(menu.messes.single.days, hasLength(1));
    });

    test('carries a blank date down from the row above', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Sheet1': <List<String>>[
            <String>['Date', 'Lunch'],
            <String>['2026-08-17', 'Rice'],
            <String>['', 'Sambar'],
          ],
        }),
      );
      final lunch = menu.messes.single
          .dayFor(DateTime(2026, 8, 17))!
          .mealFor(MealType.lunch)!;
      expect(lunch.items.map((item) => item.name), <String>['Rice', 'Sambar']);
    });
  });

  group('long layout', () {
    test('reads one dish per row with an explicit variant column', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{'Special': longSheet()}),
      );

      final mess = menu.messes.single;
      expect(mess.id, 'special');
      expect(mess.name, 'Special');

      final day = mess.dayFor(DateTime(2026, 8, 17))!;
      expect(day.meals, hasLength(4));

      final lunch = day.mealFor(MealType.lunch)!;
      expect(lunch.items, hasLength(3));
      expect(lunch.items[1].variant, ItemVariant.nonVeg);
      expect(lunch.items[2].variant, ItemVariant.veg);
    });

    test('honours optional start and end columns', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Sheet1': <List<String>>[
            <String>['Date', 'Meal', 'Item', 'Start', 'End'],
            <String>['2026-08-17', 'Lunch', 'Rice', '12:45', '14:00'],
          ],
        }),
      );
      final lunch = menu.messes.single
          .dayFor(DateTime(2026, 8, 17))!
          .mealFor(MealType.lunch)!;
      expect(lunch.startTime, const MinuteOfDay(12, 45));
      expect(lunch.endTime, const MinuteOfDay(14, 0));
    });

    test('a Mess column splits one sheet into tiers', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Sheet1': <List<String>>[
            <String>['Date', 'Mess', 'Meal', 'Item'],
            <String>['2026-08-17', 'Veg & Non-Veg', 'Lunch', 'Rice'],
            <String>['2026-08-17', 'Special', 'Lunch', 'Biryani'],
          ],
        }),
      );

      expect(menu.messes, hasLength(2));
      expect(
        menu.messes.map((mess) => mess.id),
        containsAll(<String>['veg-nonveg', 'special']),
      );
      expect(
        menu
            .messById('special')!
            .dayFor(DateTime(2026, 8, 17))!
            .mealFor(MealType.lunch)!
            .items
            .single
            .name,
        'Biryani',
      );
    });

    test('carries a blank meal down from the row above', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Sheet1': <List<String>>[
            <String>['Date', 'Meal', 'Item'],
            <String>['2026-08-17', 'Dinner', 'Chapathi'],
            <String>['', '', 'Dal Tadka'],
          ],
        }),
      );
      final dinner = menu.messes.single
          .dayFor(DateTime(2026, 8, 17))!
          .mealFor(MealType.dinner)!;
      expect(
        dinner.items.map((item) => item.name),
        <String>['Chapathi', 'Dal Tadka'],
      );
    });
  });

  group('multiple sheets', () {
    test('each worksheet becomes a subscription tier', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Veg & Non-Veg': gridSheet(),
          'Special': gridSheet(),
        }),
      );

      expect(menu.messes, hasLength(2));
      expect(menu.messById('veg-nonveg'), isNotNull);
      expect(menu.messById('special'), isNotNull);
    });

    test('an unreadable sheet does not sink the readable one', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{
          'Notes': <List<String>>[
            <String>['Contact the mess office for changes'],
          ],
          'Special': gridSheet(),
        }),
      );

      expect(menu.messes, hasLength(1));
      expect(menu.messes.single.id, 'special');
    });
  });

  group('document metadata', () {
    test('infers the month from the dates present', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{'Sheet1': gridSheet()}),
      );
      expect(menu.month, '2026-08');
      expect(menu.campus, 'VIT-AP');
      expect(menu.schemaVersion, 1);
    });

    test('round-trips through the JSON cache format', () {
      final menu = parser.parse(
        buildWorkbook(<String, List<List<String>>>{'Sheet1': gridSheet()}),
      );
      expect(Menu.decode(menu.encode()), menu);
    });
  });

  group('rejections', () {
    test('throws when the workbook has no date column', () {
      expect(
        () => parser.parse(
          buildWorkbook(<String, List<List<String>>>{
            'Sheet1': <List<String>>[
              <String>['Day', 'Food'],
              <String>['Monday', 'Idly'],
            ],
          }),
        ),
        throwsA(isA<ExcelParseException>()),
      );
    });

    test('throws when a dated sheet has no meal columns', () {
      expect(
        () => parser.parse(
          buildWorkbook(<String, List<List<String>>>{
            'Sheet1': <List<String>>[
              <String>['Date', 'Notes'],
              <String>['2026-08-17', 'Holiday'],
            ],
          }),
        ),
        throwsA(isA<ExcelParseException>()),
      );
    });

    test('throws on bytes that are not a workbook', () {
      expect(
        () => parser.parse(<int>[1, 2, 3, 4, 5]),
        throwsA(isA<ExcelParseException>()),
      );
    });
  });
}
