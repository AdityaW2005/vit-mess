import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/core/config/app_config.dart';
import 'package:vit_mess/core/utils/result.dart';
import 'package:vit_mess/models/menu.dart';
import 'package:vit_mess/repositories/analytics_repository_impl.dart';
import 'package:vit_mess/repositories/menu_repository_impl.dart';
import 'package:vit_mess/services/analytics_service.dart';
import 'package:vit_mess/services/file_import_service.dart';
import 'package:vit_mess/services/local_storage_service.dart';
import 'package:vit_mess/services/menu_api_service.dart';

import 'excel_helpers.dart';

/// Builds a minimal but valid JSON document for [month].
String documentFor(String month, {String dish = 'Idly'}) =>
    '''
{
  "schemaVersion": 1,
  "month": "$month",
  "campus": "VIT-AP",
  "messes": [
    {
      "id": "veg-nonveg",
      "name": "Veg & Non-Veg",
      "days": [
        {
          "date": "$month-17",
          "weekday": "Mon",
          "meals": [
            {
              "type": "breakfast",
              "startTime": "07:15",
              "endTime": "09:00",
              "items": [{ "name": "$dish", "variant": null }]
            }
          ]
        }
      ]
    }
  ]
}
''';

/// An API that either returns a canned body or fails like a dead network.
class FakeMenuApiService implements MenuApiService {
  FakeMenuApiService({this.body, this.failure});

  String? body;
  MenuApiException? failure;
  int fetchCount = 0;

  @override
  Future<String> fetchMenuDocument({String url = ''}) async {
    fetchCount++;
    final error = failure;
    if (error != null) throw error;
    return body!;
  }

  @override
  void dispose() {}
}

/// An in-memory stand-in for shared preferences.
class FakeLocalStorageService implements LocalStorageService {
  String? document;
  MenuSource source = MenuSource.cache;
  DateTime? updatedAt;
  String? settings;
  bool writeSucceeds = true;
  int writeCount = 0;

  @override
  String? readMenuDocument() => document;

  @override
  DateTime? readLastUpdated() => updatedAt;

  @override
  MenuSource readMenuSource() => source;

  @override
  Future<bool> writeMenuDocument(
    String document, {
    required MenuSource source,
    required DateTime updatedAt,
  }) async {
    writeCount++;
    if (!writeSucceeds) return false;
    this.document = document;
    this.source = source;
    this.updatedAt = updatedAt;
    return true;
  }

  @override
  Future<void> clearMenuDocument() async {
    document = null;
    updatedAt = null;
  }

  @override
  String? readSettings() => settings;

  @override
  Future<bool> writeSettings(String settings) async {
    this.settings = settings;
    return true;
  }
}

/// A picker with a controllable result.
class FakeFileImportService implements FileImportService {
  FakeFileImportService({this.picked, this.failure});

  PickedWorkbook? picked;
  FileImportException? failure;

  @override
  Future<PickedWorkbook?> pickMenuWorkbook() async {
    final error = failure;
    if (error != null) throw error;
    return picked;
  }
}

/// Analytics that goes nowhere: the repository under test must work whether
/// or not Firebase is configured.
class SilentAnalyticsService implements AnalyticsService {
  @override
  bool get isAvailable => false;

  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {}

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}

  @override
  Null get navigatorObserver => null;
}

void main() {
  late FakeMenuApiService api;
  late FakeLocalStorageService storage;
  late FakeFileImportService files;

  /// A repository wired to a published menu URL, so the network path runs.
  AnalyticsRepositoryImpl silentAnalytics() =>
      AnalyticsRepositoryImpl(analytics: SilentAnalyticsService());

  MenuRepositoryImpl buildRepository() => MenuRepositoryImpl(
    api: api,
    storage: storage,
    files: files,
    analytics: silentAnalytics(),
    menuUrl: 'https://menus.example.test/menu.json',
  );

  /// A repository in the shipped configuration, where no menu server exists.
  MenuRepositoryImpl buildRepositoryWithoutRemote() => MenuRepositoryImpl(
    api: api,
    storage: storage,
    files: files,
    analytics: silentAnalytics(),
  );

  PickedWorkbook workbook() => PickedWorkbook(
    name: 'menu.xlsx',
    bytes: buildWorkbook(<String, List<List<String>>>{
      'Veg & Non-Veg': gridSheet(),
    }),
  );

  setUp(() {
    api = FakeMenuApiService(body: documentFor('2026-08'));
    storage = FakeLocalStorageService();
    files = FakeFileImportService();
  });

  group('getMenu — cache-first ordering', () {
    test('returns the cache without touching the network', () async {
      storage
        ..document = documentFor('2026-08', dish: 'Cached')
        ..source = MenuSource.imported
        ..updatedAt = DateTime(2026, 8, 17, 9);

      final result = await buildRepository().getMenu();

      expect(result.isSuccess, isTrue);
      final snapshot = result.valueOrNull!;
      expect(snapshot.source, MenuSource.imported);
      expect(snapshot.lastUpdated, DateTime(2026, 8, 17, 9));
      expect(
        snapshot.menu.messes.single.days.single.meals.single.items.single.name,
        'Cached',
      );
      // The whole point: the first frame never waits on a socket.
      expect(api.fetchCount, 0);
    });

    test('falls through to the network when nothing is cached', () async {
      final result = await buildRepository().getMenu();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.source, MenuSource.network);
      expect(api.fetchCount, 1);
    });

    test('treats an unparseable cache as absent rather than erroring', () async {
      storage.document = '{ this is not json';

      final result = await buildRepository().getMenu();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.source, MenuSource.network);
    });

    test(
      'reports an empty failure when there is no cache and no network',
      () async {
        api.failure = const MenuApiException('offline');

        final result = await buildRepository().getMenu();

        // This is the state the UI turns into the centred import prompt.
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull!.kind, FailureKind.empty);
      },
    );
  });

  group('refreshMenu — network with cache fallback', () {
    test('caches a successful fetch and stamps it', () async {
      final repository = buildRepository();
      api.body = documentFor('2026-08', dish: 'Fresh');

      final result = await repository.refreshMenu();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.source, MenuSource.network);
      expect(result.valueOrNull!.lastUpdated, isNotNull);
      expect(storage.document, contains('Fresh'));
      expect(storage.source, MenuSource.network);
      expect(await repository.lastUpdated(), isNotNull);
    });

    test('fails without disturbing an existing cache when offline', () async {
      storage
        ..document = documentFor('2026-08', dish: 'Cached')
        ..updatedAt = DateTime(2026, 8, 17, 9);
      api.failure = const MenuApiException('no route to host');

      final repository = buildRepository();
      final refreshed = await repository.refreshMenu();

      expect(refreshed.isFailure, isTrue);
      expect(refreshed.failureOrNull!.kind, FailureKind.network);
      // The cache survives, so the app stays fully usable offline.
      expect(storage.document, contains('Cached'));

      final fallback = await repository.getMenu();
      expect(fallback.isSuccess, isTrue);
      expect(
        fallback
            .valueOrNull!
            .menu
            .messes
            .single
            .days
            .single
            .meals
            .single
            .items
            .single
            .name,
        'Cached',
      );
    });

    test('reports a parse failure for a fetched but unreadable body', () async {
      api.body = '<html>404</html>';

      final result = await buildRepository().refreshMenu();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.parse);
      // Nothing unreadable is ever written to the cache.
      expect(storage.document, isNull);
    });

    test('still returns the menu when the cache write fails', () async {
      storage.writeSucceeds = false;

      final result = await buildRepository().refreshMenu();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.source, MenuSource.network);
    });
  });

  group('importMenu — Excel', () {
    test('parses a picked workbook and caches it as JSON', () async {
      files.picked = workbook();

      final result = await buildRepository().importMenu();

      expect(result.isSuccess, isTrue);
      final snapshot = result.valueOrNull!;
      expect(snapshot.source, MenuSource.imported);
      expect(snapshot.menu.month, '2026-08');
      expect(snapshot.menu.messes.single.id, 'veg-nonveg');

      // The cache always holds JSON, whatever the menu arrived as.
      expect(storage.source, MenuSource.imported);
      expect(Menu.decode(storage.document!), isNotNull);
      expect(storage.document, contains('Carrot Idly'));
    });

    test('an imported menu is what getMenu returns afterwards', () async {
      files.picked = workbook();
      final repository = buildRepository();

      await repository.importMenu();
      final reloaded = await repository.getMenu();

      expect(reloaded.isSuccess, isTrue);
      expect(reloaded.valueOrNull!.source, MenuSource.imported);
      // No network call was needed to serve it back.
      expect(api.fetchCount, 0);
    });

    test('announces the new menu on the change stream', () async {
      files.picked = workbook();
      final repository = buildRepository();

      final emitted = expectLater(
        repository.changes,
        emits(isA<MenuSnapshot>()),
      );
      await repository.importMenu();
      await emitted;
      await repository.dispose();
    });

    test('reports cancellation distinctly so the UI stays quiet', () async {
      files.picked = null;

      final result = await buildRepository().importMenu();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.cancelled);
    });

    test('reports a parse failure for a workbook with no menu rows', () async {
      files.picked = PickedWorkbook(
        name: 'notes.xlsx',
        bytes: buildWorkbook(<String, List<List<String>>>{
          'Sheet1': <List<String>>[
            <String>['Notes'],
            <String>['Nothing here'],
          ],
        }),
      );

      final result = await buildRepository().importMenu();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.parse);
      expect(storage.document, isNull);
    });

    test('reports a parse failure for a file that is not a workbook', () async {
      files.picked = const PickedWorkbook(
        name: 'menu.xlsx',
        bytes: <int>[1, 2, 3],
      );

      final result = await buildRepository().importMenu();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.parse);
    });

    test('surfaces a picker failure as a parse failure', () async {
      files.failure = const FileImportException('Not a spreadsheet');

      final result = await buildRepository().importMenu();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.parse);
    });
  });

  group('refreshMenu — no menu server configured', () {
    test('reports unsupported instead of firing a doomed request', () async {
      // The shipped build still carries the placeholder URL.
      expect(AppConfig.isRemoteConfigured, isFalse);

      final result = await buildRepositoryWithoutRemote().refreshMenu();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.unsupported);
      // No socket was opened, so the student never waits on a timeout.
      expect(api.fetchCount, 0);
    });

    test('leaves an existing cache untouched', () async {
      storage.document = documentFor('2026-08', dish: 'Cached');

      final repository = buildRepositoryWithoutRemote();
      await repository.refreshMenu();

      expect(storage.document, contains('Cached'));
      final reloaded = await repository.getMenu();
      expect(reloaded.isSuccess, isTrue);
      expect(
        reloaded
            .valueOrNull!
            .menu
            .messes
            .single
            .days
            .single
            .meals
            .single
            .items
            .single
            .name,
        'Cached',
      );
    });

    test('getMenu still ends at the import prompt', () async {
      final result = await buildRepositoryWithoutRemote().getMenu();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.empty);
      expect(api.fetchCount, 0);
    });
  });

  group('empty-state reporting', () {
    test('is reported once even though three screens ask', () async {
      final repository = buildRepositoryWithoutRemote();

      await repository.getMenu();
      await repository.getMenu();
      await repository.getMenu();

      // Home, Week and Search each call getMenu on startup; the student saw
      // one prompt, so it is one event.
      expect(repository.debugEmptyPromptReported, isTrue);
    });
  });

  group('clearCache', () {
    test('drops the cache so the import prompt returns', () async {
      storage.document = documentFor('2026-08', dish: 'Cached');
      api.failure = const MenuApiException('offline');
      final repository = buildRepository();

      expect((await repository.clearCache()).isSuccess, isTrue);

      final result = await repository.getMenu();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.empty);
    });
  });

  group('stale month handling', () {
    test('a cached document from last month is reported as stale', () async {
      storage.document = documentFor('2026-07');

      final result = await buildRepository().getMenu();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.isStaleFor(DateTime(2026, 8, 17)), isTrue);
    });
  });
}
