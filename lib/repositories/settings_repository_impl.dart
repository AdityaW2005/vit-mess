import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/constants/strings.dart';
import '../core/utils/result.dart';
import '../models/app_settings.dart';
import '../services/local_storage_service.dart';
import 'settings_repository.dart';

/// Preferences-backed settings store.
class SettingsRepositoryImpl implements SettingsRepository {
  /// Creates the repository over local storage.
  SettingsRepositoryImpl({required LocalStorageService storage})
    : _storage = storage;

  final LocalStorageService _storage;
  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  AppSettings _current = AppSettings.initial();

  @override
  AppSettings get current => _current;

  @override
  Stream<AppSettings> get changes => _controller.stream;

  @override
  Future<Result<AppSettings>> load() async {
    try {
      final raw = _storage.readSettings();
      if (raw != null && raw.trim().isNotEmpty) {
        _current = AppSettings.fromJson(jsonDecode(raw));
      }
      return Result<AppSettings>.success(_current);
    } on FormatException catch (error) {
      // Corrupt settings are not worth an error screen: fall back to defaults
      // and let the student re-choose.
      debugPrint('Stored settings were unreadable; using defaults: $error');
      _current = AppSettings.initial();
      return Result<AppSettings>.success(_current);
    } on Object catch (error) {
      debugPrint('Loading settings failed: $error');
      return Result<AppSettings>.failure(
        Strings.failureStorage,
        kind: FailureKind.storage,
        cause: error,
      );
    }
  }

  @override
  Future<Result<AppSettings>> save(AppSettings settings) async {
    // Update in-memory state first so the UI stays responsive even if the
    // write is slow or fails.
    _current = settings;
    if (!_controller.isClosed) _controller.add(settings);

    try {
      final wrote = await _storage.writeSettings(jsonEncode(settings.toJson()));
      if (!wrote) {
        return Result<AppSettings>.failure(
          Strings.failureStorage,
          kind: FailureKind.storage,
        );
      }
      return Result<AppSettings>.success(settings);
    } on Object catch (error) {
      debugPrint('Saving settings failed: $error');
      return Result<AppSettings>.failure(
        Strings.failureStorage,
        kind: FailureKind.storage,
        cause: error,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}
