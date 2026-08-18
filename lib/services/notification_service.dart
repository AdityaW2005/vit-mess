import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/config/app_config.dart';

/// A single reminder to be placed on the platform scheduler.
@immutable
class ScheduledReminder {
  /// Creates a reminder.
  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
  });

  /// Stable identifier, so re-scheduling replaces rather than duplicates.
  final int id;

  /// Notification title.
  final String title;

  /// Notification body.
  final String body;

  /// When it should fire, in device-local time.
  final DateTime fireAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledReminder &&
          id == other.id &&
          title == other.title &&
          body == other.body &&
          fireAt == other.fireAt);

  @override
  int get hashCode => Object.hash(id, title, body, fireAt);

  @override
  String toString() => 'ScheduledReminder($id at $fireAt)';
}

/// Wraps the local notification plugin.
///
/// Every method is defensive: a student who denies notification permission,
/// or a platform that refuses exact alarms, must never break the app. Failures
/// are reported as `false`, never thrown.
class NotificationService {
  /// Creates the service. Pass a [plugin] in tests.
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  bool _timezoneReady = false;

  /// True once [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// Prepares the plugin and the timezone database.
  ///
  /// Safe to call more than once. Returns `false` if the platform refused to
  /// initialise, in which case scheduling is skipped silently.
  Future<bool> initialize() async {
    if (_initialized) return true;

    _prepareTimezones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Permission is requested explicitly, at the moment the student turns
        // reminders on, rather than as a cold-start surprise.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    try {
      final result = await _plugin.initialize(settings: settings);
      _initialized = result ?? true;
    } on Object catch (error) {
      debugPrint('NotificationService.initialize failed: $error');
      _initialized = false;
      return false;
    }

    await _createAndroidChannel();
    return _initialized;
  }

  /// Asks the platform for permission to post notifications.
  ///
  /// Returns `false` when the student declines or the platform has no such
  /// concept, so callers can fall back to leaving reminders switched off.
  Future<bool> requestPermission() async {
    if (!await initialize()) return false;

    try {
      if (_isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }
      if (_isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } on Object catch (error) {
      debugPrint('NotificationService.requestPermission failed: $error');
    }
    return false;
  }

  /// Replaces every scheduled reminder with [reminders].
  ///
  /// Cancelling first is what makes this safe to call on every tier change,
  /// timing change and menu refresh without piling up duplicates. Reminders
  /// whose time has already passed are skipped.
  Future<bool> replaceAll(List<ScheduledReminder> reminders) async {
    if (!await initialize()) return false;

    try {
      await _plugin.cancelAll();
    } on Object catch (error) {
      debugPrint('NotificationService.cancelAll failed: $error');
      return false;
    }

    if (reminders.isEmpty) return true;

    final details = _details();
    final now = DateTime.now();
    var scheduled = 0;

    for (final reminder in reminders) {
      if (!reminder.fireAt.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: _toZoned(reminder.fireAt),
          notificationDetails: details,
          // Inexact alarms need no special permission on Android 12+, and a
          // meal reminder does not need second-level precision.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        scheduled++;
      } on Object catch (error) {
        debugPrint('Failed to schedule reminder ${reminder.id}: $error');
      }
    }

    return scheduled > 0;
  }

  /// Cancels every pending reminder.
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } on Object catch (error) {
      debugPrint('NotificationService.cancelAll failed: $error');
    }
  }

  // ------------------------------------------------------------- internals

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      AppConfig.notificationChannelId,
      AppConfig.notificationChannelName,
      channelDescription: AppConfig.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    ),
  );

  Future<void> _createAndroidChannel() async {
    if (!_isAndroid) return;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConfig.notificationChannelId,
          AppConfig.notificationChannelName,
          description: AppConfig.notificationChannelDescription,
          importance: Importance.high,
        ),
      );
    } on Object catch (error) {
      debugPrint('Failed to create notification channel: $error');
    }
  }

  /// Loads the timezone database and picks a location for scheduling.
  ///
  /// The status logic elsewhere uses plain device-local `DateTime`; the plugin
  /// however needs a named zone. Rather than assume one, the device's current
  /// UTC offset is matched against the database, falling back to the campus
  /// timezone only if nothing matches.
  void _prepareTimezones() {
    if (_timezoneReady) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(_resolveLocation());
      _timezoneReady = true;
    } on Object catch (error) {
      debugPrint('Timezone initialisation failed: $error');
    }
  }

  tz.Location _resolveLocation() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;

    for (final location in tz.timeZoneDatabase.locations.values) {
      final zoned = tz.TZDateTime.from(now, location);
      if (zoned.timeZoneOffset == offset) return location;
    }

    try {
      return tz.getLocation(AppConfig.fallbackTimeZone);
    } on Object {
      return tz.UTC;
    }
  }

  tz.TZDateTime _toZoned(DateTime local) =>
      tz.TZDateTime.from(local, tz.local);

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  bool get _isIOS => !kIsWeb && Platform.isIOS;
}
