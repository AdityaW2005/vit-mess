import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/analytics_events.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/result.dart';
import '../models/app_settings.dart';
import '../models/meal.dart';
import '../models/meal_item.dart';
import '../models/menu.dart';
import '../models/menu_day.dart';
import '../models/mess.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/menu_repository.dart';
import '../repositories/settings_repository.dart';
import 'base_view_model.dart';

/// One matching dish, with the context needed to say when it is served.
@immutable
class SearchHit {
  /// Creates a hit.
  const SearchHit({required this.day, required this.meal, required this.item});

  /// The day the dish appears on.
  final MenuDay day;

  /// The meal it appears in.
  final Meal meal;

  /// The matching dish.
  final MealItem item;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHit &&
          day == other.day &&
          meal == other.meal &&
          item == other.item);

  @override
  int get hashCode => Object.hash(day, meal, item);

  @override
  String toString() => 'SearchHit(${item.name} on ${day.dateKey})';
}

/// Hits for one date, which is how results are presented.
@immutable
class SearchDayGroup {
  /// Creates a group. [hits] is made immutable.
  SearchDayGroup({
    required this.day,
    required this.daysFromToday,
    required List<SearchHit> hits,
  }) : hits = List<SearchHit>.unmodifiable(hits);

  /// The date these hits fall on.
  final MenuDay day;

  /// Whole days from today: `0` is today, `1` tomorrow.
  final int daysFromToday;

  /// The matching dishes on that date. Immutable.
  final List<SearchHit> hits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchDayGroup &&
          day == other.day &&
          daysFromToday == other.daysFromToday &&
          listEquals(hits, other.hits));

  @override
  int get hashCode => Object.hash(day, daysFromToday, Object.hashAll(hits));

  @override
  String toString() => 'SearchDayGroup(${day.dateKey}, ${hits.length} hits)';
}

/// Drives full-month dish search.
///
/// Answers the question students actually have — "when is chicken biryani
/// next?" — so results run from today forwards and are grouped by date.
class SearchViewModel extends BaseViewModel {
  /// Creates the ViewModel over its repository interfaces.
  SearchViewModel({
    required MenuRepository menuRepository,
    required SettingsRepository settingsRepository,
    required AnalyticsRepository analyticsRepository,
  }) : _menuRepository = menuRepository,
       _settingsRepository = settingsRepository,
       _analytics = analyticsRepository,
       _settings = settingsRepository.current;

  /// How long typing settles before the month is searched.
  static const Duration debounce = Duration(milliseconds: 220);

  final MenuRepository _menuRepository;
  final SettingsRepository _settingsRepository;
  final AnalyticsRepository _analytics;

  Timer? _debounceTimer;
  StreamSubscription<AppSettings>? _settingsSubscription;
  StreamSubscription<MenuSnapshot>? _menuSubscription;

  AppSettings _settings;
  MenuSnapshot? _snapshot;
  Mess? _mess;
  String _query = '';
  List<SearchDayGroup> _groups = const <SearchDayGroup>[];
  bool _initialized = false;
  bool _isImporting = false;

  // ------------------------------------------------------------- getters

  /// The current query, as typed.
  String get query => _query;

  /// True when the student has typed something searchable.
  bool get hasQuery => _query.trim().isNotEmpty;

  /// Matching dishes, grouped by date, soonest first. Immutable.
  List<SearchDayGroup> get groups => _groups;

  /// Total number of matching dishes across every group.
  int get resultCount =>
      _groups.fold<int>(0, (sum, group) => sum + group.hits.length);

  /// True while the spreadsheet picker flow is running.
  bool get isImporting => _isImporting;

  /// True when a query returned nothing.
  bool get hasNoResults => hasQuery && _groups.isEmpty;

  // -------------------------------------------------------------- actions

  /// Loads the menu. Safe to call more than once.
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
        _mess = snapshot.menu.messByIdOrFirst(_settings.messId);
        setState(ViewState.ready);
      },
      onFailure: setFailure,
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
  void onShown() => unawaited(_analytics.logScreen(AnalyticsScreens.search));

  /// Records a new query and re-runs the search once typing settles.
  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    safeNotify();

    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      _groups = const <SearchDayGroup>[];
      safeNotify();
      return;
    }
    _debounceTimer = Timer(debounce, _runSearch);
  }

  /// Clears the query and any results.
  void clear() {
    _debounceTimer?.cancel();
    _query = '';
    _groups = const <SearchDayGroup>[];
    safeNotify();
  }

  // ------------------------------------------------------------ internals

  void _onMenuChanged(MenuSnapshot snapshot) {
    if (isDisposed) return;
    _snapshot = snapshot;
    _mess = snapshot.menu.messByIdOrFirst(_settings.messId);
    setState(ViewState.ready);
    clearError();
    if (hasQuery) _runSearch();
  }

  void _onSettingsChanged(AppSettings settings) {
    if (isDisposed) return;
    final messChanged = settings.messId != _settings.messId;
    _settings = settings;
    if (!messChanged) return;

    _mess = _snapshot?.menu.messByIdOrFirst(settings.messId);
    if (hasQuery) {
      _runSearch();
    } else {
      safeNotify();
    }
  }

  void _runSearch() {
    if (isDisposed) return;

    final needle = _query.trim().toLowerCase();
    final mess = _mess;
    if (needle.isEmpty || mess == null) {
      _groups = const <SearchDayGroup>[];
      safeNotify();
      return;
    }

    final now = DateTime.now();
    final today = startOfDay(now);
    final groups = <SearchDayGroup>[];

    for (final day in mess.days) {
      // Only today and later can answer "when is this next served".
      if (day.date.isBefore(today)) continue;

      final hits = <SearchHit>[];
      for (final meal in _settings.timings.applyToAll(day.meals)) {
        for (final item in meal.items) {
          if (item.name.toLowerCase().contains(needle)) {
            hits.add(SearchHit(day: day, meal: meal, item: item));
          }
        }
      }

      if (hits.isNotEmpty) {
        groups.add(
          SearchDayGroup(
            day: day,
            daysFromToday: daysBetween(now, day.date),
            hits: hits,
          ),
        );
      }
    }

    _groups = List<SearchDayGroup>.unmodifiable(groups);
    // Logged once typing has settled, so a single search is one event rather
    // than one per keystroke.
    unawaited(_analytics.logSearch(term: needle, resultCount: resultCount));
    safeNotify();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    unawaited(_settingsSubscription?.cancel());
    _settingsSubscription = null;
    unawaited(_menuSubscription?.cancel());
    _menuSubscription = null;
    super.dispose();
  }
}
