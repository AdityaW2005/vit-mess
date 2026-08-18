import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
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

class _MainShellState extends State<MainShell> {
  int _index = 0;

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
      onDestinationSelected: (index) => setState(() => _index = index),
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
