import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/constants/strings.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/result.dart';
import '../models/app_settings.dart';
import '../models/meal.dart';
import '../models/menu.dart';
import '../services/notification_service.dart';
import 'reminder_repository.dart';

/// Builds the reminder schedule and hands it to the platform.
class ReminderRepositoryImpl implements ReminderRepository {
  /// Creates the repository over the notification service.
  ReminderRepositoryImpl({required NotificationService notifications})
    : _notifications = notifications;

  final NotificationService _notifications;

  @override
  Future<Result<bool>> requestPermission() async {
    try {
      final granted = await _notifications.requestPermission();
      return Result<bool>.success(granted);
    } on Object catch (error) {
      debugPrint('Requesting notification permission failed: $error');
      // A platform that cannot be asked is treated as a decline, not a crash.
      return const Result<bool>.success(false);
    }
  }

  @override
  Future<Result<int>> reschedule({
    required Menu menu,
    required AppSettings settings,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();

    if (!settings.remindersEnabled || settings.reminderMeals.isEmpty) {
      debugPrint(
        '[reminders] none scheduled: enabled=${settings.remindersEnabled} '
        'meals=${settings.reminderMeals.length}',
      );
      await cancelAll();
      return const Result<int>.success(0);
    }

    final mess = menu.messByIdOrFirst(settings.messId);
    if (mess == null) {
      debugPrint('[reminders] none scheduled: no tier for ${settings.messId}');
      await cancelAll();
      return const Result<int>.success(0);
    }

    final reminders = <ScheduledReminder>[];

    for (var offset = 0; offset < AppConfig.reminderHorizonDays; offset++) {
      final date = startOfDay(moment).add(Duration(days: offset));
      final day = mess.dayFor(date);
      if (day == null) continue;

      for (final meal in settings.timings.applyToAll(day.meals)) {
        if (!settings.remindsFor(meal.type)) continue;

        final fireAt = meal.startTime
            .onDay(day.date)
            .subtract(const Duration(minutes: AppConfig.reminderLeadMinutes));
        if (!fireAt.isAfter(moment)) continue;

        reminders.add(
          ScheduledReminder(
            id: _idFor(offset, meal.type),
            title: Strings.reminderTitle(meal.type),
            body: Strings.reminderBody(_previewItems(meal)),
            fireAt: fireAt,
          ),
        );
      }
    }

    debugPrint(
      '[reminders] built ${reminders.length} from ${mess.days.length} days '
      'covering ${AppConfig.reminderHorizonDays} days from $moment',
    );

    try {
      await _notifications.replaceAll(reminders);
      return Result<int>.success(reminders.length);
    } on Object catch (error) {
      debugPrint('Rescheduling reminders failed: $error');
      return Result<int>.failure(
        Strings.failureUnknown,
        kind: FailureKind.permission,
        cause: error,
      );
    }
  }

  @override
  Future<void> cancelAll() => _notifications.cancelAll();

  @override
  Future<ReminderStatus> status() async {
    final pending = await _notifications.pendingCount();
    return ReminderStatus(
      notificationsAllowed: await _notifications.areNotificationsEnabled(),
      exactAlarmsAllowed: _notifications.canScheduleExact,
      pending: pending,
    );
  }

  /// The first few dish names, used as the notification body.
  List<String> _previewItems(Meal meal) => meal.items
      .take(AppConfig.reminderItemPreviewCount)
      .map((item) => item.name)
      .toList(growable: false);

  /// Stable per-day, per-slot id so re-scheduling replaces cleanly.
  int _idFor(int dayOffset, MealType type) =>
      dayOffset * MealType.values.length + type.index;
}
