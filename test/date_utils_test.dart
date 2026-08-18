import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/core/config/meal_timings.dart';
import 'package:vit_mess/core/utils/date_utils.dart';
import 'package:vit_mess/models/meal.dart';
import 'package:vit_mess/models/meal_item.dart';
import 'package:vit_mess/models/meal_status.dart';
import 'package:vit_mess/models/menu_day.dart';
import 'package:vit_mess/models/mess.dart';

Meal buildMeal(
  MealType type,
  String start,
  String end, {
  List<String> items = const <String>['Idly'],
}) => Meal(
  type: type,
  startTime: MinuteOfDay.tryParse(start)!,
  endTime: MinuteOfDay.tryParse(end)!,
  items: items.map((name) => MealItem(name: name)).toList(),
);

MenuDay buildDay(DateTime date, List<Meal> meals) =>
    MenuDay(date: date, weekday: 'Mon', meals: meals);

List<Meal> standardDay() => <Meal>[
  buildMeal(MealType.breakfast, '07:00', '09:30'),
  buildMeal(MealType.lunch, '12:00', '14:30'),
  buildMeal(MealType.snacks, '16:30', '18:00'),
  buildMeal(MealType.dinner, '19:00', '21:00'),
];

void main() {
  group('resolveStatus', () {
    final lunch = buildMeal(MealType.lunch, '12:00', '14:30');

    test('is upcoming before the window opens', () {
      final now = DateTime(2026, 8, 17, 11, 59, 59);
      expect(resolveStatus(lunch, now), MealStatus.upcoming);
    });

    test('is servingNow exactly at the opening instant', () {
      final now = DateTime(2026, 8, 17, 12);
      expect(resolveStatus(lunch, now), MealStatus.servingNow);
    });

    test('is servingNow mid-window', () {
      final now = DateTime(2026, 8, 17, 13, 15);
      expect(resolveStatus(lunch, now), MealStatus.servingNow);
    });

    test('is servingNow exactly at the closing instant', () {
      final now = DateTime(2026, 8, 17, 14, 30);
      expect(resolveStatus(lunch, now), MealStatus.servingNow);
    });

    test('is closed one second after the window ends', () {
      final now = DateTime(2026, 8, 17, 14, 30, 1);
      expect(resolveStatus(lunch, now), MealStatus.closed);
    });

    test('compares times numerically, not as strings', () {
      // '09:30' > '14:30' lexicographically would be false, but a naive
      // string comparison of '7:00' vs '12:00' would order them wrongly.
      final breakfast = buildMeal(MealType.breakfast, '07:00', '09:30');
      final now = DateTime(2026, 8, 17, 12, 30);
      expect(resolveStatus(breakfast, now), MealStatus.closed);
      expect(resolveStatus(lunch, now), MealStatus.servingNow);
    });
  });

  group('resolveStatusOnDay', () {
    final lunch = buildMeal(MealType.lunch, '12:00', '14:30');

    test('a meal on a past day is always closed', () {
      final day = DateTime(2026, 8, 16);
      final now = DateTime(2026, 8, 17, 13);
      expect(resolveStatusOnDay(lunch, day, now), MealStatus.closed);
    });

    test('a meal on a future day is always upcoming', () {
      final day = DateTime(2026, 8, 18);
      final now = DateTime(2026, 8, 17, 13);
      expect(resolveStatusOnDay(lunch, day, now), MealStatus.upcoming);
    });
  });

  group('servingNowOn', () {
    test('returns null when nothing is open', () {
      final day = DateTime(2026, 8, 17);
      final now = DateTime(2026, 8, 17, 10);
      expect(servingNowOn(standardDay(), day, now), isNull);
    });

    test('exactly one meal serves at a time', () {
      final day = DateTime(2026, 8, 17);
      final now = DateTime(2026, 8, 17, 13);
      final meals = standardDay();
      final serving = meals
          .where((meal) => resolveStatusOnDay(meal, day, now).isServing)
          .toList();
      expect(serving, hasLength(1));
      expect(serving.single.type, MealType.lunch);
    });

    test('the earliest-starting meal wins when overrides overlap', () {
      // A user override can push lunch late enough to overlap snacks.
      final meals = <Meal>[
        buildMeal(MealType.lunch, '12:00', '17:00'),
        buildMeal(MealType.snacks, '16:30', '18:00'),
      ];
      final day = DateTime(2026, 8, 17);
      final now = DateTime(2026, 8, 17, 16, 45);

      // Both are individually "serving" at this instant...
      expect(resolveStatusOnDay(meals[0], day, now), MealStatus.servingNow);
      expect(resolveStatusOnDay(meals[1], day, now), MealStatus.servingNow);
      // ...but only the earliest-starting one is chosen.
      expect(servingNowOn(meals, day, now)?.type, MealType.lunch);
    });
  });

  group('resolveFocus', () {
    Mess buildMess(List<MenuDay> days) =>
        Mess(id: 'veg-nonveg', name: 'Veg & Non-Veg', days: days);

    test('focuses the meal being served', () {
      final mess = buildMess(<MenuDay>[
        buildDay(DateTime(2026, 8, 17), standardDay()),
      ]);
      final focus = resolveFocus(mess, DateTime(2026, 8, 17, 13));

      expect(focus, isNotNull);
      expect(focus!.meal.type, MealType.lunch);
      expect(focus.status, MealStatus.servingNow);
      // Counts down to closing time while serving.
      expect(focus.target, DateTime(2026, 8, 17, 14, 30));
      expect(focus.remaining(DateTime(2026, 8, 17, 13)), const Duration(hours: 1, minutes: 30));
    });

    test('focuses the next meal between windows', () {
      final mess = buildMess(<MenuDay>[
        buildDay(DateTime(2026, 8, 17), standardDay()),
      ]);
      final now = DateTime(2026, 8, 17, 15);
      final focus = resolveFocus(mess, now);

      expect(focus!.meal.type, MealType.snacks);
      expect(focus.status, MealStatus.upcoming);
      // Counts down to opening time when not yet serving.
      expect(focus.target, DateTime(2026, 8, 17, 16, 30));
      expect(focus.remaining(now), const Duration(hours: 1, minutes: 30));
    });

    test("rolls over to tomorrow's breakfast after dinner closes", () {
      final mess = buildMess(<MenuDay>[
        buildDay(DateTime(2026, 8, 17), standardDay()),
        buildDay(DateTime(2026, 8, 18), standardDay()),
      ]);
      final now = DateTime(2026, 8, 17, 22, 30);
      final focus = resolveFocus(mess, now);

      expect(focus, isNotNull);
      expect(focus!.meal.type, MealType.breakfast);
      expect(focus.status, MealStatus.upcoming);
      expect(focus.day.date, DateTime(2026, 8, 18));
      expect(focus.isOnLaterDay(now), isTrue);
      expect(focus.daysFrom(now), 1);
      expect(focus.remaining(now), const Duration(hours: 8, minutes: 30));
    });

    test('returns null after dinner on the last day of the month', () {
      final mess = buildMess(<MenuDay>[
        buildDay(DateTime(2026, 8, 31), standardDay()),
      ]);
      // No next day exists, so there is nothing to count down to.
      expect(resolveFocus(mess, DateTime(2026, 8, 31, 22, 30)), isNull);
    });

    test('skips a gap in the document rather than failing', () {
      // The 18th is missing entirely.
      final mess = buildMess(<MenuDay>[
        buildDay(DateTime(2026, 8, 17), standardDay()),
        buildDay(DateTime(2026, 8, 19), standardDay()),
      ]);
      final focus = resolveFocus(mess, DateTime(2026, 8, 17, 22, 30));

      expect(focus!.day.date, DateTime(2026, 8, 19));
      expect(focus.meal.type, MealType.breakfast);
    });

    test('applies user timing overrides when choosing the focus', () {
      final mess = buildMess(<MenuDay>[
        buildDay(DateTime(2026, 8, 17), standardDay()),
      ]);
      // Dinner pushed earlier so it is already open at 18:30.
      const timings = MealTimings(<MealType, MealWindow>{
        MealType.dinner: MealWindow(MinuteOfDay(18, 0), MinuteOfDay(20, 0)),
      });
      final now = DateTime(2026, 8, 17, 18, 30);

      expect(resolveFocus(mess, now).runtimeType, isNotNull);
      expect(resolveFocus(mess, now)!.status, MealStatus.upcoming);
      expect(resolveFocus(mess, now, timings)!.meal.type, MealType.dinner);
      expect(resolveFocus(mess, now, timings)!.status, MealStatus.servingNow);
    });

    test('handles a day the document does not cover', () {
      final mess = buildMess(<MenuDay>[
        buildDay(DateTime(2026, 8, 20), standardDay()),
      ]);
      // "Today" is the 17th; the document starts on the 20th.
      final focus = resolveFocus(mess, DateTime(2026, 8, 17, 13));
      expect(focus!.day.date, DateTime(2026, 8, 20));
      expect(focus.meal.type, MealType.breakfast);
    });
  });

  group('calendar helpers', () {
    test('daysBetween ignores the time of day', () {
      expect(
        daysBetween(DateTime(2026, 8, 17, 23, 59), DateTime(2026, 8, 18, 0, 1)),
        1,
      );
      expect(
        daysBetween(DateTime(2026, 8, 18), DateTime(2026, 8, 17)),
        -1,
      );
    });

    test('isSameDay compares calendar dates only', () {
      expect(
        isSameDay(DateTime(2026, 8, 17, 1), DateTime(2026, 8, 17, 23)),
        isTrue,
      );
      expect(isSameDay(DateTime(2026, 8, 17), DateTime(2026, 8, 18)), isFalse);
    });

    test('dateKeyOf zero-pads', () {
      expect(dateKeyOf(DateTime(2026, 8, 7)), '2026-08-07');
    });
  });

  group('MinuteOfDay', () {
    test('parses HH:mm', () {
      expect(MinuteOfDay.tryParse('07:05')?.minutesSinceMidnight, 425);
      expect(MinuteOfDay.tryParse('00:00')?.minutesSinceMidnight, 0);
      expect(MinuteOfDay.tryParse('23:59')?.minutesSinceMidnight, 1439);
    });

    test('rejects malformed and out-of-range values', () {
      expect(MinuteOfDay.tryParse(null), isNull);
      expect(MinuteOfDay.tryParse(''), isNull);
      expect(MinuteOfDay.tryParse('7'), isNull);
      expect(MinuteOfDay.tryParse('ab:cd'), isNull);
      expect(MinuteOfDay.tryParse('24:00'), isNull);
      expect(MinuteOfDay.tryParse('12:60'), isNull);
      expect(MinuteOfDay.tryParse(730), isNull);
    });

    test('compares numerically', () {
      expect(const MinuteOfDay(7, 0) < const MinuteOfDay(12, 0), isTrue);
      expect(const MinuteOfDay(9, 30) > const MinuteOfDay(9, 29), isTrue);
      expect(const MinuteOfDay(9, 30) <= const MinuteOfDay(9, 30), isTrue);
    });

    test('round-trips through JSON', () {
      expect(const MinuteOfDay(7, 5).toJson(), '07:05');
    });
  });
}
