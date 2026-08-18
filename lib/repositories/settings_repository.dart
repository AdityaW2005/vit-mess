import '../core/utils/result.dart';
import '../models/app_settings.dart';

/// Owns the student's persisted choices.
///
/// Settings are read once at startup and then broadcast, so a tier change made
/// on the Settings screen reaches Home, Week and Search without any of them
/// knowing about each other.
abstract class SettingsRepository {
  /// The settings currently in effect. Always usable, even before [load].
  AppSettings get current;

  /// Emits whenever settings change. Broadcast; subscribe freely.
  Stream<AppSettings> get changes;

  /// Reads settings from disk into [current].
  Future<Result<AppSettings>> load();

  /// Persists [settings], updates [current], and notifies listeners.
  Future<Result<AppSettings>> save(AppSettings settings);

  /// Releases the broadcast stream.
  Future<void> dispose();
}
