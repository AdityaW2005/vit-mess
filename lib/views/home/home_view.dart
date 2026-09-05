import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/result.dart';
import '../../viewmodels/base_view_model.dart';
import '../../viewmodels/home_view_model.dart';
import '../../widgets/error_state.dart';
import '../../widgets/meal_card.dart';
import '../../widgets/now_serving_card.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/staggered_entrance.dart';
import '../../widgets/stale_menu_dialog.dart';

/// The hero screen: what is being served right now, and how long is left.
///
/// Holds no business logic — every value comes from [HomeViewModel], including
/// the current time, so nothing here recomputes state during a build.
class HomeView extends StatefulWidget {
  /// Creates the home screen.
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    // Kick the first load after the frame so the ViewModel can notify freely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeViewModel>().initialize();
    });
  }

  Future<void> _importInstead() async {
    final viewModel = context.read<HomeViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await viewModel.importMenu(
      confirmStaleMonth: (candidate) async {
        // The picker ran on another screen; this one may be gone by now, and
        // the safe answer is to leave the cached menu alone.
        if (!mounted) return false;
        return confirmStaleMenuImport(context, candidate);
      },
    );
    if (!mounted) return;

    final message = result.fold<String?>(
      onSuccess: (_) => Strings.toastImported,
      onFailure: (failure) =>
          failure.kind == FailureKind.cancelled ? null : failure.message,
    );
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<HomeViewModel>(
    builder: (context, viewModel, _) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (viewModel.state) {
          ViewState.idle || ViewState.busy => const HomeShimmer(),
          ViewState.error => ErrorState.forFailure(
            kind: viewModel.errorKind ?? FailureKind.unknown,
            message: viewModel.errorMessage ?? Strings.failureUnknown,
            onRetry: viewModel.refresh,
            onImport: _importInstead,
            busy: viewModel.isImporting,
          ),
          ViewState.ready => _HomeContent(
            viewModel: viewModel,
            onImport: _importInstead,
          ),
        },
      ),
    ),
  );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.viewModel, required this.onImport});

  final HomeViewModel viewModel;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final focus = viewModel.focus;

    return RefreshIndicator(
      onRefresh: () => viewModel.refresh(userInitiated: true),
      color: context.mess.accent,
      backgroundColor: context.mess.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppTheme.pagePadding.add(
          const EdgeInsets.only(top: 8, bottom: 32),
        ),
        children: <Widget>[
          _HomeHeader(viewModel: viewModel),
          const SizedBox(height: 20),

          if (viewModel.showMonthUnavailable || focus == null)
            // Either the document is for another month, or it is after the
            // last meal of the last day it covers.
            ErrorState(
              icon: Icons.event_busy_rounded,
              title: Strings.homeMenuUnavailableTitle,
              message: Strings.homeMenuUnavailableBody,
              primaryLabel: Strings.errorRetry,
              onPrimary: viewModel.refresh,
              secondaryLabel: Strings.errorImportInstead,
              onSecondary: onImport,
              busy: viewModel.isImporting,
            )
          else ...<Widget>[
            NowServingCard(
              focus: focus,
              remaining: viewModel.countdown,
              now: viewModel.now,
              pairAlternatives: viewModel.pairsAlternatives,
            ),
            if (viewModel.otherMeals.isNotEmpty) ...<Widget>[
              const SizedBox(height: 30),
              Text(
                (focus.isOnLaterDay(viewModel.now)
                        ? Strings.homeTomorrow
                        : Strings.homeRestOfDay)
                    .toUpperCase(),
                style: AppTypography.eyebrow(context.mess.textMuted),
              ),
              const SizedBox(height: 14),
              StaggeredEntrance(
                children: <Widget>[
                  for (final presentation in viewModel.otherMeals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MealCard(
                        key: ValueKey<String>(
                          '${presentation.day.dateKey}-'
                          '${presentation.meal.type.jsonValue}',
                        ),
                        presentation: presentation,
                        pairAlternatives: viewModel.pairsAlternatives,
                        onExpansionChanged: (expanded) {
                          if (expanded) viewModel.logMealExpanded(presentation);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Date, plan name, and a refresh affordance.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                Strings.formatDayHeading(viewModel.now).toUpperCase(),
                style: AppTypography.eyebrow(colors.textMuted),
              ),
              const SizedBox(height: 6),
              Text(
                viewModel.mess?.name ?? Strings.appName,
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: Strings.a11yRefresh,
          child: IconButton(
            onPressed: viewModel.isRefreshing ? null : viewModel.refresh,
            icon: viewModel.isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }
}
