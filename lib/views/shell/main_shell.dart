import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/strings.dart';
import '../../viewmodels/home_view_model.dart';
import '../../viewmodels/search_view_model.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../viewmodels/week_view_model.dart';
import '../home/home_view.dart';
import '../search/search_view.dart';
import '../settings/settings_view.dart';
import '../week/week_view.dart';

/// The four-tab shell.
///
/// Tabs live in an [IndexedStack] so switching away and back does not throw
/// away scroll position, the day selection, or a search in progress.
class MainShell extends StatefulWidget {
  /// Creates the shell.
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportScreen(_index);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    // The reminder schedule only runs a week ahead and the system drops
    // pending alarms on reboot, so coming back to the app rebuilds it. The
    // ViewModel owns that work; the shell only reports the lifecycle.
    context.read<HomeViewModel>().onAppResumed();
    context.read<SettingsViewModel>().refreshReminderStatus();
  }

  void _onDestinationSelected(int index) {
    // Tapping the tab you are already on is not a new screen view.
    if (index == _index) return;
    setState(() => _index = index);
    _reportScreen(index);
  }

  /// Each tab reports itself through its own ViewModel, so the view never
  /// touches the analytics layer directly.
  void _reportScreen(int index) {
    switch (index) {
      case 0:
        context.read<HomeViewModel>().onShown();
      case 1:
        context.read<WeekViewModel>().onShown();
      case 2:
        context.read<SearchViewModel>().onShown();
      case 3:
        context.read<SettingsViewModel>().onShown();
    }
  }

  static const List<Widget> _tabs = <Widget>[
    HomeView(),
    WeekView(),
    SearchView(),
    SettingsView(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _index, children: _tabs),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _onDestinationSelected,
      destinations: const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.local_dining_outlined),
          selectedIcon: Icon(Icons.local_dining_rounded),
          label: Strings.navHome,
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: Strings.navWeek,
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search_rounded),
          label: Strings.navSearch,
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune_rounded),
          label: Strings.navSettings,
        ),
      ],
    ),
  );
}
