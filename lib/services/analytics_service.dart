import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show NavigatorObserver;

/// Sends events to Google Analytics (Firebase).
///
/// This is the only place in the app that touches the Firebase SDK.
///
/// **It is safe to run unconfigured.** Firebase needs a per-project
/// `google-services.json` / `GoogleService-Info.plist`; until those are in the
/// build, [initialize] reports failure and every log call becomes a no-op
/// instead of throwing. Analytics is never allowed to break the app it is
/// measuring.
///
/// In debug builds every event is also echoed to the console, so the wiring
/// can be verified before a Firebase project exists.
class AnalyticsService {
  /// Creates the service. Pass [analytics] in tests.
  AnalyticsService({FirebaseAnalytics? analytics}) : _injected = analytics;

  final FirebaseAnalytics? _injected;

  FirebaseAnalytics? _analytics;
  bool _initialized = false;
  bool _available = false;

  /// True once Firebase is up and events can actually leave the device.
  bool get isAvailable => _available;

  /// Starts Firebase and resolves the analytics handle.
  ///
  /// Returns `false` when no Firebase configuration is bundled, which is the
  /// expected state until `google-services.json` is added. Safe to call more
  /// than once.
  Future<bool> initialize() async {
    if (_initialized) return _available;
    _initialized = true;

    if (_injected != null) {
      _analytics = _injected;
      _available = true;
      return true;
    }

    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      _available = true;
    } on Object catch (error) {
      // No google-services.json in the build, or the platform refused to
      // start Firebase. Either way the app carries on without analytics.
      debugPrint(
        'Analytics disabled — Firebase is not configured for this build '
        '($error). See README "Analytics".',
      );
      _available = false;
    }
    return _available;
  }

  /// Turns collection on or off at the SDK level.
  ///
  /// Called whenever the student changes their choice, so an opt-out stops
  /// data leaving the device rather than merely being ignored here.
  Future<void> setCollectionEnabled(bool enabled) async {
    if (!_available) return;
    try {
      await _analytics!.setAnalyticsCollectionEnabled(enabled);
    } on Object catch (error) {
      debugPrint('Analytics setCollectionEnabled failed: $error');
    }
  }

  /// Records a custom event.
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    _echo(name, parameters);
    if (!_available) return;
    try {
      await _analytics!.logEvent(name: name, parameters: parameters);
    } on Object catch (error) {
      debugPrint('Analytics logEvent($name) failed: $error');
    }
  }

  /// Records a screen view.
  Future<void> logScreenView(String screenName) async {
    _echo('screen_view', <String, Object>{'screen_name': screenName});
    if (!_available) return;
    try {
      await _analytics!.logScreenView(screenName: screenName);
    } on Object catch (error) {
      debugPrint('Analytics logScreenView($screenName) failed: $error');
    }
  }

  /// Sets a user property, used for slow-moving traits such as the tier.
  Future<void> setUserProperty(String name, String? value) async {
    if (!_available) return;
    try {
      await _analytics!.setUserProperty(name: name, value: value);
    } on Object catch (error) {
      debugPrint('Analytics setUserProperty($name) failed: $error');
    }
  }

  /// A navigator observer that reports pushed routes automatically.
  ///
  /// Returns `null` when Firebase is unavailable, so `MaterialApp` simply gets
  /// no observer rather than a broken one.
  NavigatorObserver? get navigatorObserver {
    final analytics = _analytics;
    if (!_available || analytics == null) return null;
    return FirebaseAnalyticsObserver(analytics: analytics);
  }

  void _echo(String name, Map<String, Object>? parameters) {
    if (!kDebugMode) return;
    final suffix = (parameters == null || parameters.isEmpty)
        ? ''
        : ' ${parameters.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
    debugPrint('[analytics] $name$suffix');
  }
}
