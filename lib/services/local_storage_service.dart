import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../models/menu.dart';

/// Typed wrapper around `SharedPreferences`.
///
/// The menu document is cached as its raw JSON string: parsing is the
/// repository's job, so a schema change never strands unreadable objects on
/// disk.
class LocalStorageService {
  /// Creates the service around an open preferences instance.
  LocalStorageService(this._prefs);

  /// Opens preferences and returns a ready service.
  static Future<LocalStorageService> create() async =>
      LocalStorageService(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  // ----------------------------------------------------------- menu cache

  /// The cached menu document, or `null` when nothing has been stored.
  String? readMenuDocument() => _prefs.getString(AppConfig.keyMenuDocument);

  /// When the cached document was fetched or imported.
  DateTime? readLastUpdated() {
    final millis = _prefs.getInt(AppConfig.keyMenuLastUpdated);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Where the cached document came from.
  MenuSource readMenuSource() =>
      MenuSource.fromStorage(_prefs.getString(AppConfig.keyMenuSource));

  /// Caches [document] together with its provenance.
  ///
  /// Returns `false` if the write failed, so the repository can decide whether
  /// that is worth surfacing.
  Future<bool> writeMenuDocument(
    String document, {
    required MenuSource source,
    required DateTime updatedAt,
  }) async {
    final wroteDocument = await _prefs.setString(
      AppConfig.keyMenuDocument,
      document,
    );
    final wroteSource = await _prefs.setString(
      AppConfig.keyMenuSource,
      source.storageValue,
    );
    final wroteStamp = await _prefs.setInt(
      AppConfig.keyMenuLastUpdated,
      updatedAt.millisecondsSinceEpoch,
    );
    return wroteDocument && wroteSource && wroteStamp;
  }

  /// Drops the cached document and its metadata.
  Future<void> clearMenuDocument() async {
    await _prefs.remove(AppConfig.keyMenuDocument);
    await _prefs.remove(AppConfig.keyMenuSource);
    await _prefs.remove(AppConfig.keyMenuLastUpdated);
  }

  // -------------------------------------------------------------- settings

  /// The stored settings blob, or `null` on a fresh install.
  String? readSettings() => _prefs.getString(AppConfig.keySettings);

  /// Persists the settings blob.
  Future<bool> writeSettings(String settings) =>
      _prefs.setString(AppConfig.keySettings, settings);
}
