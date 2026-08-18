import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/strings.dart';
import 'core/service_locator.dart';
import 'repositories/analytics_repository.dart';
import 'core/theme/app_theme.dart';
import 'models/app_settings.dart';
import 'viewmodels/home_view_model.dart';
import 'viewmodels/search_view_model.dart';
import 'viewmodels/settings_view_model.dart';
import 'viewmodels/week_view_model.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/shell/main_shell.dart';

/// Route names used by the app.
class AppRoutes {
  const AppRoutes._();

  /// Decides between onboarding and the shell.
  static const String root = '/';

  /// First-run tier picker.
  static const String onboarding = '/onboarding';

  /// The four-tab shell.
  static const String home = '/home';
}

/// The application root.
///
/// Provides every ViewModel from the service locator, installs the light and
/// dark themes, and routes the first frame to onboarding or the shell.
class MessMateApp extends StatelessWidget {
  /// Creates the app.
  const MessMateApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      // ViewModels are resolved from get_it and kept for the life of the app,
      // so `dispose: false` — the locator owns them, not the provider.
      ChangeNotifierProvider<HomeViewModel>.value(
        value: locator<HomeViewModel>(),
      ),
      ChangeNotifierProvider<WeekViewModel>.value(
        value: locator<WeekViewModel>(),
      ),
      ChangeNotifierProvider<SearchViewModel>.value(
        value: locator<SearchViewModel>(),
      ),
      ChangeNotifierProvider<SettingsViewModel>.value(
        value: locator<SettingsViewModel>(),
      ),
    ],
    // Watching the settings ViewModel here is what lets the theme switch take
    // effect immediately, without restarting the app.
    child: Consumer<SettingsViewModel>(
      builder: (context, settings, _) => MaterialApp(
        title: Strings.appName,
        debugShowCheckedModeBanner: false,
        // Both themes ship complete; the student picks which one applies.
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeModeFor(settings.themeMode),
        // Routes push rarely here — the tabs report themselves — but this
        // catches anything pushed on top. Absent when analytics is off.
        navigatorObservers: <NavigatorObserver>[
          ?locator<AnalyticsRepository>().navigatorObserver,
        ],
        initialRoute: AppRoutes.root,
        routes: <String, WidgetBuilder>{
          AppRoutes.root: (context) => const _RootGate(),
          AppRoutes.onboarding: (context) => const _OnboardingRoute(),
          AppRoutes.home: (context) => const MainShell(),
        },
      ),
    ),
  );

  /// Maps the persisted preference onto Flutter's own enum.
  static ThemeMode _themeModeFor(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

/// Chooses the first screen based on whether onboarding has been completed.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  late bool _needsOnboarding =
      !context.read<SettingsViewModel>().onboardingCompleted;

  void _completeOnboarding() => setState(() => _needsOnboarding = false);

  @override
  Widget build(BuildContext context) => _needsOnboarding
      ? OnboardingView(onCompleted: _completeOnboarding)
      : const MainShell();
}

/// Onboarding reached by name, which pops back to whatever pushed it.
class _OnboardingRoute extends StatelessWidget {
  const _OnboardingRoute();

  @override
  Widget build(BuildContext context) => OnboardingView(
    onCompleted: () => Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
  );
}
