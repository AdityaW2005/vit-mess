import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/core/config/app_config.dart';
import 'package:vit_mess/core/constants/analytics_events.dart';
import 'package:vit_mess/core/constants/strings.dart';
import 'package:vit_mess/core/theme/app_theme.dart';
import 'package:vit_mess/core/utils/result.dart';
import 'package:vit_mess/models/app_settings.dart';
import 'package:vit_mess/models/developer.dart';
import 'package:vit_mess/models/meal.dart';
import 'package:vit_mess/models/meal_status.dart';
import 'package:vit_mess/models/menu.dart';
import 'package:vit_mess/repositories/analytics_repository.dart';
import 'package:vit_mess/repositories/app_info_repository.dart';
import 'package:vit_mess/repositories/link_repository.dart';
import 'package:vit_mess/repositories/link_repository_impl.dart';
import 'package:vit_mess/repositories/menu_repository.dart';
import 'package:vit_mess/repositories/reminder_repository.dart';
import 'package:vit_mess/repositories/settings_repository.dart';
import 'package:vit_mess/services/link_service.dart';
import 'package:vit_mess/viewmodels/settings_view_model.dart';
import 'package:vit_mess/widgets/developer_sheet.dart';

/// A platform that records what it was asked to do.
class FakeLinkService implements LinkService {
  Uri? opened;
  String? copied;
  bool openSucceeds = true;
  bool copySucceeds = true;

  @override
  Future<bool> open(Uri uri) async {
    opened = uri;
    return openSucceeds;
  }

  @override
  Future<bool> copy(String text) async {
    copied = text;
    return copySucceeds;
  }
}

/// Analytics reduced to a list of event names.
class RecordingAnalyticsRepository implements AnalyticsRepository {
  final List<String> events = <String>[];
  final List<DeveloperLinkKind> links = <DeveloperLinkKind>[];

  @override
  bool get isCollecting => true;

  @override
  NavigatorObserver? get navigatorObserver => null;

  @override
  Future<void> initialize(AppSettings settings) async {}

  @override
  Future<void> setConsent({required bool enabled}) async {}

  @override
  Future<void> logScreen(String screenName) async {}

  @override
  Future<void> logOnboardingCompleted({
    required String messId,
    required bool remindersEnabled,
  }) async {}

  @override
  Future<void> logMenuImported(Menu menu) async {}

  @override
  Future<void> logMenuImportFailed(FailureKind reason) async {}

  @override
  Future<void> logMenuRefreshed(Menu menu) async {}

  @override
  Future<void> logMenuRefreshFailed(FailureKind reason) async {}

  @override
  Future<void> logEmptyPromptShown() async {}

  @override
  Future<void> logStaleMenuImport({
    required String month,
    required bool adopted,
  }) async {}

  @override
  Future<void> logSearch({
    required String term,
    required int resultCount,
  }) async {}

  @override
  Future<void> logMealExpanded({
    required MealType type,
    required MealStatus status,
  }) async {}

  @override
  Future<void> logDaySelected(int daysFromToday) async {}

  @override
  Future<void> logPullToRefresh() async {}

  @override
  Future<void> logTierChanged(String messId) async {}

  @override
  Future<void> logMealTimingChanged({
    required MealType type,
    required bool isReset,
  }) async {}

  @override
  Future<void> logThemeChanged(AppThemeMode mode) async {}

  @override
  Future<void> logRemindersToggled({required bool enabled}) async {}

  @override
  Future<void> logRemindersBlocked() async {}

  @override
  Future<void> logDeveloperSheetOpened() async =>
      events.add(AnalyticsEvents.developerSheetOpened);

  @override
  Future<void> logDeveloperLinkOpened(DeveloperLinkKind kind) async {
    events.add(AnalyticsEvents.developerLinkOpened);
    links.add(kind);
  }
}

/// The minimum a [SettingsViewModel] needs to exist in a widget test.
class StubMenuRepository implements MenuRepository {
  @override
  Stream<MenuSnapshot> get changes => const Stream<MenuSnapshot>.empty();

  @override
  Future<Result<MenuSnapshot>> getMenu() async =>
      const Result<MenuSnapshot>.failure('none', kind: FailureKind.empty);

  @override
  Future<Result<MenuSnapshot>> refreshMenu() async => getMenu();

  @override
  Future<Result<MenuSnapshot>> importMenu({
    ConfirmStaleImport? confirmStaleMonth,
    DateTime? now,
  }) async => getMenu();

  @override
  Future<DateTime?> lastUpdated() async => null;

  @override
  Future<Result<void>> clearCache() async => const Result<void>.success(null);

  @override
  Future<void> dispose() async {}
}

class StubSettingsRepository implements SettingsRepository {
  AppSettings _current = AppSettings.initial();

  @override
  AppSettings get current => _current;

  @override
  Stream<AppSettings> get changes => const Stream<AppSettings>.empty();

  @override
  Future<Result<AppSettings>> load() async =>
      Result<AppSettings>.success(_current);

  @override
  Future<Result<AppSettings>> save(AppSettings settings) async {
    _current = settings;
    return Result<AppSettings>.success(settings);
  }

  @override
  Future<void> dispose() async {}
}

class StubAppInfoRepository implements AppInfoRepository {
  StubAppInfoRepository([this.reported = '1.0.0']);

  final String? reported;

  @override
  Future<String?> version() async => reported;
}

class StubReminderRepository implements ReminderRepository {
  @override
  Future<Result<bool>> requestPermission() async =>
      const Result<bool>.success(true);

  @override
  Future<Result<int>> reschedule({
    required Menu menu,
    required AppSettings settings,
    DateTime? now,
  }) async => const Result<int>.success(0);

  @override
  Future<void> cancelAll() async {}

  @override
  Future<ReminderStatus> status() async => const ReminderStatus(
    notificationsAllowed: true,
    exactAlarmsAllowed: true,
    pending: 0,
  );
}

void main() {
  group('DeveloperLink', () {
    test('turns an address into a mailto uri', () {
      const link = DeveloperLink(
        kind: DeveloperLinkKind.email,
        target: 'someone@example.com',
      );

      expect(link.isEmail, isTrue);
      expect(link.uri.toString(), 'mailto:someone@example.com');
    });

    test('assumes https for a target pasted without a scheme', () {
      const link = DeveloperLink(
        kind: DeveloperLinkKind.linkedin,
        target: 'linkedin.com/in/example',
      );

      expect(link.uri.toString(), 'https://linkedin.com/in/example');
    });

    test('leaves an explicit scheme alone', () {
      const link = DeveloperLink(
        kind: DeveloperLinkKind.github,
        target: 'https://github.com/example',
      );

      expect(link.uri.toString(), 'https://github.com/example');
    });
  });

  group('DeveloperProfile', () {
    test('never offers a blank link', () {
      // The build may have none configured yet; whatever it has must be real.
      for (final link in DeveloperProfile.links) {
        expect(link.target.trim(), isNotEmpty);
      }
      // Every kind the vocabulary carries has to be reachable from config,
      // or the switch below it is dead code.
      expect(
        DeveloperProfile.links.map((link) => link.kind).toSet(),
        DeveloperLinkKind.values.toSet(),
      );
    });

    test('is named, so the footer always has something to show', () {
      expect(DeveloperProfile.name.trim(), isNotEmpty);
      expect(DeveloperProfile.name, AppConfig.developerName);
      expect(DeveloperProfile.initials.trim(), isNotEmpty);
    });

    test('every kind has a button label', () {
      for (final kind in DeveloperLinkKind.values) {
        expect(Strings.developerLinkLabel(kind).trim(), isNotEmpty);
      }
    });
  });

  group('LinkRepositoryImpl', () {
    late FakeLinkService links;
    late LinkRepository repository;

    setUp(() {
      links = FakeLinkService();
      repository = LinkRepositoryImpl(links: links);
    });

    test('opens a web link and reports it was not copied', () async {
      const link = DeveloperLink(
        kind: DeveloperLinkKind.github,
        target: 'github.com/example',
      );

      final result = await repository.follow(link);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isFalse);
      expect(links.opened.toString(), 'https://github.com/example');
      expect(links.copied, isNull);
    });

    test('copies an address instead of launching it', () async {
      // A phone with no mail client would show nothing at all on a mailto.
      const link = DeveloperLink(
        kind: DeveloperLinkKind.email,
        target: 'someone@example.com',
      );

      final result = await repository.follow(link);

      expect(result.valueOrNull, isTrue);
      expect(links.copied, 'someone@example.com');
      expect(links.opened, isNull);
    });

    test('reports a refusal as a failure rather than throwing', () async {
      links.openSucceeds = false;

      final result = await repository.follow(
        const DeveloperLink(
          kind: DeveloperLinkKind.github,
          target: 'https://github.com/example',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.unsupported);
    });
  });

  group('DeveloperSheet', () {
    late FakeLinkService links;
    late RecordingAnalyticsRepository analytics;
    late SettingsViewModel viewModel;

    const github = DeveloperLink(
      kind: DeveloperLinkKind.github,
      target: 'https://github.com/example',
    );
    const email = DeveloperLink(
      kind: DeveloperLinkKind.email,
      target: 'someone@example.com',
    );

    setUp(() {
      links = FakeLinkService();
      analytics = RecordingAnalyticsRepository();
      viewModel = SettingsViewModel(
        menuRepository: StubMenuRepository(),
        settingsRepository: StubSettingsRepository(),
        reminderRepository: StubReminderRepository(),
        analyticsRepository: analytics,
        linkRepository: LinkRepositoryImpl(links: links),
        appInfoRepository: StubAppInfoRepository(),
      );
    });

    tearDown(() => viewModel.dispose());

    Future<void> pumpSheet(
      WidgetTester tester, {
      List<DeveloperLink> configured = const <DeveloperLink>[github, email],
    }) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: DeveloperSheet(viewModel: viewModel, links: configured),
        ),
      ),
    );

    testWidgets('introduces the developer', (tester) async {
      await pumpSheet(tester);

      expect(find.text(AppConfig.developerName), findsOneWidget);
      expect(find.text(AppConfig.developerRole), findsOneWidget);
      expect(find.text(AppConfig.developerInitials), findsOneWidget);
    });

    testWidgets('shows a button for each configured link', (tester) async {
      await pumpSheet(tester);

      expect(find.text(Strings.developerGithubLabel), findsOneWidget);
      expect(find.text(Strings.developerEmailLabel), findsOneWidget);
      // Nothing was configured for this one, so nothing is offered.
      expect(find.text(Strings.developerLinkedInLabel), findsNothing);
    });

    testWidgets('draws the real brand marks, not a stand-in', (tester) async {
      await pumpSheet(
        tester,
        configured: const <DeveloperLink>[
          github,
          DeveloperLink(
            kind: DeveloperLinkKind.linkedin,
            target: 'https://linkedin.com/in/example',
          ),
        ],
      );

      // FaIcon, not Icon: the brand glyphs are not square and Icon clips them.
      final marks = tester
          .widgetList<FaIcon>(find.byType(FaIcon))
          .map((widget) => widget.icon)
          .toList();
      expect(marks, <IconData>[
        FontAwesomeIcons.github.data,
        FontAwesomeIcons.linkedinIn.data,
      ]);
    });

    testWidgets('says so when no link is configured yet', (tester) async {
      await pumpSheet(tester, configured: const <DeveloperLink>[]);

      expect(
        tester.getSize(find.byType(DeveloperSheet)).width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
    });

    testWidgets('opens a link and records the tap', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text(Strings.developerGithubLabel));
      await tester.pumpAndSettle();

      expect(links.opened.toString(), 'https://github.com/example');
      expect(analytics.links, <DeveloperLinkKind>[DeveloperLinkKind.github]);
    });

    testWidgets('confirms a copied address in place, then reverts', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.tap(find.text(Strings.developerEmailLabel));
      await tester.pump();

      // The confirmation lives in the button: a snack bar would be hidden
      // behind the sheet.
      expect(links.copied, 'someone@example.com');
      expect(find.text(Strings.developerEmailCopied), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text(Strings.developerEmailCopied), findsNothing);
      expect(find.text(Strings.developerEmailLabel), findsOneWidget);
    });

    testWidgets('explains a link that would not open', (tester) async {
      links.openSucceeds = false;
      await pumpSheet(tester);

      await tester.tap(find.text(Strings.developerGithubLabel));
      await tester.pumpAndSettle();

      expect(find.text(Strings.developerLinkFailed), findsOneWidget);
    });

    testWidgets('drops its timer when dismissed mid-confirmation', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.tap(find.text(Strings.developerEmailLabel));
      await tester.pump();

      // Tearing the sheet down while the revert is pending must not fire a
      // setState on a dead State.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in light mode too', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DeveloperSheet(
              viewModel: viewModel,
              links: const <DeveloperLink>[github],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(AppConfig.developerName), findsOneWidget);
    });
  });
}
