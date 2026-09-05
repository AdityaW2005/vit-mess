/// The complete analytics vocabulary.
///
/// Every event and parameter name the app can send lives here, so the schema
/// is reviewable in one place and no call site invents a stringly-typed name.
/// GA4 rules the names have to respect: 40 characters max, letters, digits and
/// underscores only, and no more than 25 parameters per event.
class AnalyticsEvents {
  const AnalyticsEvents._();

  // ------------------------------------------------------------- lifecycle
  /// A tab or screen came to the front. Uses GA4's reserved `screen_view`.
  static const String screenView = 'screen_view';

  /// Onboarding finished, carrying the tier the student picked.
  static const String onboardingCompleted = 'onboarding_completed';

  // ------------------------------------------------------------ menu data
  /// A spreadsheet was parsed and adopted.
  static const String menuImported = 'menu_imported';

  /// A spreadsheet was chosen but could not be used.
  static const String menuImportFailed = 'menu_import_failed';

  /// The remote JSON document was downloaded and adopted.
  static const String menuRefreshed = 'menu_refreshed';

  /// A download attempt did not produce a menu.
  static const String menuRefreshFailed = 'menu_refresh_failed';

  /// The app had no menu at all and showed the import prompt.
  static const String menuEmptyPromptShown = 'menu_empty_prompt_shown';

  // ---------------------------------------------------------- interaction
  /// A dish search ran. Uses GA4's reserved `search` event.
  static const String search = 'search';

  /// A meal card was expanded to reveal its dishes.
  static const String mealExpanded = 'meal_expanded';

  /// A different day was selected in the month browser.
  static const String daySelected = 'day_selected';

  /// The student pulled to refresh on the home screen.
  static const String pullToRefresh = 'pull_to_refresh';

  // -------------------------------------------------------------- settings
  /// The subscription tier changed.
  static const String tierChanged = 'tier_changed';

  /// A meal window was overridden or reset.
  static const String mealTimingChanged = 'meal_timing_changed';

  /// The light/dark/system choice changed.
  static const String themeChanged = 'theme_changed';

  /// Meal reminders were switched on or off.
  static const String remindersToggled = 'reminders_toggled';

  /// The platform refused notification permission.
  static const String remindersBlocked = 'reminders_blocked';

  /// Analytics collection itself was switched on or off.
  static const String analyticsToggled = 'analytics_toggled';

  // ------------------------------------------------------------- developer
  /// The about-the-developer sheet was opened from the Settings footer.
  static const String developerSheetOpened = 'developer_sheet_opened';

  /// One of the sheet's links was followed.
  static const String developerLinkOpened = 'developer_link_opened';
}

/// Parameter keys used by [AnalyticsEvents].
class AnalyticsParams {
  const AnalyticsParams._();

  /// GA4 reserved: the screen a `screen_view` refers to.
  static const String screenName = 'screen_name';

  /// GA4 reserved: the class backing the screen.
  static const String screenClass = 'screen_class';

  /// GA4 reserved: the text a student searched for.
  static const String searchTerm = 'search_term';

  /// Subscription tier id, e.g. `veg-nonveg`.
  static const String messId = 'mess_id';

  /// Meal slot, e.g. `lunch`.
  static const String mealType = 'meal_type';

  /// Where a menu came from: `imported`, `network` or `cache`.
  static const String source = 'source';

  /// Days covered by an imported document.
  static const String dayCount = 'day_count';

  /// Tiers found in an imported document.
  static const String tierCount = 'tier_count';

  /// The `yyyy-MM` a document covers.
  static const String month = 'month';

  /// Why something failed, as a `FailureKind` name.
  static const String reason = 'reason';

  /// Number of matches a search produced.
  static const String resultCount = 'result_count';

  /// Serving state of a meal: `servingNow`, `upcoming` or `closed`.
  static const String mealStatus = 'meal_status';

  /// How far the chosen day is from today; negative for the past.
  static const String daysFromToday = 'days_from_today';

  /// Generic on/off flag.
  static const String enabled = 'enabled';

  /// Theme choice: `system`, `light` or `dark`.
  static const String themeMode = 'theme_mode';

  /// True when a meal window was reset rather than set.
  static const String isReset = 'is_reset';

  /// Which developer link was followed: `github`, `linkedin` or `email`.
  static const String link = 'link';
}

/// Screen names reported with [AnalyticsEvents.screenView].
class AnalyticsScreens {
  const AnalyticsScreens._();

  /// The hero "what's being served" screen.
  static const String home = 'home';

  /// The month browser.
  static const String week = 'week';

  /// Dish search.
  static const String search = 'search';

  /// Settings.
  static const String settings = 'settings';

  /// First-run tier picker.
  static const String onboarding = 'onboarding';
}
