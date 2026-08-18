import 'package:get_it/get_it.dart';

import '../repositories/analytics_repository.dart';
import '../repositories/analytics_repository_impl.dart';
import '../repositories/menu_repository.dart';
import '../repositories/menu_repository_impl.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/reminder_repository_impl.dart';
import '../repositories/settings_repository.dart';
import '../repositories/settings_repository_impl.dart';
import '../services/analytics_service.dart';
import '../services/file_import_service.dart';
import '../services/local_storage_service.dart';
import '../services/menu_api_service.dart';
import '../services/notification_service.dart';
import '../viewmodels/home_view_model.dart';
import '../viewmodels/search_view_model.dart';
import '../viewmodels/settings_view_model.dart';
import '../viewmodels/week_view_model.dart';

/// The app's single dependency container.
final GetIt locator = GetIt.instance;

/// Registers every service, repository and ViewModel.
///
/// Repositories are registered against their *interfaces*, which is what lets
/// ViewModels stay ignorant of the implementations and lets tests swap in
/// fakes. Call this once, before `runApp`.
Future<void> setupServiceLocator() async {
  // ------------------------------------------------------------- services
  // Storage has to be awaited: everything downstream reads from it.
  final storage = await LocalStorageService.create();
  locator
    ..registerSingleton<LocalStorageService>(storage)
    ..registerLazySingleton<MenuApiService>(MenuApiService.new)
    ..registerLazySingleton<FileImportService>(FileImportService.new)
    ..registerLazySingleton<NotificationService>(NotificationService.new)
    ..registerLazySingleton<AnalyticsService>(AnalyticsService.new);

  // --------------------------------------------------------- repositories
  locator
    ..registerLazySingleton<MenuRepository>(
      () => MenuRepositoryImpl(
        api: locator<MenuApiService>(),
        storage: locator<LocalStorageService>(),
        files: locator<FileImportService>(),
        analytics: locator<AnalyticsRepository>(),
      ),
    )
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(storage: locator<LocalStorageService>()),
    )
    ..registerLazySingleton<ReminderRepository>(
      () => ReminderRepositoryImpl(
        notifications: locator<NotificationService>(),
      ),
    )
    ..registerLazySingleton<AnalyticsRepository>(
      () => AnalyticsRepositoryImpl(analytics: locator<AnalyticsService>()),
    );

  // Load persisted settings before the first frame so onboarding is decided
  // without a flash of the wrong screen.
  await locator<SettingsRepository>().load();

  // Analytics starts after settings, so the stored consent choice is applied
  // before the first event can fire. It never throws: an unconfigured build
  // simply collects nothing.
  await locator<AnalyticsRepository>().initialize(
    locator<SettingsRepository>().current,
  );

  // ----------------------------------------------------------- viewmodels
  // Registered as lazy singletons: the four tabs live in an IndexedStack and
  // keep their state for the life of the app.
  locator
    ..registerLazySingleton<HomeViewModel>(
      () => HomeViewModel(
        menuRepository: locator<MenuRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        reminderRepository: locator<ReminderRepository>(),
        analyticsRepository: locator<AnalyticsRepository>(),
      ),
    )
    ..registerLazySingleton<WeekViewModel>(
      () => WeekViewModel(
        menuRepository: locator<MenuRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        analyticsRepository: locator<AnalyticsRepository>(),
      ),
    )
    ..registerLazySingleton<SearchViewModel>(
      () => SearchViewModel(
        menuRepository: locator<MenuRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        analyticsRepository: locator<AnalyticsRepository>(),
      ),
    )
    ..registerLazySingleton<SettingsViewModel>(
      () => SettingsViewModel(
        menuRepository: locator<MenuRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        reminderRepository: locator<ReminderRepository>(),
        analyticsRepository: locator<AnalyticsRepository>(),
      ),
    );
}

/// Tears the container down. Used by tests.
Future<void> resetServiceLocator() async {
  await locator.reset();
}
