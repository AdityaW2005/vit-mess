import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/constants/strings.dart';
import '../core/utils/result.dart';
import '../models/menu.dart';
import '../services/excel_menu_parser.dart';
import '../services/file_import_service.dart';
import '../services/local_storage_service.dart';
import '../services/menu_api_service.dart';
import 'analytics_repository.dart';
import 'menu_repository.dart';

/// Remote-first, cache-fallback implementation.
///
/// The ordering rule the whole app depends on: **never block the UI on the
/// network**. [getMenu] answers from disk so the first frame after a
/// successful load is always immediate, and [refreshMenu] runs afterwards to
/// replace it.
///
/// There is no bundled menu. Until a student either downloads or imports one,
/// [getMenu] fails with [FailureKind.empty] and the UI asks for a spreadsheet.
class MenuRepositoryImpl implements MenuRepository {
  /// Creates the repository over its services.
  MenuRepositoryImpl({
    required MenuApiService api,
    required LocalStorageService storage,
    required FileImportService files,
    required AnalyticsRepository analytics,
    ExcelMenuParser parser = const ExcelMenuParser(),
    String menuUrl = AppConfig.menuUrl,
  }) : _api = api,
       _storage = storage,
       _files = files,
       _analytics = analytics,
       _parser = parser,
       _menuUrl = menuUrl;

  final MenuApiService _api;
  final LocalStorageService _storage;
  final FileImportService _files;
  final AnalyticsRepository _analytics;
  final ExcelMenuParser _parser;

  /// Where the JSON document lives. Injected so tests can exercise the network
  /// path without depending on the shipped placeholder.
  final String _menuUrl;

  /// True once [_menuUrl] points at a real published document.
  bool get _hasRemote =>
      _menuUrl.trim().isNotEmpty && _menuUrl != AppConfig.placeholderMenuUrl;

  final StreamController<MenuSnapshot> _changes =
      StreamController<MenuSnapshot>.broadcast();

  @override
  Stream<MenuSnapshot> get changes => _changes.stream;

  @override
  Future<Result<MenuSnapshot>> getMenu() async {
    final cached = _readCachedSnapshot();
    if (cached != null) return Result<MenuSnapshot>.success(cached);

    // Nothing on disk: the network is the only thing that can save the first
    // launch. If it cannot, the UI asks the student to import a workbook.
    final fetched = await refreshMenu();
    if (fetched.isSuccess) return fetched;

    unawaited(_analytics.logEmptyPromptShown());
    return const Result<MenuSnapshot>.failure(
      Strings.failureEmpty,
      kind: FailureKind.empty,
    );
  }

  @override
  Future<Result<MenuSnapshot>> refreshMenu() async {
    // Without a published menu URL there is nothing to fetch. Saying so beats
    // a timeout followed by a misleading "you are offline".
    if (!_hasRemote) {
      return const Result<MenuSnapshot>.failure(
        Strings.failureNoRemote,
        kind: FailureKind.unsupported,
      );
    }

    String document;
    try {
      document = await _api.fetchMenuDocument(url: _menuUrl);
    } on MenuApiException catch (error) {
      debugPrint('Menu refresh failed: $error');
      unawaited(_analytics.logMenuRefreshFailed(FailureKind.network));
      return Result<MenuSnapshot>.failure(
        Strings.failureNetwork,
        kind: FailureKind.network,
        cause: error,
      );
    }

    final menu = Menu.decode(document);
    if (menu == null) {
      return const Result<MenuSnapshot>.failure(
        Strings.failureParse,
        kind: FailureKind.parse,
      );
    }

    unawaited(_analytics.logMenuRefreshed(menu));
    return _adopt(menu, document, MenuSource.network);
  }

  @override
  Future<Result<MenuSnapshot>> importMenu() async {
    PickedWorkbook? workbook;
    try {
      workbook = await _files.pickMenuWorkbook();
    } on FileImportException catch (error) {
      debugPrint('Workbook selection failed: $error');
      unawaited(_analytics.logMenuImportFailed(FailureKind.parse));
      return Result<MenuSnapshot>.failure(
        Strings.failureNotSpreadsheet,
        kind: FailureKind.parse,
        cause: error,
      );
    }

    if (workbook == null) {
      return const Result<MenuSnapshot>.failure(
        Strings.failureCancelled,
        kind: FailureKind.cancelled,
      );
    }

    Menu menu;
    try {
      menu = _parser.parse(workbook.bytes);
    } on ExcelParseException catch (error) {
      debugPrint('Workbook parse failed: $error');
      unawaited(_analytics.logMenuImportFailed(FailureKind.parse));
      return Result<MenuSnapshot>.failure(
        Strings.failureSpreadsheetShape,
        kind: FailureKind.parse,
        cause: error,
      );
    } on Object catch (error) {
      debugPrint('Unexpected workbook failure: $error');
      return Result<MenuSnapshot>.failure(
        Strings.failureSpreadsheetShape,
        kind: FailureKind.parse,
        cause: error,
      );
    }

    // The workbook is normalised to the JSON contract before caching, so the
    // cache format never depends on where a menu came from.
    unawaited(_analytics.logMenuImported(menu));
    return _adopt(menu, menu.encode(), MenuSource.imported);
  }

  @override
  Future<DateTime?> lastUpdated() async {
    try {
      return _storage.readLastUpdated();
    } on Object catch (error) {
      debugPrint('Reading last-updated stamp failed: $error');
      return null;
    }
  }

  @override
  Future<Result<void>> clearCache() async {
    try {
      await _storage.clearMenuDocument();
      return const Result<void>.success(null);
    } on Object catch (error) {
      return Result<void>.failure(
        Strings.failureStorage,
        kind: FailureKind.storage,
        cause: error,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (!_changes.isClosed) await _changes.close();
  }

  // ------------------------------------------------------------- internals

  /// Caches [document], announces the new [menu], and returns it.
  ///
  /// A failed cache write is logged but not fatal: the student still gets the
  /// menu for this session.
  Future<Result<MenuSnapshot>> _adopt(
    Menu menu,
    String document,
    MenuSource source,
  ) async {
    final now = DateTime.now();
    try {
      final wrote = await _storage.writeMenuDocument(
        document,
        source: source,
        updatedAt: now,
      );
      if (!wrote) debugPrint('Menu cache write reported failure.');
    } on Object catch (error) {
      debugPrint('Menu cache write failed: $error');
    }

    final snapshot = MenuSnapshot(
      menu: menu,
      source: source,
      lastUpdated: now,
    );
    if (!_changes.isClosed) _changes.add(snapshot);
    return Result<MenuSnapshot>.success(snapshot);
  }

  /// The cached document, or `null` when absent or unparseable.
  ///
  /// A cache that no longer parses is treated as absent rather than as an
  /// error, so a bad write can never brick the app.
  MenuSnapshot? _readCachedSnapshot() {
    String? document;
    try {
      document = _storage.readMenuDocument();
    } on Object catch (error) {
      debugPrint('Reading menu cache failed: $error');
      return null;
    }
    if (document == null || document.trim().isEmpty) return null;

    final menu = Menu.decode(document);
    if (menu == null) {
      debugPrint('Cached menu could not be parsed; ignoring it.');
      return null;
    }

    return MenuSnapshot(
      menu: menu,
      source: _storage.readMenuSource(),
      lastUpdated: _storage.readLastUpdated(),
    );
  }
}
