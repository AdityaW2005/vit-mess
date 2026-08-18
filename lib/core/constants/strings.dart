import 'package:intl/intl.dart';

import '../../models/app_settings.dart';
import '../../models/meal.dart';
import '../../models/menu.dart';

/// Every user-facing string in the app.
///
/// Widgets never hold literal copy; they read it from here. Keeping it in one
/// place makes the tone consistent and leaves a single file to translate.
class Strings {
  const Strings._();

  // ------------------------------------------------------------------ app
  static const String appName = 'MessMate';
  static const String appTagline = 'Your mess, minus the guesswork';

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
  static const String homeToday = 'Today';
  static const String homeClosesIn = 'closes in';
  static const String homeStartsIn = 'starts in';
  static const String homeClosingNow = 'Closing now';
  static const String homeOpeningNow = 'Opening now';
  static const String homePullToRefresh = 'Pull down to refresh';
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
  static const String weekSwipeHint = 'Swipe to change day';

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
  static const String settingsPlanSubtitle =
      'Switch the tier you are subscribed to.';
  static const String settingsTimingsSection = 'Meal timings';
  static const String settingsTimingsSubtitle =
      'The published times are approximate. Override them to match your mess.';
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
  static const String settingsImport = 'Import a menu spreadsheet';
  static const String settingsImportSubtitle =
      'Load the Excel file (.xlsx) shared by the mess office.';
  static const String settingsNeverUpdated = 'Never updated';
  static const String settingsAppearanceSection = 'Appearance';
  static const String settingsAppearanceSubtitle =
      'MessMate is designed dark-first, but both themes are here.';
  static const String settingsThemeSystem = 'System';
  static const String settingsThemeLight = 'Light';
  static const String settingsThemeDark = 'Dark';
  static const String settingsAboutSection = 'About';
  static const String settingsSchemaLabel = 'Menu format';
  static const String settingsCampusLabel = 'Campus';
  static const String settingsMonthLabel = 'Menu month';

  // --------------------------------------------------------------- states
  static const String errorGenericTitle = 'Something went sideways';
  static const String errorOfflineTitle = "Can't reach the menu";
  static const String errorOfflineBody =
      'You are offline, or the menu server is down. Nothing is cached yet, so '
      'there is nothing to show.';
  static const String errorParseTitle = "That file doesn't look right";
  static const String errorParseTitleSheet = "That sheet couldn't be read";
  static const String errorParseBody =
      'The menu file could not be read. It may be for a different app version.';
  static const String errorRetry = 'Try again';
  static const String errorImportInstead = 'Import a spreadsheet instead';

  // ------------------------------------------------------- import prompt
  static const String importPromptTitle = 'Import your mess menu';
  static const String importPromptBody =
      'MessMate has no menu yet. Import the Excel sheet the mess office '
      'shared, and it will be saved on this device for offline use.';
  static const String importPromptAction = 'Choose a spreadsheet';
  static const String importPromptRetry = 'Try downloading instead';
  static const String importPromptFormatHint =
      'Accepts .xlsx with a Date column and Breakfast, Lunch, Snacks and '
      'Dinner columns — or one row per dish.';

  // --------------------------------------------------------------- toasts
  static const String toastRefreshed = 'Menu updated';
  static const String toastImported = 'Menu imported';
  static const String toastImportedNamed = 'Imported';
  static const String toastPlanChanged = 'Mess plan updated';
  static const String toastTimingsReset = 'Timings reset';
  static const String toastRemindersBlocked =
      'Notifications are blocked. Enable them in your device settings.';
  static const String toastRemindersScheduled = 'Reminders scheduled';

  // ------------------------------------------------------- notifications
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
  static const String failureEmpty =
      'No menu is available yet. Import the spreadsheet to get started.';
  static const String failureCancelled = 'Import cancelled.';
  static const String failureUnknown =
      'Something went wrong loading the menu. Please try again.';

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

  // ------------------------------------------------------------ variants
  static const String variantVeg = 'Veg';
  static const String variantNonVeg = 'Non-veg';
  static const String variantOr = 'or';

  // ----------------------------------------------------------- formatters

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

  /// Display name for a menu source, used on the "last updated" line.
  static String menuSourceLabel(MenuSource source) => switch (source) {
    MenuSource.cache => 'Saved on this device',
    MenuSource.network => 'Downloaded',
    MenuSource.imported => 'Imported file',
  };

  /// A countdown, at the coarsest useful precision.
  ///
  /// Seconds only appear inside the last minute, so the digits do not churn
  /// distractingly for the other 99% of the time.
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
  static String formatMonth(DateTime date) =>
      DateFormat('MMMM y').format(date);

  /// How far away a date is, in the words a student would use.
  static String relativeDay(int daysFromToday) {
    if (daysFromToday <= 0) return 'Today';
    if (daysFromToday == 1) return 'Tomorrow';
    return 'In $daysFromToday days';
  }

  /// `Updated 5 min ago`, or the date once it is more than a day old.
  static String lastUpdated(DateTime? timestamp, DateTime now) {
    if (timestamp == null) return settingsNeverUpdated;
    final elapsed = now.difference(timestamp);
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Updated just now';
    if (elapsed.inHours < 1) return 'Updated ${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24) {
      final hours = elapsed.inHours;
      return 'Updated $hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    if (elapsed.inDays < 7) {
      final days = elapsed.inDays;
      return 'Updated $days ${days == 1 ? 'day' : 'days'} ago';
    }
    return 'Updated ${DateFormat('d MMM').format(timestamp)}';
  }

  /// `3 items` / `1 item`.
  static String itemCount(int count) =>
      '$count ${count == 1 ? 'item' : 'items'}';

  /// `Breakfast closes in 42 min` style hero subtitle.
  static String countdownSentence({
    required MealType type,
    required bool isServing,
    required Duration remaining,
  }) =>
      '${mealName(type)} ${isServing ? homeClosesIn : homeStartsIn} '
      '${formatCountdown(remaining)}';

  /// Notification title, e.g. `Lunch opens in 15 min`.
  static String reminderTitle(MealType type) =>
      '${mealName(type)} $notificationTitlePrefix';

  /// Notification body: the first few dishes, comma separated.
  static String reminderBody(List<String> itemNames) => itemNames.join(', ');

  /// `2 results` / `1 result`.
  static String resultCount(int count) =>
      '$count ${count == 1 ? 'result' : 'results'}';
}
