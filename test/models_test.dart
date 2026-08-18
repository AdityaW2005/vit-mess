import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/core/constants/strings.dart';
import 'package:vit_mess/models/app_settings.dart';
import 'package:vit_mess/models/meal.dart';
import 'package:vit_mess/models/meal_item.dart';
import 'package:vit_mess/models/menu.dart';
import 'package:vit_mess/models/menu_day.dart';
import 'package:vit_mess/models/mess.dart';

const String wellFormedDocument = '''
{
  "schemaVersion": 1,
  "month": "2026-08",
  "campus": "VIT-AP",
  "messes": [
    {
      "id": "veg-nonveg",
      "name": "Veg & Non-Veg",
      "days": [
        {
          "date": "2026-08-17",
          "weekday": "Mon",
          "meals": [
            {
              "type": "breakfast",
              "startTime": "07:00",
              "endTime": "09:30",
              "items": [
                { "name": "Carrot Idly", "variant": null },
                { "name": "Telangana Chicken Curry", "variant": "nonveg" },
                { "name": "Achari Paneer", "variant": "veg" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';

void main() {
  group('MealItem', () {
    test('parses a plain item', () {
      final item = MealItem.fromJson(<String, dynamic>{
        'name': 'Carrot Idly',
        'variant': null,
      });
      expect(item?.name, 'Carrot Idly');
      expect(item?.variant, isNull);
      expect(item?.isPaired, isFalse);
    });

    test('parses both variants, including the hyphenated spelling', () {
      expect(
        MealItem.fromJson(<String, dynamic>{'name': 'A', 'variant': 'veg'})
            ?.variant,
        ItemVariant.veg,
      );
      expect(
        MealItem.fromJson(<String, dynamic>{'name': 'B', 'variant': 'nonveg'})
            ?.variant,
        ItemVariant.nonVeg,
      );
      expect(
        MealItem.fromJson(<String, dynamic>{'name': 'C', 'variant': 'NON-VEG'})
            ?.variant,
        ItemVariant.nonVeg,
      );
    });

    test('returns null for unusable input instead of throwing', () {
      expect(MealItem.fromJson(null), isNull);
      expect(MealItem.fromJson('not a map'), isNull);
      expect(MealItem.fromJson(<String, dynamic>{}), isNull);
      expect(MealItem.fromJson(<String, dynamic>{'name': ''}), isNull);
      expect(MealItem.fromJson(<String, dynamic>{'name': '   '}), isNull);
      expect(MealItem.fromJson(<String, dynamic>{'name': 42}), isNull);
    });

    test('degrades an unrecognised variant to null rather than failing', () {
      final item = MealItem.fromJson(<String, dynamic>{
        'name': 'Mystery',
        'variant': 'vegan',
      });
      expect(item?.name, 'Mystery');
      expect(item?.variant, isNull);
    });

    test('has value equality and copyWith', () {
      const a = MealItem(name: 'Idly', variant: ItemVariant.veg);
      const b = MealItem(name: 'Idly', variant: ItemVariant.veg);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(name: 'Vada').name, 'Vada');
      expect(a.copyWith(clearVariant: true).variant, isNull);
    });
  });

  group('Meal', () {
    test('parses a well-formed meal', () {
      final meal = Meal.fromJson(<String, dynamic>{
        'type': 'lunch',
        'startTime': '12:00',
        'endTime': '14:30',
        'items': <dynamic>[
          <String, dynamic>{'name': 'Rice'},
        ],
      });
      expect(meal?.type, MealType.lunch);
      expect(meal?.startTime, const MinuteOfDay(12, 0));
      expect(meal?.endTime, const MinuteOfDay(14, 30));
      expect(meal?.items, hasLength(1));
    });

    test('returns null when the slot cannot be identified', () {
      expect(Meal.fromJson(null), isNull);
      expect(Meal.fromJson(<String, dynamic>{'type': 'brunch'}), isNull);
      expect(Meal.fromJson(<String, dynamic>{}), isNull);
    });

    test('falls back to the canonical window when times are malformed', () {
      final meal = Meal.fromJson(<String, dynamic>{
        'type': 'breakfast',
        'startTime': 'oops',
        'items': <dynamic>[],
      });
      expect(meal?.startTime, MealType.breakfast.defaultStart);
      expect(meal?.endTime, MealType.breakfast.defaultEnd);
    });

    test('falls back when the window ends before it starts', () {
      final meal = Meal.fromJson(<String, dynamic>{
        'type': 'dinner',
        'startTime': '19:00',
        'endTime': '18:00',
        'items': <dynamic>[],
      });
      expect(meal?.endTime, MealType.dinner.defaultEnd);
    });

    test('drops unparseable items but keeps the good ones', () {
      final meal = Meal.fromJson(<String, dynamic>{
        'type': 'snacks',
        'items': <dynamic>[
          <String, dynamic>{'name': 'Samosa'},
          null,
          'garbage',
          <String, dynamic>{'name': ''},
          <String, dynamic>{'name': 'Tea'},
        ],
      });
      expect(meal?.items.map((item) => item.name), <String>['Samosa', 'Tea']);
    });

    test('tolerates a missing items list', () {
      final meal = Meal.fromJson(<String, dynamic>{'type': 'lunch'});
      expect(meal?.items, isEmpty);
    });

    test('exposes an unmodifiable item list', () {
      final meal = Meal.fromJson(<String, dynamic>{
        'type': 'lunch',
        'items': <dynamic>[
          <String, dynamic>{'name': 'Rice'},
        ],
      })!;
      expect(
        () => meal.items.add(const MealItem(name: 'Sneaky')),
        throwsUnsupportedError,
      );
    });

    test('groups paired alternatives two by two', () {
      final meal = Meal.fromJson(<String, dynamic>{
        'type': 'lunch',
        'items': <dynamic>[
          <String, dynamic>{'name': 'Rice'},
          <String, dynamic>{'name': 'Chicken Curry', 'variant': 'nonveg'},
          <String, dynamic>{'name': 'Paneer', 'variant': 'veg'},
        ],
      })!;
      expect(meal.plainItems, hasLength(1));
      expect(meal.variantPairs, hasLength(1));
      expect(meal.variantPairs.single, hasLength(2));
    });

    test('round-trips through JSON', () {
      final original = Meal.fromJson(<String, dynamic>{
        'type': 'lunch',
        'startTime': '12:00',
        'endTime': '14:30',
        'items': <dynamic>[
          <String, dynamic>{'name': 'Chicken', 'variant': 'nonveg'},
        ],
      })!;
      expect(Meal.fromJson(original.toJson()), original);
    });
  });

  group('MenuDay', () {
    test('parses and normalises the date to local midnight', () {
      final day = MenuDay.fromJson(<String, dynamic>{
        'date': '2026-08-17',
        'weekday': 'Mon',
        'meals': <dynamic>[],
      });
      expect(day?.date, DateTime(2026, 8, 17));
      expect(day?.dateKey, '2026-08-17');
    });

    test('returns null without a usable date', () {
      expect(MenuDay.fromJson(<String, dynamic>{'weekday': 'Mon'}), isNull);
      expect(MenuDay.fromJson(<String, dynamic>{'date': 'not-a-date'}), isNull);
      expect(MenuDay.fromJson('nope'), isNull);
    });

    test('derives the weekday label when the document omits it', () {
      final day = MenuDay.fromJson(<String, dynamic>{'date': '2026-08-17'});
      expect(day?.weekday, 'Mon');
    });

    test('sorts meals into serving order regardless of document order', () {
      final day = MenuDay.fromJson(<String, dynamic>{
        'date': '2026-08-17',
        'meals': <dynamic>[
          <String, dynamic>{'type': 'dinner'},
          <String, dynamic>{'type': 'breakfast'},
          <String, dynamic>{'type': 'snacks'},
          <String, dynamic>{'type': 'lunch'},
        ],
      })!;
      expect(day.meals.map((meal) => meal.type), <MealType>[
        MealType.breakfast,
        MealType.lunch,
        MealType.snacks,
        MealType.dinner,
      ]);
    });

    test('looks a meal up by slot', () {
      final day = MenuDay.fromJson(<String, dynamic>{
        'date': '2026-08-17',
        'meals': <dynamic>[
          <String, dynamic>{'type': 'lunch'},
        ],
      })!;
      expect(day.mealFor(MealType.lunch), isNotNull);
      expect(day.mealFor(MealType.dinner), isNull);
    });
  });

  group('Mess', () {
    test('sorts days ascending and looks them up by date', () {
      final mess = Mess.fromJson(<String, dynamic>{
        'id': 'special',
        'name': 'Special',
        'days': <dynamic>[
          <String, dynamic>{'date': '2026-08-19'},
          <String, dynamic>{'date': '2026-08-17'},
        ],
      })!;
      expect(mess.days.first.dateKey, '2026-08-17');
      expect(mess.dayFor(DateTime(2026, 8, 19, 13)), isNotNull);
      expect(mess.dayFor(DateTime(2026, 8, 18)), isNull);
      expect(mess.dayAfter(DateTime(2026, 8, 17)), isNotNull);
      expect(mess.dayAfter(DateTime(2026, 8, 19)), isNull);
    });

    test('returns null without a usable id', () {
      expect(Mess.fromJson(<String, dynamic>{'name': 'No id'}), isNull);
      expect(Mess.fromJson(<String, dynamic>{'id': '  '}), isNull);
    });

    test('falls back to the id when the name is missing', () {
      expect(Mess.fromJson(<String, dynamic>{'id': 'special'})?.name, 'special');
    });
  });

  group('Menu', () {
    test('decodes the documented contract shape', () {
      final menu = Menu.decode(wellFormedDocument)!;
      expect(menu.schemaVersion, 1);
      expect(menu.month, '2026-08');
      expect(menu.campus, 'VIT-AP');
      expect(menu.messes, hasLength(1));

      final meal = menu.messes.single.days.single.meals.single;
      expect(meal.type, MealType.breakfast);
      expect(meal.items, hasLength(3));
      expect(meal.items[0].variant, isNull);
      expect(meal.items[1].variant, ItemVariant.nonVeg);
      expect(meal.items[2].variant, ItemVariant.veg);
    });

    test('returns null on malformed JSON instead of throwing', () {
      expect(Menu.decode('{ not json'), isNull);
      expect(Menu.decode(''), isNull);
      expect(Menu.decode('[]'), isNull);
      expect(Menu.decode('null'), isNull);
    });

    test('returns null when no tier can be parsed', () {
      expect(Menu.decode('{"messes": []}'), isNull);
      expect(Menu.decode('{"messes": [{"name": "no id"}]}'), isNull);
      expect(Menu.decode('{"schemaVersion": 1}'), isNull);
    });

    test('degrades missing scalars instead of failing', () {
      final menu = Menu.decode(
        '{"messes":[{"id":"a","days":[{"date":"2026-08-01"}]}]}',
      )!;
      expect(menu.schemaVersion, 1);
      expect(menu.campus, '');
      // The month is inferred from the earliest day present.
      expect(menu.month, '2026-08');
    });

    test('detects a stale month', () {
      final menu = Menu.decode(wellFormedDocument)!;
      expect(menu.coversMonthOf(DateTime(2026, 8, 17)), isTrue);
      expect(menu.coversMonthOf(DateTime(2026, 9, 1)), isFalse);
    });

    test('falls back to the first tier for an unknown id', () {
      final menu = Menu.decode(wellFormedDocument)!;
      expect(menu.messById('nope'), isNull);
      expect(menu.messByIdOrFirst('nope')?.id, 'veg-nonveg');
    });

    test('round-trips through encode/decode', () {
      final original = Menu.decode(wellFormedDocument)!;
      expect(Menu.decode(original.encode()), original);
    });

    test('MenuSnapshot reports staleness against a given instant', () {
      final snapshot = MenuSnapshot(
        menu: Menu.decode(wellFormedDocument)!,
        source: MenuSource.cache,
        lastUpdated: DateTime(2026, 8, 17),
      );
      expect(snapshot.isStaleFor(DateTime(2026, 8, 20)), isFalse);
      expect(snapshot.isStaleFor(DateTime(2026, 9, 2)), isTrue);
    });
  });

  group('AppSettings', () {
    test('round-trips through JSON', () {
      final settings = AppSettings.initial()
          .copyWith(messId: 'special', remindersEnabled: true)
          .withReminderFor(MealType.snacks, false);

      final restored = AppSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())),
      );
      expect(restored, settings);
      expect(restored.reminderMeals.contains(MealType.snacks), isFalse);
      expect(restored.remindsFor(MealType.lunch), isTrue);
    });

    test('falls back to defaults for unusable stored data', () {
      final restored = AppSettings.fromJson('garbage');
      expect(restored, AppSettings.initial());
      expect(restored.onboardingCompleted, isFalse);
    });

    test('ignores unrecognised meal names in the reminder list', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'messId': 'special',
        'reminderMeals': <dynamic>['lunch', 'brunch', 7],
      });
      expect(restored.reminderMeals, <MealType>{MealType.lunch});
    });

    test('defaults to following the device theme', () {
      expect(AppSettings.initial().themeMode, AppThemeMode.system);
    });

    test('persists an explicit theme choice', () {
      final settings = AppSettings.initial().copyWith(
        themeMode: AppThemeMode.light,
      );
      final restored = AppSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())),
      );
      expect(restored.themeMode, AppThemeMode.light);
      expect(restored, settings);
    });

    test('falls back to system for an unrecognised theme value', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'themeMode': 'sepia',
      });
      expect(restored.themeMode, AppThemeMode.system);
    });

    test('theme choice participates in equality', () {
      final light = AppSettings.initial().copyWith(
        themeMode: AppThemeMode.light,
      );
      final dark = AppSettings.initial().copyWith(themeMode: AppThemeMode.dark);
      expect(light, isNot(dark));
    });

    test('exposes an unmodifiable reminder set', () {
      expect(
        () => AppSettings.initial().reminderMeals.add(MealType.lunch),
        throwsUnsupportedError,
      );
    });
  });

  group('month labels', () {
    test('renders a yyyy-MM key as a month name', () {
      expect(Strings.formatMonthKey('2026-08'), 'August 2026');
      expect(Strings.formatMonthKey('2026-1'), 'January 2026');
      expect(Strings.formatMonthKey('2027-12'), 'December 2027');
    });

    test('falls back rather than showing nothing', () {
      expect(Strings.formatMonthKey(null), '—');
      expect(Strings.formatMonthKey(''), '—');
      expect(Strings.formatMonthKey('   '), '—');
      // Anything unrecognisable is shown as stored, not swallowed.
      expect(Strings.formatMonthKey('August'), 'August');
      expect(Strings.formatMonthKey('2026-13'), '2026-13');
    });
  });

  group('MealType weekday windows', () {
    test('breakfast runs 07:00-09:00 Tuesday to Saturday', () {
      for (final date in <DateTime>[
        DateTime(2026, 8, 18), // Tue
        DateTime(2026, 8, 19), // Wed
        DateTime(2026, 8, 20), // Thu
        DateTime(2026, 8, 21), // Fri
        DateTime(2026, 8, 22), // Sat
      ]) {
        expect(MealType.breakfast.startOn(date), const MinuteOfDay(7, 0));
        expect(MealType.breakfast.endOn(date), const MinuteOfDay(9, 0));
        expect(MealType.breakfast.hasWeekdayException(date), isFalse);
      }
    });

    test('breakfast runs 07:15-09:15 on Sunday and Monday', () {
      for (final date in <DateTime>[
        DateTime(2026, 8, 23), // Sun
        DateTime(2026, 8, 24), // Mon
      ]) {
        expect(MealType.breakfast.startOn(date), const MinuteOfDay(7, 15));
        expect(MealType.breakfast.endOn(date), const MinuteOfDay(9, 15));
        expect(MealType.breakfast.hasWeekdayException(date), isTrue);
      }
    });

    test('the other slots keep one window all week', () {
      for (final type in <MealType>[
        MealType.lunch,
        MealType.snacks,
        MealType.dinner,
      ]) {
        expect(type.hasWeekdayVariants, isFalse);
        for (var day = 17; day <= 23; day++) {
          final date = DateTime(2026, 8, day);
          expect(type.startOn(date), type.defaultStart, reason: '$type $date');
          expect(type.endOn(date), type.defaultEnd, reason: '$type $date');
        }
      }
    });

    test('matches the published mess timings table', () {
      expect(MealType.lunch.defaultStart, const MinuteOfDay(12, 30));
      expect(MealType.lunch.defaultEnd, const MinuteOfDay(14, 15));
      expect(MealType.snacks.defaultStart, const MinuteOfDay(16, 30));
      expect(MealType.snacks.defaultEnd, const MinuteOfDay(18, 15));
      expect(MealType.dinner.defaultStart, const MinuteOfDay(19, 15));
      expect(MealType.dinner.defaultEnd, const MinuteOfDay(21, 0));
    });
  });
}
