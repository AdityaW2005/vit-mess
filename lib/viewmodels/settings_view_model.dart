import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/constants/analytics_events.dart';
import '../core/config/meal_timings.dart';
import '../core/utils/result.dart';
import '../models/app_settings.dart';
import '../models/developer.dart';
import '../models/meal.dart';
import '../models/menu.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/app_info_repository.dart';
import '../repositories/link_repository.dart';
import '../repositories/menu_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/settings_repository.dart';
import 'base_view_model.dart';

/// A selectable subscription tier.
@immutable
class MessOption {
  /// Creates an option.
  const MessOption({required this.id, required this.name});

  /// Tier id, e.g. `veg-nonveg`.
  final String id;

  /// Display name from the document.
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessOption && id == other.id && name == other.name);

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'MessOption($id)';
}

/// Drives Settings and onboarding.
///
/// Every mutation writes through the settings repository, which broadcasts the
/// change so Home, Week and Search update without knowing this screen exists.
class SettingsViewModel extends BaseViewModel {
  /// Creates the ViewModel over its repository interfaces.
  SettingsViewModel({
    required MenuRepository menuRepository,
    required SettingsRepository settingsRepository,
    required ReminderRepository reminderRepository,
    required AnalyticsRepository analyticsRepository,
    required LinkRepository linkRepository,
    required AppInfoRepository appInfoRepository,
  }) : _menuRepository = menuRepository,
       _settingsRepository = settingsRepository,
       _reminderRepository = reminderRepository,
       _analytics = analyticsRepository,
       _links = linkRepository,
       _appInfo = appInfoRepository,
       _settings = settingsRepository.current;

  final MenuRepository _menuRepository;
  final SettingsRepository _settingsRepository;
  final ReminderRepository _reminderRepository;
  final AnalyticsRepository _analytics;
  final LinkRepository _links;
  final AppInfoRepository _appInfo;

  StreamSubscription<AppSettings>? _settingsSubscription;
  StreamSubscription<MenuSnapshot>? _menuSubscription;

  AppSettings _settings;
  MenuSnapshot? _snapshot;
  bool _initialized = false;
  bool _isRefreshing = false;
  bool _isImporting = false;
  bool _notificationsBlocked = false;
  ReminderStatus? _reminderStatus;
  String? _appVersion;

  // ------------------------------------------------------------- getters

  /// The settings currently in effect.
  AppSettings get settings => _settings;

  /// The menu in hand, used for the "about" rows and for rescheduling.
  MenuSnapshot? get snapshot => _snapshot;

  /// When the menu was last fetched or imported.
  DateTime? get lastUpdated => _snapshot?.lastUpdated;

  /// Where the menu in hand came from.
  MenuSource? get source => _snapshot?.source;

  /// True while a forced refresh is in flight.
  bool get isRefreshing => _isRefreshing;

  /// True when a menu server is published, so downloading is worth offering.
  bool get canRefreshFromServer => AppConfig.isRemoteConfigured;

  /// True once a menu has been imported or downloaded.
  bool get hasMenu => _snapshot != null;

  /// The `yyyy-MM` the loaded document covers, or `null`.
  String? get menuMonth => _snapshot?.menu.month;

  /// Days the loaded document covers.
  int get menuDayCount {
    final messes = _snapshot?.menu.messes;
    if (messes == null || messes.isEmpty) return 0;
    return messes.first.days.length;
  }

  /// Tiers the loaded document carries.
  int get menuTierCount => _snapshot?.menu.messes.length ?? 0;

  /// True while the file picker flow is running.
  bool get isImporting => _isImporting;

  /// The running build's version, once the platform has reported it.
  ///
  /// `null` until then, and on a platform that cannot say — the footer leaves
  /// the line out rather than showing a guess.
  String? get appVersion => _appVersion;

  /// What the platform will currently allow reminders to do, once known.
  ReminderStatus? get reminderStatus => _reminderStatus;

  /// True when the OS is blocking notifications outright.
  bool get notificationsBlockedByOs =>
      _settings.remindersEnabled && _reminderStatus?.notificationsAllowed == false;

  /// True when reminders will be delivered, but possibly late.
  bool get remindersMayBeDelayed =>
      _settings.remindersEnabled &&
      _reminderStatus?.notificationsAllowed == true &&
      _reminderStatus?.exactAlarmsAllowed == false;

  /// True when the platform refused notification permission.
  ///
  /// The UI uses this to explain why reminders stayed off.
  bool get notificationsBlocked => _notificationsBlocked;

  /// True once onboarding has been dismissed.
  bool get onboardingCompleted => _settings.onboardingCompleted;

  /// Light, dark, or follow the device.
  AppThemeMode get themeMode => _settings.themeMode;

  /// The tiers the document offers. Immutable.
  List<MessOption> get messOptions {
    final messes = _snapshot?.menu.messes;
    if (messes == null || messes.isEmpty) return const <MessOption>[];
    return List<MessOption>.unmodifiable(
      messes
          .map((mess) => MessOption(id: mess.id, name: mess.name))
          .toList(growable: false),
    );
  }

  /// The selected tier's display name, or its id as a fallback.
  String get selectedMessName {
    for (final option in messOptions) {
      if (option.id == _settings.messId) return option.name;
    }
    return _settings.messId;
  }

  /// The effective window for [type], override included.
  MealWindow windowFor(MealType type) => _settings.timings.windowFor(type);

  /// True when [type] has been retimed by the student.
  bool isOverridden(MealType type) => _settings.timings.isOverridden(type);

  // -------------------------------------------------------------- actions

  /// Loads settings and the menu. Safe to call more than once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _settings = _settingsRepository.current;
    _settingsSubscription = _settingsRepository.changes.listen((settings) {
      if (isDisposed) return;
      _settings = settings;
      safeNotify();
    });
    _menuSubscription = _menuRepository.changes.listen((snapshot) {
      if (isDisposed) return;
      _snapshot = snapshot;
      safeNotify();
    });

    setState(ViewState.busy);

    final result = await _menuRepository.getMenu();
    if (isDisposed) return;

    unawaited(refreshReminderStatus());
    unawaited(_loadAppVersion());

    result.fold(
      onSuccess: (snapshot) {
        _snapshot = snapshot;
        setState(ViewState.ready);
      },
      // Settings must stay usable even with no menu, so a load failure is
      // recorded but does not blank the screen.
      onFailure: (failure) {
        setState(ViewState.ready);
      },
    );
  }

/// Called when this tab comes to the front.
  ///
  /// Tabs live in an `IndexedStack`, so they are built once and never pushed
  /// as routes — the navigator observer cannot see them and the screen has to
  /// report itself.
  void onShown() => unawaited(_analytics.logScreen(AnalyticsScreens.settings));

  /// Called when the first-run tier picker appears.
  void onOnboardingShown() =>
      unawaited(_analytics.logScreen(AnalyticsScreens.onboarding));

  /// Reads the build version for the footer. Failing is not worth reporting:
  /// the line simply does not appear.
  Future<void> _loadAppVersion() async {
    final version = await _appInfo.version();
    if (isDisposed || version == null) return;
    _appVersion = version;
    safeNotify();
  }

  /// Re-reads what the platform will allow, so the warnings stay truthful
  /// after a trip to system settings.
  Future<void> refreshReminderStatus() async {
    final status = await _reminderRepository.status();
    if (isDisposed) return;
    _reminderStatus = status;
    safeNotify();
  }

  /// Switches the subscription tier and reschedules reminders.
  Future<void> selectMess(String messId) async {
    if (messId == _settings.messId) return;
    unawaited(_analytics.logTierChanged(messId));
    await _persist(_settings.copyWith(messId: messId));
  }

  /// Switches between the light theme, the dark theme, and the device
  /// setting.
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (mode == _settings.themeMode) return;
    unawaited(_analytics.logThemeChanged(mode));
    await _persist(_settings.copyWith(themeMode: mode));
  }

  /// Turns anonymous usage analytics on or off.
  ///
  /// The choice is applied at the SDK level, so opting out stops data leaving
  /// the device rather than merely being dropped here.
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (enabled == _settings.analyticsEnabled) return;
    await _analytics.setConsent(enabled: enabled);
    await _persist(_settings.copyWith(analyticsEnabled: enabled));
  }

  /// Overrides the serving window for [type].
  Future<void> setMealWindow(MealType type, MealWindow window) async {
    if (!window.isValid) return;
    unawaited(_analytics.logMealTimingChanged(type: type, isReset: false));
    await _persist(
      _settings.copyWith(timings: _settings.timings.withWindow(type, window)),
    );
  }

  /// Drops the override for [type], restoring the published window.
  Future<void> clearMealWindow(MealType type) async {
    if (!_settings.timings.isOverridden(type)) return;
    unawaited(_analytics.logMealTimingChanged(type: type, isReset: true));
    await _persist(
      _settings.copyWith(timings: _settings.timings.withoutOverride(type)),
    );
  }

  /// Drops every timing override.
  Future<void> resetTimings() async {
    if (!_settings.timings.hasOverrides) return;
    await _persist(_settings.copyWith(timings: MealTimings.defaults));
  }

  /// Turns meal reminders on or off.
  ///
  /// Returns `true` when reminders ended up enabled. Turning them on requests
  /// permission first; a decline leaves the switch off and sets
  /// [notificationsBlocked] so the UI can explain why.
  Future<bool> setRemindersEnabled(bool enabled) async {
    if (!enabled) {
      _notificationsBlocked = false;
      unawaited(_analytics.logRemindersToggled(enabled: false));
      await _persist(_settings.copyWith(remindersEnabled: false));
      await _reminderRepository.cancelAll();
      return false;
    }

    final granted = await _reminderRepository.requestPermission();
    if (isDisposed) return false;

    final allowed = granted.valueOrNull ?? false;
    _notificationsBlocked = !allowed;
    if (!allowed) {
      unawaited(_analytics.logRemindersBlocked());
      safeNotify();
      return false;
    }

    unawaited(_analytics.logRemindersToggled(enabled: true));
    await _persist(_settings.copyWith(remindersEnabled: true));
    await refreshReminderStatus();
    return true;
  }

  /// Turns the reminder for a single meal on or off.
  Future<void> setReminderForMeal(MealType type, bool enabled) async {
    await _persist(_settings.withReminderFor(type, enabled));
  }

  /// Completes onboarding with the chosen tier and reminder preference.
  ///
  /// Returns `true` when reminders were requested and granted.
  Future<bool> completeOnboarding({
    required String messId,
    required bool remindersRequested,
  }) async {
    var remindersEnabled = false;
    if (remindersRequested) {
      final granted = await _reminderRepository.requestPermission();
      if (isDisposed) return false;
      remindersEnabled = granted.valueOrNull ?? false;
      _notificationsBlocked = remindersRequested && !remindersEnabled;
    }

    unawaited(
      _analytics.logOnboardingCompleted(
        messId: messId,
        remindersEnabled: remindersEnabled,
      ),
    );
    await _persist(
      _settings.copyWith(
        messId: messId,
        onboardingCompleted: true,
        remindersEnabled: remindersEnabled,
      ),
    );
    return remindersEnabled;
  }

  /// Called when the about-the-developer sheet opens.
  void onDeveloperSheetShown() =>
      unawaited(_analytics.logDeveloperSheetOpened());

  /// Opens one of the developer's links, or copies it when it is an address.
  ///
  /// Returns `true` when the target was copied, so the view can confirm it.
  Future<Result<bool>> followDeveloperLink(DeveloperLink link) async {
    unawaited(_analytics.logDeveloperLinkOpened(link.kind));
    return _links.follow(link);
  }

  /// Fetches the document immediately, bypassing the cache.
  Future<Result<MenuSnapshot>> forceRefresh() async {
    if (_isRefreshing) {
      return const Result<MenuSnapshot>.failure(
        'A refresh is already running.',
        kind: FailureKind.unknown,
      );
    }
    _isRefreshing = true;
    safeNotify();

    final result = await _menuRepository.refreshMenu();
    if (isDisposed) return result;

    _isRefreshing = false;
    result.fold(
      onSuccess: (snapshot) {
        _snapshot = snapshot;
        unawaited(_rescheduleReminders());
      },
      onFailure: (_) {},
    );
    safeNotify();
    return result;
  }

  /// Imports a menu document chosen by the student.
  Future<Result<MenuSnapshot>> importMenu() async {
    if (_isImporting) {
      return const Result<MenuSnapshot>.failure(
        'An import is already running.',
        kind: FailureKind.unknown,
      );
    }
    _isImporting = true;
    safeNotify();

    final result = await _menuRepository.importMenu();
    if (isDisposed) return result;

    _isImporting = false;
    result.fold(
      onSuccess: (snapshot) {
        _snapshot = snapshot;
        unawaited(_rescheduleReminders());
      },
      onFailure: (_) {},
    );
    safeNotify();
    return result;
  }

  // ------------------------------------------------------------ internals

  /// Writes settings through the repository, then rebuilds the schedule.
  ///
  /// Rescheduling on every change is what keeps reminders correct after a tier
  /// switch or a timing edit.
  Future<void> _persist(AppSettings next) async {
    _settings = next;
    safeNotify();
    await _settingsRepository.save(next);
    await _rescheduleReminders();
  }

  Future<void> _rescheduleReminders() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    await _reminderRepository.reschedule(
      menu: snapshot.menu,
      settings: _settings,
    );
  }

  @override
  void dispose() {
    unawaited(_settingsSubscription?.cancel());
    _settingsSubscription = null;
    unawaited(_menuSubscription?.cancel());
    _menuSubscription = null;
    super.dispose();
  }
}
