import 'dart:async';

import '../core/config/app_config.dart';
import '../core/constants/analytics_events.dart';
import '../core/constants/strings.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/result.dart';
import '../models/app_settings.dart';
import '../models/menu.dart';
import '../models/menu_day.dart';
import '../models/mess.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/menu_repository.dart';
import '../repositories/settings_repository.dart';
import 'base_view_model.dart';
import 'meal_presentation.dart';

/// Drives the month browser: a day strip plus the selected day's four meals.
class WeekViewModel extends BaseViewModel {
  /// Creates the ViewModel over its repository interfaces.
  WeekViewModel({
    required MenuRepository menuRepository,
    required SettingsRepository settingsRepository,
    required AnalyticsRepository analyticsRepository,
  }) : _menuRepository = menuRepository,
       _settingsRepository = settingsRepository,
       _analytics = analyticsRepository,
       _settings = settingsRepository.current;

  final MenuRepository _menuRepository;
  final SettingsRepository _settingsRepository;
  final AnalyticsRepository _analytics;

  StreamSubscription<AppSettings>? _settingsSubscription;
  StreamSubscription<MenuSnapshot>? _menuSubscription;

  AppSettings _settings;
  MenuSnapshot? _snapshot;
  Mess? _mess;
  List<MenuDay> _days = const <MenuDay>[];
  List<MealPresentation> _selectedMeals = const <MealPresentation>[];
  int _selectedIndex = 0;
  bool _initialized = false;
  bool _isImporting = false;
  DateTime _now = DateTime.now();

  // ------------------------------------------------------------- getters

  /// Every day the document covers, ascending. Immutable.
  List<MenuDay> get days => _days;

  /// Index of the selected day within [days].
  int get selectedIndex => _selectedIndex;

  /// The selected day, or `null` when the document is empty.
  MenuDay? get selectedDay =>
      (_selectedIndex >= 0 && _selectedIndex < _days.length)
      ? _days[_selectedIndex]
      : null;

  /// The selected day's meals, with status resolved. Immutable.
  List<MealPresentation> get selectedMeals => _selectedMeals;

  /// The meals for the day at [index], with status resolved.
  ///
  /// `PageView` builds the pages either side of the current one, so every
  /// index has to be answerable — not just the selected one, or a swipe would
  /// reveal a blank page before the selection catches up.
  List<MealPresentation> mealsForIndex(int index) {
    if (index < 0 || index >= _days.length) {
      return const <MealPresentation>[];
    }
    if (index == _selectedIndex) return _selectedMeals;
    return _presentationsFor(_days[index]);
  }

  /// Index of today within [days], or `-1` when the month does not cover it.
  int get todayIndex {
    for (var i = 0; i < _days.length; i++) {
      if (isSameDay(_days[i].date, _now)) return i;
    }
    return -1;
  }

  /// The tier the student is subscribed to.
  Mess? get mess => _mess;

  /// The instant the last recompute used.
  DateTime get now => _now;

  /// True while the spreadsheet picker flow is running.
  bool get isImporting => _isImporting;

  /// Whether veg/non-veg alternatives read as one either/or choice.
  ///
  /// The Veg & Non-Veg plan serves one of the pair; the Special plan serves
  /// both, so there they are listed as separate dishes.
  bool get pairsAlternatives => _mess?.id != AppConfig.messIdSpecial;

  /// True when the document covers no days at all.
  bool get isEmpty => _days.isEmpty;

  // -------------------------------------------------------------- actions

  /// Loads the menu and pre-selects today. Safe to call more than once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _settings = _settingsRepository.current;
    _settingsSubscription = _settingsRepository.changes.listen(
      _onSettingsChanged,
    );
    // A menu imported on any screen lands here too.
    _menuSubscription = _menuRepository.changes.listen(_onMenuChanged);

    setState(ViewState.busy);

    final result = await _menuRepository.getMenu();
    if (isDisposed) return;

    result.fold(
      onSuccess: (snapshot) {
        _snapshot = snapshot;
        _rebuild(preserveSelection: false);
        setState(ViewState.ready);
      },
      onFailure: setFailure,
    );
  }

  /// Re-reads the menu, keeping the current selection where possible.
  Future<void> refresh() async {
    final result = await _menuRepository.refreshMenu();
    if (isDisposed) return;

    result.fold(
      onSuccess: (snapshot) {
        _snapshot = snapshot;
        _rebuild(preserveSelection: true);
        setState(ViewState.ready);
      },
      onFailure: (failure) {
        // With a month already on screen there is nothing to do. With nothing
        // on the device, the import prompt is more useful than an offline
        // notice.
        if (_snapshot != null) return;
        final isDownloadProblem =
            failure.kind == FailureKind.network ||
            failure.kind == FailureKind.unsupported;
        setFailure(
          isDownloadProblem
              ? const Failure<MenuSnapshot>(
                  Strings.failureEmpty,
                  kind: FailureKind.empty,
                )
              : failure,
        );
      },
    );
  }

  /// Imports a menu spreadsheet chosen by the student.
  ///
  /// Success arrives through the repository's change stream, which every
  /// screen listens to, so there is nothing to adopt here.
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
      onSuccess: (_) {},
      onFailure: (failure) {
        if (_snapshot == null && failure.kind != FailureKind.cancelled) {
          setFailure(failure);
        } else {
          safeNotify();
        }
      },
    );
    return result;
  }

/// Called when this tab comes to the front.
  ///
  /// Tabs live in an `IndexedStack`, so they are built once and never pushed
  /// as routes — the navigator observer cannot see them and the screen has to
  /// report itself.
  void onShown() => unawaited(_analytics.logScreen(AnalyticsScreens.week));

  /// Records that a meal card was opened.
  void logMealExpanded(MealPresentation presentation) => unawaited(
    _analytics.logMealExpanded(
      type: presentation.meal.type,
      status: presentation.status,
    ),
  );

  /// Selects the day at [index]. Out-of-range values are ignored.
  void selectDay(int index) {
    if (index < 0 || index >= _days.length || index == _selectedIndex) return;
    _selectedIndex = index;
    _recomputeSelectedMeals();
    unawaited(_analytics.logDaySelected(daysBetween(_now, _days[index].date)));
    safeNotify();
  }

  /// Jumps back to today when the month covers it.
  void selectToday() {
    final index = todayIndex;
    if (index >= 0) selectDay(index);
  }

  // ------------------------------------------------------------ internals

  void _onMenuChanged(MenuSnapshot snapshot) {
    if (isDisposed) return;
    _snapshot = snapshot;
    _rebuild(preserveSelection: false);
    setState(ViewState.ready);
    clearError();
    safeNotify();
  }

  void _onSettingsChanged(AppSettings settings) {
    if (isDisposed) return;
    final relevant =
        settings.messId != _settings.messId ||
        settings.timings != _settings.timings;
    _settings = settings;
    if (!relevant) return;

    _rebuild(preserveSelection: true);
    safeNotify();
  }

  void _rebuild({required bool preserveSelection}) {
    _now = DateTime.now();

    final snapshot = _snapshot;
    final mess = snapshot?.menu.messByIdOrFirst(_settings.messId);
    _mess = mess;
    _days = mess?.days ?? const <MenuDay>[];

    if (_days.isEmpty) {
      _selectedIndex = 0;
      _selectedMeals = const <MealPresentation>[];
      return;
    }

    if (!preserveSelection || _selectedIndex >= _days.length) {
      // Today is the anchor; fall back to the first day of the month when the
      // document does not reach today.
      final index = todayIndex;
      _selectedIndex = index >= 0 ? index : 0;
    }

    _recomputeSelectedMeals();
  }

  void _recomputeSelectedMeals() {
    final day = selectedDay;
    _selectedMeals = day == null
        ? const <MealPresentation>[]
        : _presentationsFor(day);
  }

  /// Resolves every meal on [day] against the current time and overrides.
  List<MealPresentation> _presentationsFor(MenuDay day) =>
      List<MealPresentation>.unmodifiable(
        _settings.timings
            .applyToAll(day.meals)
            .map(
              (meal) => MealPresentation(
                meal: meal,
                day: day,
                status: resolveStatusOnDay(meal, day.date, _now),
              ),
            )
            .toList(growable: false),
      );

  @override
  void dispose() {
    unawaited(_settingsSubscription?.cancel());
    _settingsSubscription = null;
    unawaited(_menuSubscription?.cancel());
    _menuSubscription = null;
    super.dispose();
  }
}
