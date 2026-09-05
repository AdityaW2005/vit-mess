import 'package:intl/intl.dart';

import '../../models/app_settings.dart';
import '../../models/developer.dart';
import '../../models/meal.dart';

/// Every user-facing string in the app.
///
/// Widgets never hold literal copy; they read it from here. Keeping it in one
/// place makes the tone consistent and leaves a single file to translate.
class Strings {
  const Strings._();

  // ------------------------------------------------------------------ app
  static const String appName = 'MessUp';

  // ----------------------------------------------------------- navigation
  static const String navHome = 'Today';
  static const String navWeek = 'Week';
  static const String navSearch = 'Search';
  static const String navSettings = 'Settings';

  // ----------------------------------------------------------- onboarding
  static const String onboardingTitle = 'Pick your mess plan';
  static const String onboardingSubtitle =
      'This is the plan you are subscribed to. You can change it later in '
      'Settings.';
  static const String onboardingTierVegNonVegName = 'Veg & Non-Veg';
  static const String onboardingTierVegNonVegBlurb =
      'The standard plan. Both veg and non-veg options at lunch and dinner.';
  static const String onboardingTierSpecialName = 'Special';
  static const String onboardingTierSpecialBlurb =
      'The premium plan. Extra sides, desserts and beverages at every meal.';
  static const String onboardingRemindersTitle = 'Meal reminders';
  static const String onboardingRemindersBlurb =
      'A nudge 15 minutes before each meal opens. You can fine-tune which '
      'meals later.';
  static const String onboardingContinue = 'Start eating well';
  static const String onboardingSelectedHint = 'Selected';

  // ----------------------------------------------------------------- home
  static const String homeNowServing = 'Now serving';
  static const String homeUpNext = 'Up next';
  static const String homeRestOfDay = 'Rest of the day';
  static const String homeTomorrow = 'Tomorrow';
  static const String homeClosesIn = 'closes in';
  static const String homeStartsIn = 'starts in';
  static const String homeMenuUnavailableTitle =
      "This month's menu isn't up yet";
  static const String homeMenuUnavailableBody =
      'The mess office publishes the new menu at the start of each month. '
      'Pull down to check again, or import a file if someone has shared one.';
  static const String homeNoMealsTitle = 'Nothing listed for today';
  static const String homeNoMealsBody =
      'The menu document has no meals for this date.';

  // ----------------------------------------------------------------- week
  static const String weekTitle = 'This month';

  // --------------------------------------------------------------- search
  static const String searchTitle = 'Search the menu';
  static const String searchHint = 'Try "chicken biryani" or "dosa"';
  static const String searchClear = 'Clear search';
  static const String searchEmptyTitle = 'What are you hunting for?';
  static const String searchEmptyBody =
      'Search every meal this month to find out when a dish is next served.';
  static const String searchNoResultsTitle = 'No dish matches that';
  static const String searchNoResultsBody =
      'Check the spelling, or try a shorter word.';

  // ------------------------------------------------------------- settings
  static const String settingsTitle = 'Settings';
  static const String settingsPlanSection = 'Mess plan';
  static const String settingsTimingsSection = 'Meal timings';
  static const String settingsTimingsReset = 'Reset to published times';
  static const String settingsTimingsOverridden = 'Custom';
  static const String settingsTimingsInvalid =
      'A meal has to close after it opens.';
  static const String settingsRemindersSection = 'Reminders';
  static const String settingsRemindersSubtitle =
      'Fires 15 minutes before a meal opens.';
  static const String settingsRemindersMaster = 'Meal reminders';
  static const String settingsDataSection = 'Menu data';
  static const String settingsForceRefresh = 'Refresh now';
  static const String settingsMenuLoaded = 'Menu loaded';
  static const String settingsMenuMissing = 'No menu yet';
  static const String settingsMenuMissingBody =
      'Import the spreadsheet to see what is being served.';
  static const String settingsImport = 'Import a menu spreadsheet';
  static const String settingsImportSubtitle =
      'Load the Excel file (.xlsx) shared by the mess committee.';
  static const String settingsNeverUpdated = 'Never updated';
  static const String settingsAppearanceSection = 'Appearance';
  static const String settingsThemeSystem = 'System';
  static const String settingsThemeLight = 'Light';
  static const String settingsThemeDark = 'Dark';
  static const String settingsAboutSection = 'About';
  static const String settingsCampusLabel = 'Campus';
  static const String settingsMonthLabel = 'Menu month';

  // --------------------------------------------------------------- states
  static const String errorGenericTitle = 'Something went sideways';
  static const String errorOfflineTitle = "Can't reach the menu";
  static const String errorOfflineBody =
      'You are offline, or the menu server is down. Nothing is cached yet, so '
      'there is nothing to show.';
  static const String errorParseTitleSheet = "That sheet couldn't be read";
  static const String errorRetry = 'Try again';
  static const String errorImportInstead = 'Import a spreadsheet instead';

  // ------------------------------------------------------- import prompt
  static const String importPromptTitle = 'Import your mess menu';
  static const String importPromptBody =
      'MessUp has no menu yet. Import the Excel sheet the mess office '
      'shared, and it will be saved on this device for offline use.';
  static const String importPromptAction = 'Choose a spreadsheet';
  static const String importPromptRetry = 'Try downloading instead';
  static const String importPromptFormatHint =
      'Accepts .xlsx with a Date column and Breakfast, Lunch, Snacks and '
      'Dinner columns — or one row per dish.';

  // --------------------------------------------------------------- toasts
  static const String toastRefreshed = 'Menu updated';
  static const String toastImported = 'Menu imported';
  static const String toastTimingsReset = 'Timings reset';
  static const String toastRemindersBlocked =
      'Notifications are blocked. Enable them in your device settings.';
  static const String toastRemindersScheduled = 'Reminders scheduled';

  // ------------------------------------------------------- notifications
  static const String settingsRemindersBlockedOs =
      'Notifications are switched off for MessUp in your device settings, so '
      'reminders cannot be delivered.';
  static const String settingsExactAlarmsOff =
      'Android may delay reminders because exact alarms are not allowed. '
      'Grant "Alarms & reminders" in system settings for on-time nudges.';
  static const String notificationTitlePrefix = 'opens in 15 min';

  // ------------------------------------------------------------ failures
  static const String failureNetwork =
      'Could not reach the menu server. Check your connection and try again.';
  static const String failureParse =
      'The menu file could not be read — it may be corrupted or out of date.';
  static const String failureNotSpreadsheet =
      'That file could not be opened. Pick an Excel workbook (.xlsx).';
  static const String failureSpreadsheetShape =
      'No menu rows were found in that sheet. It needs a Date column and a '
      'column per meal, or one row per dish.';
  static const String failureStorage =
      'Could not save to this device. Free up some space and try again.';
  static const String failureNoRemote =
      'No menu server is set up yet, so there is nothing to download. Import '
      'the spreadsheet instead.';
  static const String failureEmpty =
      'No menu is available yet. Import the spreadsheet to get started.';
  static const String failureCancelled = 'Import cancelled.';
  static const String failureUnknown =
      'Something went wrong loading the menu. Please try again.';

  // ------------------------------------------------- out-of-date spreadsheet
  static const String staleImportTitle = 'This menu has expired';
  static const String staleImportAccept = 'Import anyway';
  static const String staleImportCancel = 'Keep current menu';
  static const String staleImportDismiss = 'Choose another file';

  /// Explains what the chosen spreadsheet covers and what accepting it costs.
  static String staleImportBody({
    required String month,
    String? currentMonth,
  }) {
    final chosen = formatMonthKey(month);
    if (currentMonth == null) {
      return 'This spreadsheet is for $chosen, which has already passed. '
          'Today and Week will have nothing to show.';
    }
    return 'This spreadsheet is for $chosen, which has already passed. '
        'Importing it replaces your ${formatMonthKey(currentMonth)} menu and '
        'clears any meal reminders.';
  }

  /// Shown in Menu data when the loaded document is out of date.
  static const String settingsMenuExpired = 'Menu has expired';

  /// Reported when the student backs out of an out-of-date import.
  static const String failureStaleDeclined = 'Import cancelled.';

  // ------------------------------------------------------------- developer
  /// The Settings footer. The name itself is the tappable part.
  static const String developerCreatedBy = 'Created by';

  /// Button labels, in the order the sheet lays them out.
  static const String developerGithubLabel = 'Check my works';
  static const String developerLinkedInLabel = 'Connect with me';
  static const String developerEmailLabel = 'Copy my email';

  /// The build version, shown under the footer byline.
  static String appVersionLabel(String version) => 'v$version';

  /// Confirmations.
  static const String developerEmailCopied = 'Email copied to clipboard';
  static const String developerLinkFailed = 'Could not open that link.';

  /// The label for one of the sheet's buttons.
  static String developerLinkLabel(DeveloperLinkKind kind) => switch (kind) {
    DeveloperLinkKind.github => developerGithubLabel,
    DeveloperLinkKind.linkedin => developerLinkedInLabel,
    DeveloperLinkKind.email => developerEmailLabel,
  };

  // ---------------------------------------------------------- a11y labels
  static const String a11yRefresh = 'Refresh the menu';
  static const String a11yExpandMeal = 'Expand meal';
  static const String a11yCollapseMeal = 'Collapse meal';
  static const String a11yVegItem = 'Vegetarian';
  static const String a11yNonVegItem = 'Non-vegetarian';
  static const String a11yPairedItem =
      'Paired alternative: one of these is served depending on your plan';
  static const String a11ySelectDay = 'Select day';
  static const String a11ySelectTheme = 'Select theme';
  static const String a11yAboutDeveloper = 'About the developer';

  // ------------------------------------------------------------ variants
  static const String variantOr = 'or';

  // ----------------------------------------------------------- formatters

  /// `Sun & Mon: 7:15 AM – 9:15 AM`, the one slot that runs two clocks.
  static String lateBreakfastNote() =>
      'Sun & Mon: '
      '${formatWindow(MealType.lateBreakfastStart, MealType.lateBreakfastEnd)}';

  /// Display name for a theme choice.
  static String themeModeLabel(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => settingsThemeSystem,
    AppThemeMode.light => settingsThemeLight,
    AppThemeMode.dark => settingsThemeDark,
  };

  /// Display name for a meal slot.
  static String mealName(MealType type) => switch (type) {
    MealType.breakfast => 'Breakfast',
    MealType.lunch => 'Lunch',
    MealType.snacks => 'Snacks',
    MealType.dinner => 'Dinner',
  };

  /// `2h 15m`, `43 min`, `12 sec` — the coarsest unit that stays truthful.
  static String formatCountdown(Duration duration) {
    if (duration <= Duration.zero) return '0 sec';
    if (duration.inHours >= 1) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
    }
    if (duration.inMinutes >= 1) return '${duration.inMinutes} min';
    return '${duration.inSeconds} sec';
  }

  /// `7:00 AM` for a wall-clock time.
  static String formatClock(MinuteOfDay time) {
    final asDate = DateTime(2000, 1, 1, time.hour, time.minute);
    return DateFormat.jm().format(asDate);
  }

  /// `7:00 AM – 9:30 AM` for a serving window.
  static String formatWindow(MinuteOfDay start, MinuteOfDay end) =>
      '${formatClock(start)} – ${formatClock(end)}';

  /// `Mon 17 Aug` for a day header.
  static String formatDayHeading(DateTime date) =>
      DateFormat('EEE d MMM').format(date);

  /// `17 August` for a search result group.
  static String formatDayLong(DateTime date) =>
      DateFormat('d MMMM').format(date);

  /// `August 2026` for a month label.
  static String formatMonth(DateTime date) => DateFormat('MMMM y').format(date);

  /// Turns a `yyyy-MM` contract key into `August 2026`.
  ///
  /// The stored form is a sortable code; nobody wants to read "2026-08" in the
  /// UI. Falls back to whatever was stored if it is not a recognisable key.
  static String formatMonthKey(String? monthKey) {
    final raw = monthKey?.trim() ?? '';
    if (raw.isEmpty) return '—';

    final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(raw);
    if (match == null) return raw;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) return raw;

    return formatMonth(DateTime(year, month));
  }

  /// How far away a date is, in the words a student would use.
  static String relativeDay(int daysFromToday) {
    if (daysFromToday <= 0) return 'Today';
    if (daysFromToday == 1) return 'Tomorrow';
    return 'In $daysFromToday days';
  }

  /// `August 2026 · 31 days · 2 plans` — what a loaded document covers.
  static String menuCoverage({
    required String? month,
    required int days,
    required int tiers,
  }) => <String>[
    formatMonthKey(month),
    '$days ${days == 1 ? 'day' : 'days'}',
    '$tiers ${tiers == 1 ? 'plan' : 'plans'}',
  ].join('  ·  ');

  /// `3 items` / `1 item`.
  static String itemCount(int count) =>
      '$count ${count == 1 ? 'item' : 'items'}';

  /// Notification title, e.g. `Lunch opens in 15 min`.
  static String reminderTitle(MealType type) =>
      '${mealName(type)} $notificationTitlePrefix';

  /// Notification body: the first few dishes, comma separated.
  static String reminderBody(List<String> itemNames) => itemNames.join(', ');

  /// `2 results` / `1 result`.
  static String resultCount(int count) =>
      '$count ${count == 1 ? 'result' : 'results'}';
}
