import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/config/meal_timings.dart';
import '../../core/constants/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/result.dart';
import '../../models/app_settings.dart';
import '../../models/meal.dart';
import '../../viewmodels/settings_view_model.dart';

/// Tier, timings, reminders and menu data.
class SettingsView extends StatefulWidget {
  /// Creates the settings screen.
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SettingsViewModel>().initialize();
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    final result = await context.read<SettingsViewModel>().forceRefresh();
    if (!mounted) return;
    _toast(
      result.fold(
        onSuccess: (_) => Strings.toastRefreshed,
        onFailure: (failure) => failure.message,
      ),
    );
  }

  Future<void> _import() async {
    final result = await context.read<SettingsViewModel>().importMenu();
    if (!mounted) return;
    final message = result.fold<String?>(
      onSuccess: (_) => Strings.toastImported,
      onFailure: (failure) =>
          failure.kind == FailureKind.cancelled ? null : failure.message,
    );
    if (message != null) _toast(message);
  }

  Future<void> _toggleReminders(bool enabled) async {
    final viewModel = context.read<SettingsViewModel>();
    final granted = await viewModel.setRemindersEnabled(enabled);
    if (!mounted) return;
    if (enabled && !granted) {
      _toast(Strings.toastRemindersBlocked);
    } else if (enabled) {
      _toast(Strings.toastRemindersScheduled);
    }
  }

  /// Opens the platform time picker for one end of a meal window.
  Future<void> _editWindow(MealType type, {required bool isStart}) async {
    final viewModel = context.read<SettingsViewModel>();
    final window = viewModel.windowFor(type);
    final current = isStart ? window.start : window.end;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || !mounted) return;

    final chosen = MinuteOfDay(picked.hour, picked.minute);
    final next = isStart
        ? MealWindow(chosen, window.end)
        : MealWindow(window.start, chosen);

    if (!next.isValid) {
      _toast(Strings.settingsTimingsInvalid);
      return;
    }
    await viewModel.setMealWindow(type, next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Consumer<SettingsViewModel>(
        builder: (context, viewModel, _) => ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: <Widget>[
            Padding(
              padding: AppTheme.pagePadding.add(
                const EdgeInsets.only(top: 8, bottom: 8),
              ),
              child: Text(
                Strings.settingsTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.mess.textPrimary,
                ),
              ),
            ),

            _Section(
              title: Strings.settingsPlanSection,
              subtitle: Strings.settingsPlanSubtitle,
              child: _PlanSelector(viewModel: viewModel),
            ),

            _Section(
              title: Strings.settingsTimingsSection,
              subtitle: Strings.settingsTimingsSubtitle,
              child: Column(
                children: <Widget>[
                  for (final type in MealType.values)
                    _TimingRow(
                      type: type,
                      window: viewModel.windowFor(type),
                      overridden: viewModel.isOverridden(type),
                      onEditStart: () => _editWindow(type, isStart: true),
                      onEditEnd: () => _editWindow(type, isStart: false),
                      onReset: () => viewModel.clearMealWindow(type),
                    ),
                  if (viewModel.settings.timings.hasOverrides)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            await viewModel.resetTimings();
                            _toast(Strings.toastTimingsReset);
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text(Strings.settingsTimingsReset),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            _Section(
              title: Strings.settingsRemindersSection,
              subtitle: Strings.settingsRemindersSubtitle,
              child: Column(
                children: <Widget>[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: viewModel.settings.remindersEnabled,
                    onChanged: _toggleReminders,
                    title: const Text(Strings.settingsRemindersMaster),
                    subtitle: viewModel.notificationsBlocked
                        ? const Text(Strings.toastRemindersBlocked)
                        : null,
                  ),
                  for (final type in MealType.values)
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.only(left: 8),
                      value: viewModel.settings.reminderMeals.contains(type),
                      onChanged: viewModel.settings.remindersEnabled
                          ? (value) => viewModel.setReminderForMeal(type, value)
                          : null,
                      title: Text(Strings.mealName(type)),
                      dense: true,
                    ),
                ],
              ),
            ),

            _Section(
              title: Strings.settingsDataSection,
              child: Column(
                children: <Widget>[
                  // Downloading is only offered once a menu server exists;
                  // otherwise the button would always fail and teach the
                  // student to distrust it.
                  if (viewModel.canRefreshFromServer)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.refresh_rounded),
                      title: const Text(Strings.settingsForceRefresh),
                      subtitle: Text(
                        Strings.lastUpdated(
                          viewModel.lastUpdated,
                          DateTime.now(),
                        ),
                      ),
                      trailing: viewModel.isRefreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: viewModel.isRefreshing ? null : _refresh,
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_open_outlined),
                    title: const Text(Strings.settingsImport),
                    subtitle: Text(
                      viewModel.canRefreshFromServer
                          ? Strings.settingsImportSubtitle
                          : '${Strings.settingsImportSubtitle}\n'
                                '${Strings.lastUpdated(viewModel.lastUpdated, DateTime.now())}',
                    ),
                    isThreeLine: !viewModel.canRefreshFromServer,
                    trailing: viewModel.isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: viewModel.isImporting ? null : _import,
                  ),
                ],
              ),
            ),

            _Section(
              title: Strings.settingsAppearanceSection,
              subtitle: Strings.settingsAppearanceSubtitle,
              child: _ThemeSelector(
                selected: viewModel.themeMode,
                onSelected: viewModel.setThemeMode,
              ),
            ),

            _Section(
              title: Strings.settingsPrivacySection,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: viewModel.settings.analyticsEnabled,
                onChanged: viewModel.setAnalyticsEnabled,
                title: const Text(Strings.settingsAnalytics),
                subtitle: const Text(Strings.settingsAnalyticsSubtitle),
                isThreeLine: true,
              ),
            ),

            _Section(
              title: Strings.settingsAboutSection,
              child: Column(
                children: <Widget>[
                  _AboutRow(
                    label: Strings.settingsCampusLabel,
                    value: viewModel.snapshot?.menu.campus ?? AppConfig.campus,
                  ),
                  _AboutRow(
                    label: Strings.settingsMonthLabel,
                    value: Strings.formatMonthKey(
                      viewModel.snapshot?.menu.month,
                    ),
                  ),
                  _AboutRow(
                    label: Strings.settingsSchemaLabel,
                    value:
                        'v${viewModel.snapshot?.menu.schemaVersion ?? AppConfig.supportedSchemaVersion}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A titled group of settings rows.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: AppTheme.pagePadding.add(const EdgeInsets.only(top: 22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: AppTypography.eyebrow(colors.accent),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Three-way light / dark / system switch.
///
/// Both themes are complete and shipped; this is where a student picks which
/// one applies, rather than being stuck with whatever the device says.
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.selected, required this.onSelected});

  final AppThemeMode selected;
  final ValueChanged<AppThemeMode> onSelected;

  static const Map<AppThemeMode, IconData> _icons = <AppThemeMode, IconData>{
    AppThemeMode.system: Icons.brightness_auto_rounded,
    AppThemeMode.light: Icons.light_mode_rounded,
    AppThemeMode.dark: Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.chipRadius),
        border: Border.all(color: colors.hairline),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          for (final mode in AppThemeMode.values)
            Expanded(
              child: _ThemeOption(
                mode: mode,
                icon: _icons[mode]!,
                selected: mode == selected,
                onTap: () => onSelected(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected ? colors.onAccent : colors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: '${Strings.a11ySelectTheme}: ${Strings.themeModeLabel(mode)}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.chipRadius - 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected ? colors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.chipRadius - 2),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 20, color: foreground),
                const SizedBox(height: 6),
                Text(
                  Strings.themeModeLabel(mode),
                  style: textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tier switcher.
class _PlanSelector extends StatelessWidget {
  const _PlanSelector({required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final options = viewModel.messOptions;
    if (options.isEmpty) {
      return Text(
        Strings.failureEmpty,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      children: <Widget>[
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PlanTile(
              name: option.name,
              selected: option.id == viewModel.settings.messId,
              onTap: () => viewModel.selectMess(option.id),
            ),
          ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.accentTint : colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.chipRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.chipRadius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.chipRadius),
              border: Border.all(
                color: selected ? colors.accent : colors.hairline,
                width: selected ? 1.6 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? colors.accent : colors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One meal's editable serving window.
class _TimingRow extends StatelessWidget {
  const _TimingRow({
    required this.type,
    required this.window,
    required this.overridden,
    required this.onEditStart,
    required this.onEditEnd,
    required this.onReset,
  });

  final MealType type;
  final MealWindow window;
  final bool overridden;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    // Breakfast runs to two clocks across the week. An override replaces both,
    // so the note only applies while the published times are in force.
    final showsWeekdayNote = type.hasWeekdayVariants && !overridden;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        Strings.mealName(type),
                        style: textTheme.titleMedium?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (overridden) ...<Widget>[
                      const SizedBox(width: 8),
                      Text(
                        Strings.settingsTimingsOverridden.toUpperCase(),
                        style: AppTypography.eyebrow(colors.accent),
                      ),
                    ],
                  ],
                ),
              ),
              _TimeButton(
                label: Strings.formatClock(window.start),
                onTap: onEditStart,
              ),
              Text(
                '–',
                style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
              ),
              _TimeButton(
                label: Strings.formatClock(window.end),
                onTap: onEditEnd,
              ),
              if (overridden)
                IconButton(
                  tooltip: Strings.settingsTimingsReset,
                  onPressed: onReset,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                ),
            ],
          ),
          if (showsWeekdayNote)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                Strings.lateBreakfastNote(),
                style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: colors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}

/// A read-only label / value row.
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
