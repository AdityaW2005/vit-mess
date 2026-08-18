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
import '../repositories/reminder_repository.dart';
import '../repositories/settings_repository.dart';
import 'base_view_model.dart';
import 'meal_presentation.dart';

/// Drives the hero screen: what is being served, and how long is left.
///
/// Owns the one-second ticker that the countdown reads from. The ticker is
/// cancelled in [dispose].
class HomeViewModel extends BaseViewModel {
  /// Creates the ViewModel over its repository interfaces.
  HomeViewModel({
    required MenuRepository menuRepository,
    required SettingsRepository settingsRepository,
    required ReminderRepository reminderRepository,
    required AnalyticsRepository analyticsRepository,
  }) : _menuRepository = menuRepository,
       _settingsRepository = settingsRepository,
       _reminderRepository = reminderRepository,
       _analytics = analyticsRepository,
       _settings = settingsRepository.current;

  final MenuRepository _menuRepository;
  final SettingsRepository _settingsRepository;
  final ReminderRepository _reminderRepository;
  final AnalyticsRepository _analytics;

  Timer? _ticker;
  StreamSubscription<AppSettings>? _settingsSubscription;
  StreamSubscription<MenuSnapshot>? _menuSubscription;

  AppSettings _settings;
  MenuSnapshot? _snapshot;
  Mess? _mess;
  MenuDay? _today;
  MealFocus? _focus;
  List<MealPresentation> _otherMeals = const <MealPresentation>[];
  Duration _countdown = Duration.zero;
  String _countdownLabel = '';
  DateTime _now = DateTime.now();

  bool _initialized = false;
  bool _isRefreshing = false;
  bool _isImporting = false;
  bool _refreshFailedQuietly = false;

  // ------------------------------------------------------------- getters

  /// The menu in hand, with its provenance.
  MenuSnapshot? get snapshot => _snapshot;

  /// The tier the student is subscribed to.
  Mess? get mess => _mess;

  /// Today's entry in the document, or `null` when the month does not cover
  /// today.
  MenuDay? get today => _today;

  /// The meal the hero card is showing: serving now, or the next to open.
  MealFocus? get focus => _focus;

  /// The other meals on the focused day, in serving order. Immutable.
  List<MealPresentation> get otherMeals => _otherMeals;

  /// Time remaining until the focused meal closes (or opens).
  Duration get countdown => _countdown;

  /// The instant the ticker last observed. Views should read time from here
  /// rather than calling `DateTime.now()` during a build.
  DateTime get now => _now;

  /// True while a refresh is in flight.
  bool get isRefreshing => _isRefreshing;

  /// True while the spreadsheet picker flow is running.
  bool get isImporting => _isImporting;

  /// True when a background refresh failed but a cached menu is still shown.
  ///
  /// The UI marks this with a quiet "last updated" line, never an error
  /// banner.
  bool get isShowingStaleData => _refreshFailedQuietly;

  /// When the menu in hand was fetched or imported.
  DateTime? get lastUpdated => _snapshot?.lastUpdated;

  /// Where the menu in hand came from.
  MenuSource? get source => _snapshot?.source;

  /// True when the document does not cover the current month.
  bool get isMonthStale => _snapshot?.isStaleFor(_now) ?? false;

  /// True when there is nothing left to show for this month — either the
  /// document is for another month, or it is after the last meal of the last
  /// day it covers.
  bool get showMonthUnavailable =>
      _snapshot != null && !_isRefreshing && (_focus == null || isMonthStale);

  /// Whether veg/non-veg alternatives read as one either/or choice.
  ///
  /// The Veg & Non-Veg plan serves one of the pair; the Special plan serves
  /// both, so there they are listed as separate dishes.
  bool get pairsAlternatives => _mess?.id != AppConfig.messIdSpecial;

  /// True when the day exists but carries no meals at all.
  bool get hasEmptyDay =>
      _snapshot != null && _today != null && _today!.meals.isEmpty;

  // -------------------------------------------------------------- actions

  /// Loads the menu and starts the ticker. Safe to call more than once.
  ///
  /// Returns as soon as the cached menu is on screen; the network refresh
  /// continues in the background.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _settings = _settingsRepository.current;
    _settingsSubscription = _settingsRepository.changes.listen(
      _onSettingsChanged,
    );
    // An import performed on Settings must land here too.
    _menuSubscription = _menuRepository.changes.listen(_onMenuChanged);

    setState(ViewState.busy);

    final result = await _menuRepository.getMenu();
    if (isDisposed) return;

    result.fold(
      onSuccess: (snapshot) {
        _snapshot = snapshot;
        _recompute();
        setState(ViewState.ready);
      },
      onFailure: setFailure,
    );

    _startTicker();

    // Refresh in the background: the screen is already usable.
    unawaited(refresh());
  }

/// Called when this tab comes to the front.
  ///
  /// Tabs live in an `IndexedStack`, so they are built once and never pushed
  /// as routes — the navigator observer cannot see them and the screen has to
  /// report itself.
  void onShown() => unawaited(_analytics.logScreen(AnalyticsScreens.home));

  /// Records that a meal card was opened.
  void logMealExpanded(MealPresentation presentation) => unawaited(
    _analytics.logMealExpanded(
      type: presentation.meal.type,
      status: presentation.status,
    ),
  );

  /// Fetches the latest document.
  ///
  /// A failure is swallowed when a menu is already on screen — an offline
  /// student should see their cached menu, not a banner. The full error state
  /// appears only when there is genuinely nothing to show.
  Future<void> refresh({bool userInitiated = false}) async {
    if (userInitiated) unawaited(_analytics.logPullToRefresh());
    if (_isRefreshing) return;
    _isRefreshing = true;
    safeNotify();

    final result = await _menuRepository.refreshMenu();

    if (isDisposed) return;
    _isRefreshing = false;

    result.fold(
      onSuccess: (snapshot) {
        _adoptSnapshot(snapshot);
        unawaited(_rescheduleReminders());
      },
      onFailure: (failure) {
        if (_snapshot != null) {
          // A cached menu is already on screen: keep it. Only a genuine
          // network failure is worth the quiet "last updated" marker — a build
          // with no menu server simply has nothing to download.
          _refreshFailedQuietly = failure.kind == FailureKind.network;
          safeNotify();
        } else if (failure.kind == FailureKind.network ||
            failure.kind == FailureKind.unsupported) {
          // Nothing on the device at all. The useful screen is the import
          // prompt, not an offline notice — the remote document is optional,
          // and the prompt still offers downloading as its secondary action.
          setFailure(_emptyFailure);
        } else {
          setFailure(failure);
        }
      },
    );
  }

  /// Imports a menu spreadsheet chosen by the student.
  ///
  /// This is the primary way a menu arrives while the remote document is not
  /// reachable, so it is offered directly from the empty state.
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
      onSuccess: (snapshot) {
        _adoptSnapshot(snapshot);
        unawaited(_rescheduleReminders());
      },
      onFailure: (failure) {
        // Cancelling leaves whatever is on screen alone. A genuinely bad
        // workbook replaces the empty state with an explanation, but never
        // discards a menu that is already loaded.
        if (_snapshot == null && failure.kind != FailureKind.cancelled) {
          setFailure(failure);
        } else {
          safeNotify();
        }
      },
    );
    return result;
  }

  // ------------------------------------------------------------ internals

  /// The "no menu yet" state, which the UI renders as the import prompt.
  static const Failure<MenuSnapshot> _emptyFailure = Failure<MenuSnapshot>(
    Strings.failureEmpty,
    kind: FailureKind.empty,
  );

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Advances `now` and rebuilds derived state.
  ///
  /// Listeners are notified only when something visible actually changed,
  /// which keeps the tree from rebuilding 60 times a minute for nothing.
  void _tick() {
    if (isDisposed) return;
    _now = DateTime.now();

    final previousFocus = _focus;
    final previousLabel = _countdownLabel;
    final previousUnavailable = showMonthUnavailable;

    _recompute();

    if (_focus != previousFocus ||
        _countdownLabel != previousLabel ||
        showMonthUnavailable != previousUnavailable) {
      safeNotify();
    }
  }

  /// Adopts a newly loaded menu and clears any error state.
  void _adoptSnapshot(MenuSnapshot snapshot) {
    _snapshot = snapshot;
    _refreshFailedQuietly = false;
    _recompute();
    setState(ViewState.ready);
    clearError();
  }

  void _onMenuChanged(MenuSnapshot snapshot) {
    if (isDisposed) return;
    _adoptSnapshot(snapshot);
  }

  void _onSettingsChanged(AppSettings settings) {
    if (isDisposed) return;
    final messChanged = settings.messId != _settings.messId;
    final timingsChanged = settings.timings != _settings.timings;
    _settings = settings;

    if (messChanged || timingsChanged) {
      _recompute();
      safeNotify();
    }
  }

  /// Recomputes every derived value from `_snapshot`, `_settings` and `_now`.
  void _recompute() {
    final snapshot = _snapshot;
    if (snapshot == null) {
      _mess = null;
      _today = null;
      _focus = null;
      _otherMeals = const <MealPresentation>[];
      _countdown = Duration.zero;
      _countdownLabel = '';
      return;
    }

    final mess = snapshot.menu.messByIdOrFirst(_settings.messId);
    _mess = mess;
    if (mess == null) {
      _today = null;
      _focus = null;
      _otherMeals = const <MealPresentation>[];
      _countdown = Duration.zero;
      _countdownLabel = '';
      return;
    }

    _today = mess.dayFor(_now);
    _focus = resolveFocus(mess, _now, _settings.timings);

    // The secondary cards belong to whichever day the hero is showing, so
    // after dinner they roll over to tomorrow alongside it.
    final day = _focus?.day ?? _today;
    if (day == null) {
      _otherMeals = const <MealPresentation>[];
    } else {
      final focusedType = _focus?.meal.type;
      final meals = _settings.timings.applyToAll(day.meals);
      _otherMeals = List<MealPresentation>.unmodifiable(
        meals
            .where((meal) => meal.type != focusedType)
            .map(
              (meal) => MealPresentation(
                meal: meal,
                day: day,
                status: resolveStatusOnDay(meal, day.date, _now),
              ),
            )
            .toList(growable: false),
      );
    }

    _countdown = _focus?.remaining(_now) ?? Duration.zero;
    _countdownLabel = Strings.formatCountdown(_countdown);
  }

  Future<void> _rescheduleReminders() async {
    final snapshot = _snapshot;
    if (snapshot == null || !_settings.remindersEnabled) return;
    await _reminderRepository.reschedule(
      menu: snapshot.menu,
      settings: _settings,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(_settingsSubscription?.cancel());
    _settingsSubscription = null;
    unawaited(_menuSubscription?.cancel());
    _menuSubscription = null;
    super.dispose();
  }
}
