/// Application-wide constants.
///
/// Everything that a maintainer may need to change when the menu source moves
/// or the campus changes lives here, so no other file hardcodes an endpoint.
class AppConfig {
  const AppConfig._();

  /// Display name of the app.
  static const String appName = 'MessMate';

  /// Campus this build targets. Used to sanity-check a downloaded document.
  static const String campus = 'VIT-AP';

  /// The single source of truth for the remote menu document.
  ///
  /// Point this at the raw URL of `menu.json` in the menu-data repository.
  /// See README.md ("Updating the monthly menu") for the publishing flow.
  static const String menuUrl =
      'https://raw.githubusercontent.com/vitap-messmate/menu-data/main/menu.json';

  /// File extensions accepted by the manual import flow.
  ///
  /// The menu is published to students as a spreadsheet, so import takes an
  /// Excel workbook. The remote document at [menuUrl] is still JSON.
  static const List<String> importExtensions = <String>['xlsx', 'xlsm'];

  /// Schema version this build understands.
  static const int supportedSchemaVersion = 1;

  /// How long to wait for the remote document before giving up.
  static const Duration networkTimeout = Duration(seconds: 12);

  /// Mess id selected when the user has not chosen one yet.
  static const String defaultMessId = 'veg-nonveg';

  /// The two subscription tiers present in the data contract.
  static const String messIdVegNonVeg = 'veg-nonveg';
  static const String messIdSpecial = 'special';

  /// Minutes before a meal opens that its reminder fires.
  static const int reminderLeadMinutes = 15;

  /// How many items a reminder previews in its body.
  static const int reminderItemPreviewCount = 3;

  /// Android notification channel.
  static const String notificationChannelId = 'messmate_meal_reminders';
  static const String notificationChannelName = 'Meal reminders';
  static const String notificationChannelDescription =
      'Reminds you shortly before each mess meal opens.';

  /// How many days ahead reminders are scheduled in one pass.
  static const int reminderHorizonDays = 7;

  /// Timezone used for scheduling when the device zone cannot be matched to a
  /// database location. VIT-AP is in India, so this is the sensible fallback.
  static const String fallbackTimeZone = 'Asia/Kolkata';

  // --------------------------------------------------------- storage keys
  static const String keyMenuDocument = 'messmate.menu.document.v1';
  static const String keyMenuLastUpdated = 'messmate.menu.lastUpdated.v1';
  static const String keyMenuSource = 'messmate.menu.source.v1';
  static const String keySettings = 'messmate.settings.v1';
}
