import 'package:flutter/foundation.dart';

import '../core/utils/result.dart';
import '../models/app_settings.dart';
import '../models/menu.dart';

/// What the platform will currently let reminders do.
@immutable
class ReminderStatus {
  /// Creates a status snapshot.
  const ReminderStatus({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.pending,
  });

  /// False when the student has notifications switched off for the app.
  final bool notificationsAllowed;

  /// False when Android will only deliver batched, inexact alarms.
  final bool exactAlarmsAllowed;

  /// How many reminders are currently queued with the system.
  final int pending;

  @override
  String toString() =>
      'ReminderStatus(allowed=$notificationsAllowed, '
      'exact=$exactAlarmsAllowed, pending=$pending)';
}

/// Owns meal-reminder scheduling policy.
///
/// Keeps the notification plugin out of the ViewModel layer, and keeps the
/// "what should be scheduled" decision in one testable place.
abstract class ReminderRepository {
  /// Asks the platform for notification permission.
  ///
  /// Returns `Success(false)` — not a failure — when the student declines, so
  /// callers can quietly leave reminders off.
  Future<Result<bool>> requestPermission();

  /// Rebuilds the whole reminder schedule from scratch.
  ///
  /// Call after any tier change, timing change, or menu refresh. Returns the
  /// number of reminders placed.
  Future<Result<int>> reschedule({
    required Menu menu,
    required AppSettings settings,
    DateTime? now,
  });

  /// Removes every pending reminder.
  Future<void> cancelAll();

  /// What the platform will currently allow, and how many reminders are queued.
  Future<ReminderStatus> status();
}
