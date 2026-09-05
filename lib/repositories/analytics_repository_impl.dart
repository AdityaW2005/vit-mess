import 'package:flutter/widgets.dart' show NavigatorObserver;

import '../core/constants/analytics_events.dart';
import '../core/utils/result.dart';
import '../models/app_settings.dart';
import '../models/meal.dart';
import '../models/meal_status.dart';
import '../models/menu.dart';
import '../services/analytics_service.dart';
import 'analytics_repository.dart';

/// Turns app concepts into the analytics schema, and enforces consent.
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  /// Creates the repository over the analytics service.
  AnalyticsRepositoryImpl({required AnalyticsService analytics})
    : _analytics = analytics;

  /// GA4 caps `search_term` well above this; the cap here keeps a pasted essay
  /// out of the schema.
  static const int _maxSearchTermLength = 100;

  final AnalyticsService _analytics;

  bool _consented = true;

  @override
  bool get isCollecting => _consented && _analytics.isAvailable;

  @override
  Future<void> initialize(AppSettings settings) async {
    _consented = settings.analyticsEnabled;
    await _analytics.initialize();
    await _analytics.setCollectionEnabled(_consented);
  }

  @override
  Future<void> setConsent({required bool enabled}) async {
    // Record the opt-out *before* collection stops, and the opt-in after it
    // starts, so the choice itself is always measurable.
    if (!enabled) {
      await _log(AnalyticsEvents.analyticsToggled, <String, Object>{
        AnalyticsParams.enabled: false,
      });
    }

    _consented = enabled;
    await _analytics.setCollectionEnabled(enabled);

    if (enabled) {
      await _log(AnalyticsEvents.analyticsToggled, <String, Object>{
        AnalyticsParams.enabled: true,
      });
    }
  }

  @override
  NavigatorObserver? get navigatorObserver => _analytics.navigatorObserver;

  // ------------------------------------------------------------ lifecycle

  @override
  Future<void> logScreen(String screenName) async {
    if (!_consented) return;
    await _analytics.logScreenView(screenName);
  }

  @override
  Future<void> logOnboardingCompleted({
    required String messId,
    required bool remindersEnabled,
  }) => _log(AnalyticsEvents.onboardingCompleted, <String, Object>{
    AnalyticsParams.messId: messId,
    AnalyticsParams.enabled: remindersEnabled,
  });

  // ------------------------------------------------------------ menu data

  @override
  Future<void> logMenuImported(Menu menu) =>
      _log(AnalyticsEvents.menuImported, _menuShape(menu));

  @override
  Future<void> logMenuImportFailed(FailureKind reason) =>
      _log(AnalyticsEvents.menuImportFailed, <String, Object>{
        AnalyticsParams.reason: reason.name,
      });

  @override
  Future<void> logMenuRefreshed(Menu menu) =>
      _log(AnalyticsEvents.menuRefreshed, _menuShape(menu));

  @override
  Future<void> logMenuRefreshFailed(FailureKind reason) =>
      _log(AnalyticsEvents.menuRefreshFailed, <String, Object>{
        AnalyticsParams.reason: reason.name,
      });

  @override
  Future<void> logEmptyPromptShown() =>
      _log(AnalyticsEvents.menuEmptyPromptShown);

  // ---------------------------------------------------------- interaction

  @override
  Future<void> logSearch({
    required String term,
    required int resultCount,
  }) {
    final trimmed = term.trim().toLowerCase();
    if (trimmed.isEmpty) return Future<void>.value();
    return _log(AnalyticsEvents.search, <String, Object>{
      AnalyticsParams.searchTerm: trimmed.length > _maxSearchTermLength
          ? trimmed.substring(0, _maxSearchTermLength)
          : trimmed,
      AnalyticsParams.resultCount: resultCount,
    });
  }

  @override
  Future<void> logMealExpanded({
    required MealType type,
    required MealStatus status,
  }) => _log(AnalyticsEvents.mealExpanded, <String, Object>{
    AnalyticsParams.mealType: type.jsonValue,
    AnalyticsParams.mealStatus: status.name,
  });

  @override
  Future<void> logDaySelected(int daysFromToday) =>
      _log(AnalyticsEvents.daySelected, <String, Object>{
        AnalyticsParams.daysFromToday: daysFromToday,
      });

  @override
  Future<void> logPullToRefresh() => _log(AnalyticsEvents.pullToRefresh);

  // -------------------------------------------------------------- settings

  @override
  Future<void> logTierChanged(String messId) async {
    await _log(AnalyticsEvents.tierChanged, <String, Object>{
      AnalyticsParams.messId: messId,
    });
    // Slow-moving trait, so reports can be segmented by plan.
    if (_consented) {
      await _analytics.setUserProperty(AnalyticsParams.messId, messId);
    }
  }

  @override
  Future<void> logMealTimingChanged({
    required MealType type,
    required bool isReset,
  }) => _log(AnalyticsEvents.mealTimingChanged, <String, Object>{
    AnalyticsParams.mealType: type.jsonValue,
    AnalyticsParams.isReset: isReset,
  });

  @override
  Future<void> logThemeChanged(AppThemeMode mode) =>
      _log(AnalyticsEvents.themeChanged, <String, Object>{
        AnalyticsParams.themeMode: mode.storageValue,
      });

  @override
  Future<void> logRemindersToggled({required bool enabled}) =>
      _log(AnalyticsEvents.remindersToggled, <String, Object>{
        AnalyticsParams.enabled: enabled,
      });

  @override
  Future<void> logRemindersBlocked() =>
      _log(AnalyticsEvents.remindersBlocked);

  // ------------------------------------------------------------ internals

  /// The shape of a document, without any dish names — enough to see whether
  /// imports are healthy, not enough to reconstruct the menu.
  Map<String, Object> _menuShape(Menu menu) {
    final days = menu.messes.isEmpty ? 0 : menu.messes.first.days.length;
    return <String, Object>{
      AnalyticsParams.month: menu.month,
      AnalyticsParams.dayCount: days,
      AnalyticsParams.tierCount: menu.messes.length,
    };
  }

  Future<void> _log(String name, [Map<String, Object>? parameters]) {
    if (!_consented) return Future<void>.value();
    return _analytics.logEvent(name, _sanitize(parameters));
  }

  /// Coerces values into what GA4 accepts.
  ///
  /// The SDK only takes `String` and `num`, and asserts on anything else — a
  /// `bool` silently costs you the whole event. Normalising here means no call
  /// site can reintroduce that.
  static Map<String, Object>? _sanitize(Map<String, Object>? parameters) {
    if (parameters == null || parameters.isEmpty) return parameters;
    return <String, Object>{
      for (final entry in parameters.entries)
        entry.key: switch (entry.value) {
          final bool value => value ? 'true' : 'false',
          final num value => value,
          final String value => value,
          final Object value => value.toString(),
        },
    };
  }
}
