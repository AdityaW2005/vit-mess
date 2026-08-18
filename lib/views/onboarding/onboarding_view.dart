import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../viewmodels/settings_view_model.dart';

/// Shown once, on first launch: pick a tier, optionally enable reminders.
///
/// The choice is persisted through [SettingsViewModel], after which this
/// screen is never shown again.
class OnboardingView extends StatefulWidget {
  /// Creates the onboarding screen.
  const OnboardingView({required this.onCompleted, super.key});

  /// Called once the choice has been persisted.
  final VoidCallback onCompleted;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  // Local until committed: nothing is persisted while the student is still
  // deciding, so this is not ViewModel state.
  String _selectedMessId = AppConfig.defaultMessId;
  bool _remindersRequested = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SettingsViewModel>().initialize();
    });
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final viewModel = context.read<SettingsViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    final granted = await viewModel.completeOnboarding(
      messId: _selectedMessId,
      remindersRequested: _remindersRequested,
    );

    if (!mounted) return;
    if (_remindersRequested && !granted) {
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.toastRemindersBlocked)),
      );
    }
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: AppTheme.pagePadding.add(
                  const EdgeInsets.only(top: 32, bottom: 24),
                ),
                children: <Widget>[
                  Text(
                    Strings.appName.toUpperCase(),
                    style: AppTypography.eyebrow(colors.accent),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    Strings.onboardingTitle,
                    style: textTheme.displaySmall?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    Strings.onboardingSubtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  _TierCard(
                    name: Strings.onboardingTierVegNonVegName,
                    blurb: Strings.onboardingTierVegNonVegBlurb,
                    icon: Icons.lunch_dining_rounded,
                    selected: _selectedMessId == AppConfig.messIdVegNonVeg,
                    onTap: () => setState(
                      () => _selectedMessId = AppConfig.messIdVegNonVeg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TierCard(
                    name: Strings.onboardingTierSpecialName,
                    blurb: Strings.onboardingTierSpecialBlurb,
                    icon: Icons.restaurant_rounded,
                    selected: _selectedMessId == AppConfig.messIdSpecial,
                    onTap: () => setState(
                      () => _selectedMessId = AppConfig.messIdSpecial,
                    ),
                  ),

                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppTheme.chipRadius),
                      border: Border.all(color: colors.hairline),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _remindersRequested,
                      onChanged: (value) =>
                          setState(() => _remindersRequested = value),
                      title: const Text(Strings.onboardingRemindersTitle),
                      subtitle: const Text(Strings.onboardingRemindersBlurb),
                      isThreeLine: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: AppTheme.pagePadding.add(
                const EdgeInsets.only(bottom: 20, top: 8),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _finish,
                  child: _submitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onAccent,
                          ),
                        )
                      : const Text(Strings.onboardingContinue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable subscription tier.
class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.name,
    required this.blurb,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String blurb;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: name,
      hint: selected ? Strings.onboardingSelectedHint : null,
      child: Material(
        color: selected ? colors.accentTint : colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(
                color: selected ? colors.accent : colors.hairline,
                width: selected ? 1.8 : 1,
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  icon,
                  size: 26,
                  color: selected ? colors.accent : colors.textMuted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: textTheme.titleLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        blurb,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: colors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
