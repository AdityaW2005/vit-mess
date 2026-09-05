import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/core/config/app_config.dart';
import 'package:vit_mess/models/app_settings.dart';
import 'package:vit_mess/models/meal.dart';
import 'package:vit_mess/models/menu.dart';
import 'package:vit_mess/repositories/reminder_repository_impl.dart';
import 'package:vit_mess/services/notification_service.dart';

/// Captures what would have been handed to the platform.
class FakeNotificationService implements NotificationService {
  List<ScheduledReminder> lastBatch = <ScheduledReminder>[];
  int replaceCalls = 0;
  int cancelCalls = 0;
  bool permissionGranted = true;
  bool exact = true;

  @override
  bool get isInitialized => true;

  @override
  bool get canScheduleExact => exact;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<bool> replaceAll(List<ScheduledReminder> reminders) async {
    replaceCalls++;
    lastBatch = reminders;
    return reminders.isNotEmpty;
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
    lastBatch = <ScheduledReminder>[];
  }

  @override
  Future<int> pendingCount() async => lastBatch.length;

  @override
  Future<bool> areNotificationsEnabled() async => permissionGranted;

}

/// A month of menu built around [anchor], so tests are date-independent.
Menu buildMenu(DateTime anchor, {int days = 30}) {
  final entries = <String>[];
  for (var i = 0; i < days; i++) {
    final date = DateTime(anchor.year, anchor.month, anchor.day)
        .add(Duration(days: i));
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    entries.add('''
        {
          "date": "$key",
          "weekday": "Mon",
          "meals": [
            { "type": "breakfast", "startTime": "07:00", "endTime": "09:00",
              "items": [{"name": "Idly"}, {"name": "Vada"}, {"name": "Tea"},
                        {"name": "Extra"}] },
            { "type": "lunch", "startTime": "12:30", "endTime": "14:15",
              "items": [{"name": "Rice"}] },
            { "type": "snacks", "startTime": "16:30", "endTime": "18:15",
              "items": [{"name": "Bajji"}] },
            { "type": "dinner", "startTime": "19:15", "endTime": "21:00",
              "items": [{"name": "Chapathi"}] }
          ]
        }''');
  }
  return Menu.decode('''
{
  "schemaVersion": 1, "month": "2026-09", "campus": "VIT-AP",
  "messes": [
    { "id": "veg-nonveg", "name": "Veg & Non-Veg", "days": [${entries.join(',')}] }
  ]
}
''')!;
}

void main() {
  late FakeNotificationService notifications;
  late ReminderRepositoryImpl reminders;

  // Just after midnight, so every meal today is still ahead.
  final now = DateTime(2026, 9, 4, 0, 30);
  final menu = buildMenu(now);
  final enabled = AppSettings.initial().copyWith(remindersEnabled: true);

  setUp(() {
    notifications = FakeNotificationService();
    reminders = ReminderRepositoryImpl(notifications: notifications);
  });

  group('what gets scheduled', () {
    test('covers four meals across the whole horizon', () async {
      final result = await reminders.reschedule(
        menu: menu,
        settings: enabled,
        now: now,
      );

      expect(result.valueOrNull, AppConfig.reminderHorizonDays * 4);
      expect(notifications.lastBatch, hasLength(28));
    });

    test('fires the configured lead time before the meal opens', () async {
      await reminders.reschedule(menu: menu, settings: enabled, now: now);

      final first = notifications.lastBatch.reduce(
        (a, b) => a.fireAt.isBefore(b.fireAt) ? a : b,
      );
      // Breakfast opens at 07:00, so the nudge lands at 06:45.
      expect(first.fireAt, DateTime(2026, 9, 4, 6, 45));
    });

    test('carries the meal name and its first dishes', () async {
      await reminders.reschedule(menu: menu, settings: enabled, now: now);

      final first = notifications.lastBatch.reduce(
        (a, b) => a.fireAt.isBefore(b.fireAt) ? a : b,
      );
      expect(first.title, contains('Breakfast'));
      // Only a preview, not the entire meal.
      expect(first.body, 'Idly, Vada, Tea');
    });

    test('skips a meal whose reminder time has already passed', () async {
      // Mid-afternoon: breakfast and lunch are gone for today.
      final afternoon = DateTime(2026, 9, 4, 15, 0);
      await reminders.reschedule(
        menu: menu,
        settings: enabled,
        now: afternoon,
      );

      for (final reminder in notifications.lastBatch) {
        expect(reminder.fireAt.isAfter(afternoon), isTrue);
      }
      // Two of today's four are in the past.
      expect(notifications.lastBatch, hasLength(26));
    });

    test('honours the per-meal switches', () async {
      final lunchOnly = enabled.copyWith(
        reminderMeals: <MealType>{MealType.lunch},
      );

      await reminders.reschedule(menu: menu, settings: lunchOnly, now: now);

      expect(notifications.lastBatch, hasLength(7));
      expect(
        notifications.lastBatch.every((r) => r.title.contains('Lunch')),
        isTrue,
      );
    });

    test('ids are unique, so nothing overwrites anything else', () async {
      await reminders.reschedule(menu: menu, settings: enabled, now: now);

      final ids = notifications.lastBatch.map((r) => r.id).toSet();
      expect(ids, hasLength(notifications.lastBatch.length));
    });

    test('rescheduling replaces rather than accumulating', () async {
      await reminders.reschedule(menu: menu, settings: enabled, now: now);
      await reminders.reschedule(menu: menu, settings: enabled, now: now);

      expect(notifications.replaceCalls, 2);
      // replaceAll cancels first, so the batch never grows.
      expect(notifications.lastBatch, hasLength(28));
    });
  });

  group('when nothing should be scheduled', () {
    test('switching reminders off cancels everything', () async {
      await reminders.reschedule(menu: menu, settings: enabled, now: now);

      final result = await reminders.reschedule(
        menu: menu,
        settings: enabled.copyWith(remindersEnabled: false),
        now: now,
      );

      expect(result.valueOrNull, 0);
      expect(notifications.cancelCalls, greaterThan(0));
      expect(notifications.lastBatch, isEmpty);
    });

    test('no enabled meals cancels everything', () async {
      final result = await reminders.reschedule(
        menu: menu,
        settings: enabled.copyWith(reminderMeals: <MealType>{}),
        now: now,
      );

      expect(result.valueOrNull, 0);
      expect(notifications.lastBatch, isEmpty);
    });

    test('a menu that does not reach today schedules nothing', () async {
      // Last month's menu against today's date — the stale-month case.
      final stale = buildMenu(DateTime(2026, 8, 1), days: 5);

      final result = await reminders.reschedule(
        menu: stale,
        settings: enabled,
        now: now,
      );

      expect(result.valueOrNull, 0);
      expect(notifications.lastBatch, isEmpty);
    });
  });

  group('platform state', () {
    test('a declined permission is reported, not thrown', () async {
      notifications.permissionGranted = false;
      final granted = await reminders.requestPermission();
      expect(granted.isSuccess, isTrue);
      expect(granted.valueOrNull, isFalse);
    });

    test('status surfaces what the platform will allow', () async {
      await reminders.reschedule(menu: menu, settings: enabled, now: now);
      notifications.exact = false;

      final status = await reminders.status();
      expect(status.notificationsAllowed, isTrue);
      expect(status.exactAlarmsAllowed, isFalse);
      expect(status.pending, 28);
    });
  });
}
