import 'package:flutter/widgets.dart' show NavigatorObserver;

import '../core/utils/result.dart';
import '../models/app_settings.dart';
import '../models/developer.dart';
import '../models/meal.dart';
import '../models/meal_status.dart';
import '../models/menu.dart';

/// Records what students do, so the menu can be improved with evidence.
///
/// The ViewModel layer talks to this, never to the Firebase SDK. Consent lives
/// here too: with analytics switched off, nothing is recorded at all.
///
/// Nothing on this interface returns a failure — analytics must never be able
/// to interrupt what the student was doing.
abstract class AnalyticsRepository {
  /// True when events can actually leave the device: Firebase is configured
  /// *and* the student has not opted out.
  bool get isCollecting;

  /// Starts the SDK and applies the stored consent choice.
  Future<void> initialize(AppSettings settings);

  /// Applies a changed consent choice, and records the change itself.
  Future<void> setConsent({required bool enabled});

  /// A navigator observer for automatic route tracking, or `null` when
  /// analytics is unavailable.
  NavigatorObserver? get navigatorObserver;

  // ------------------------------------------------------------ lifecycle

  /// A tab or screen came to the front.
  Future<void> logScreen(String screenName);

  /// Onboarding finished.
  Future<void> logOnboardingCompleted({
    required String messId,
    required bool remindersEnabled,
  });

  // ------------------------------------------------------------ menu data

  /// A spreadsheet was parsed and adopted.
  Future<void> logMenuImported(Menu menu);

  /// A spreadsheet could not be used.
  Future<void> logMenuImportFailed(FailureKind reason);

  /// The remote document was downloaded and adopted.
  Future<void> logMenuRefreshed(Menu menu);

  /// A download attempt produced nothing.
  Future<void> logMenuRefreshFailed(FailureKind reason);

  /// The app had no menu and showed the import prompt.
  Future<void> logEmptyPromptShown();

  /// A spreadsheet for a month that has already passed was chosen, and either
  /// adopted anyway or abandoned.
  Future<void> logStaleMenuImport({
    required String month,
    required bool adopted,
  });

  // ---------------------------------------------------------- interaction

  /// A dish search ran.
  Future<void> logSearch({required String term, required int resultCount});

  /// A meal card was expanded.
  Future<void> logMealExpanded({
    required MealType type,
    required MealStatus status,
  });

  /// A different day was chosen in the month browser.
  Future<void> logDaySelected(int daysFromToday);

  /// The home screen was pulled to refresh.
  Future<void> logPullToRefresh();

  // -------------------------------------------------------------- settings

  /// The subscription tier changed.
  Future<void> logTierChanged(String messId);

  /// A meal window was overridden or reset.
  Future<void> logMealTimingChanged({
    required MealType type,
    required bool isReset,
  });

  /// The theme choice changed.
  Future<void> logThemeChanged(AppThemeMode mode);

  /// Meal reminders were switched on or off.
  Future<void> logRemindersToggled({required bool enabled});

  /// The platform refused notification permission.
  Future<void> logRemindersBlocked();

  // ------------------------------------------------------------- developer

  /// The about-the-developer sheet was opened.
  Future<void> logDeveloperSheetOpened();

  /// One of the sheet's links was followed.
  Future<void> logDeveloperLinkOpened(DeveloperLinkKind kind);
}
