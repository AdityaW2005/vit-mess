import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/core/constants/analytics_events.dart';
import 'package:vit_mess/core/utils/result.dart';
import 'package:vit_mess/models/app_settings.dart';
import 'package:vit_mess/models/meal.dart';
import 'package:vit_mess/models/meal_status.dart';
import 'package:vit_mess/models/menu.dart';
import 'package:vit_mess/repositories/analytics_repository_impl.dart';
import 'package:vit_mess/services/analytics_service.dart';

/// Records what would have been sent, so the schema can be asserted without
/// a Firebase project.
class FakeAnalyticsService implements AnalyticsService {
  final List<(String, Map<String, Object>?)> events =
      <(String, Map<String, Object>?)>[];
  final List<String> screens = <String>[];
  final Map<String, String?> userProperties = <String, String?>{};

  bool available = true;
  bool? collectionEnabled;
  int initializeCount = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<bool> initialize() async {
    initializeCount++;
    return available;
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    events.add((name, parameters));
  }

  @override
  Future<void> logScreenView(String screenName) async {
    screens.add(screenName);
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProperties[name] = value;
  }

  @override
  Null get navigatorObserver => null;

  /// Names of everything recorded, in order.
  List<String> get names => events.map((e) => e.$1).toList();

  /// Parameters of the last event with [name].
  Map<String, Object>? paramsFor(String name) =>
      events.lastWhere((e) => e.$1 == name).$2;
}

Menu buildMenu() =>
    Menu.decode('''
{
  "schemaVersion": 1,
  "month": "2026-08",
  "campus": "VIT-AP",
  "messes": [
    { "id": "veg-nonveg", "name": "Veg & Non-Veg", "days": [
      { "date": "2026-08-17", "weekday": "Mon", "meals": [
        { "type": "lunch", "items": [{ "name": "Rice", "variant": null }] }
      ]}
    ]}
  ]
}
''')!;

void main() {
  late FakeAnalyticsService service;
  late AnalyticsRepositoryImpl analytics;

  setUp(() {
    service = FakeAnalyticsService();
    analytics = AnalyticsRepositoryImpl(analytics: service);
  });

  group('consent', () {
    test('applies the stored choice on startup', () async {
      await analytics.initialize(
        AppSettings.initial().copyWith(analyticsEnabled: false),
      );

      expect(service.initializeCount, 1);
      expect(service.collectionEnabled, isFalse);
      expect(analytics.isCollecting, isFalse);
    });

    test('collects by default', () async {
      await analytics.initialize(AppSettings.initial());

      expect(service.collectionEnabled, isTrue);
      expect(analytics.isCollecting, isTrue);
    });

    test('records nothing at all once opted out', () async {
      await analytics.initialize(AppSettings.initial());
      await analytics.setConsent(enabled: false);
      service.events.clear();
      service.screens.clear();

      await analytics.logScreen('home');
      await analytics.logPullToRefresh();
      await analytics.logSearch(term: 'biryani', resultCount: 2);
      await analytics.logTierChanged('special');

      expect(service.events, isEmpty);
      expect(service.screens, isEmpty);
    });

    test('stops collection at the SDK, not just at the call site', () async {
      await analytics.initialize(AppSettings.initial());
      await analytics.setConsent(enabled: false);

      expect(service.collectionEnabled, isFalse);
    });

    test('the opt-out itself is recorded before collection stops', () async {
      await analytics.initialize(AppSettings.initial());
      await analytics.setConsent(enabled: false);

      expect(service.names, contains(AnalyticsEvents.analyticsToggled));
      expect(
        service.paramsFor(AnalyticsEvents.analyticsToggled),
        containsPair(AnalyticsParams.enabled, false),
      );
    });

    test('opting back in resumes collection and is recorded', () async {
      await analytics.initialize(AppSettings.initial());
      await analytics.setConsent(enabled: false);
      service.events.clear();

      await analytics.setConsent(enabled: true);

      expect(service.collectionEnabled, isTrue);
      expect(analytics.isCollecting, isTrue);
      expect(
        service.paramsFor(AnalyticsEvents.analyticsToggled),
        containsPair(AnalyticsParams.enabled, true),
      );
    });

    test('is not collecting when Firebase is unconfigured', () async {
      service.available = false;
      await analytics.initialize(AppSettings.initial());

      // Consent is granted, but there is nowhere to send anything.
      expect(analytics.isCollecting, isFalse);
    });
  });

  group('event schema', () {
    setUp(() async {
      await analytics.initialize(AppSettings.initial());
      service.events.clear();
    });

    test('search carries the term and the result count', () async {
      await analytics.logSearch(term: '  Chicken Biryani ', resultCount: 4);

      expect(service.names, <String>[AnalyticsEvents.search]);
      expect(service.paramsFor(AnalyticsEvents.search), <String, Object>{
        AnalyticsParams.searchTerm: 'chicken biryani',
        AnalyticsParams.resultCount: 4,
      });
    });

    test('an empty search is not an event', () async {
      await analytics.logSearch(term: '   ', resultCount: 0);
      expect(service.events, isEmpty);
    });

    test('a very long search term is truncated', () async {
      await analytics.logSearch(term: 'a' * 500, resultCount: 0);

      final term =
          service.paramsFor(AnalyticsEvents.search)![AnalyticsParams.searchTerm]!
              as String;
      expect(term.length, 100);
    });

    test('menu events carry shape, never dish names', () async {
      await analytics.logMenuImported(buildMenu());

      final params = service.paramsFor(AnalyticsEvents.menuImported)!;
      expect(params[AnalyticsParams.month], '2026-08');
      expect(params[AnalyticsParams.dayCount], 1);
      expect(params[AnalyticsParams.tierCount], 1);
      expect(params.values.join(' '), isNot(contains('Rice')));
    });

    test('failures carry a machine-readable reason', () async {
      await analytics.logMenuImportFailed(FailureKind.parse);
      await analytics.logMenuRefreshFailed(FailureKind.network);

      expect(
        service.paramsFor(AnalyticsEvents.menuImportFailed),
        containsPair(AnalyticsParams.reason, 'parse'),
      );
      expect(
        service.paramsFor(AnalyticsEvents.menuRefreshFailed),
        containsPair(AnalyticsParams.reason, 'network'),
      );
    });

    test('a tier change also sets the user property', () async {
      await analytics.logTierChanged('special');

      expect(
        service.paramsFor(AnalyticsEvents.tierChanged),
        containsPair(AnalyticsParams.messId, 'special'),
      );
      expect(service.userProperties[AnalyticsParams.messId], 'special');
    });

    test('meal expansion carries slot and state', () async {
      await analytics.logMealExpanded(
        type: MealType.dinner,
        status: MealStatus.servingNow,
      );

      expect(service.paramsFor(AnalyticsEvents.mealExpanded), <String, Object>{
        AnalyticsParams.mealType: 'dinner',
        AnalyticsParams.mealStatus: 'servingNow',
      });
    });

    test('theme and reminder toggles carry their new value', () async {
      await analytics.logThemeChanged(AppThemeMode.dark);
      await analytics.logRemindersToggled(enabled: false);

      expect(
        service.paramsFor(AnalyticsEvents.themeChanged),
        containsPair(AnalyticsParams.themeMode, 'dark'),
      );
      expect(
        service.paramsFor(AnalyticsEvents.remindersToggled),
        containsPair(AnalyticsParams.enabled, false),
      );
    });

    test('screen views go through the dedicated channel', () async {
      await analytics.logScreen(AnalyticsScreens.week);
      expect(service.screens, <String>['week']);
    });
  });

  group('event names are GA4-legal', () {
    test('every name fits the 40-character identifier rules', () {
      const names = <String>[
        AnalyticsEvents.screenView,
        AnalyticsEvents.onboardingCompleted,
        AnalyticsEvents.menuImported,
        AnalyticsEvents.menuImportFailed,
        AnalyticsEvents.menuRefreshed,
        AnalyticsEvents.menuRefreshFailed,
        AnalyticsEvents.menuEmptyPromptShown,
        AnalyticsEvents.search,
        AnalyticsEvents.mealExpanded,
        AnalyticsEvents.daySelected,
        AnalyticsEvents.pullToRefresh,
        AnalyticsEvents.tierChanged,
        AnalyticsEvents.mealTimingChanged,
        AnalyticsEvents.themeChanged,
        AnalyticsEvents.remindersToggled,
        AnalyticsEvents.remindersBlocked,
        AnalyticsEvents.analyticsToggled,
      ];

      final legal = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
      for (final name in names) {
        expect(legal.hasMatch(name), isTrue, reason: name);
      }
      expect(names.toSet(), hasLength(names.length), reason: 'duplicate name');
    });
  });
}
