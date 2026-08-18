import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/result.dart';
import '../../viewmodels/base_view_model.dart';
import '../../viewmodels/week_view_model.dart';
import '../../widgets/day_strip.dart';
import '../../widgets/error_state.dart';
import '../../widgets/meal_card.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/staggered_entrance.dart';

/// Browses the whole month: a day strip on top, that day's four meals below.
///
/// The strip and the body are two views of one selection, which lives in
/// [WeekViewModel]. Swiping the body and tapping the strip both route through
/// `selectDay`, so they can never disagree.
class WeekView extends StatefulWidget {
  /// Creates the week screen.
  const WeekView({super.key});

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  PageController? _pageController;
  int _lastSyncedIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WeekViewModel>().initialize();
    });
  }

  Future<void> _import() async {
    final viewModel = context.read<WeekViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await viewModel.importMenu();
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
  void dispose() {
    _pageController?.dispose();
    _pageController = null;
    super.dispose();
  }

  /// Creates the controller once the day count is known, and keeps its page in
  /// step with the ViewModel's selection.
  PageController _controllerFor(int selectedIndex) {
    final controller =
        _pageController ??= PageController(initialPage: selectedIndex);

    if (selectedIndex != _lastSyncedIndex) {
      _lastSyncedIndex = selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !controller.hasClients) return;
        if (controller.page?.round() == selectedIndex) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          controller.jumpToPage(selectedIndex);
        } else {
          controller.animateToPage(
            selectedIndex,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) => Consumer<WeekViewModel>(
    builder: (context, viewModel, _) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (viewModel.state) {
          ViewState.idle || ViewState.busy => const WeekShimmer(),
          ViewState.error => ErrorState.forFailure(
            kind: viewModel.errorKind ?? FailureKind.unknown,
            message: viewModel.errorMessage ?? Strings.failureUnknown,
            onRetry: viewModel.refresh,
            onImport: _import,
            busy: viewModel.isImporting,
          ),
          ViewState.ready => viewModel.isEmpty
              ? ErrorState.importPrompt(
                  onImport: _import,
                  onRetry: viewModel.refresh,
                  busy: viewModel.isImporting,
                )
              : _WeekContent(
                  viewModel: viewModel,
                  controller: _controllerFor(viewModel.selectedIndex),
                ),
        },
      ),
    ),
  );
}

class _WeekContent extends StatelessWidget {
  const _WeekContent({required this.viewModel, required this.controller});

  final WeekViewModel viewModel;
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: AppTheme.pagePadding.add(
            const EdgeInsets.only(top: 8, bottom: 14),
          ),
          child: Text(
            Strings.weekTitle,
            style: textTheme.headlineMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        DayStrip(
          days: viewModel.days,
          selectedIndex: viewModel.selectedIndex,
          todayIndex: viewModel.todayIndex,
          onSelected: viewModel.selectDay,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: viewModel.days.length,
            onPageChanged: viewModel.selectDay,
            itemBuilder: (context, index) => _DayPage(
              viewModel: viewModel,
              index: index,
            ),
          ),
        ),
      ],
    );
  }
}

/// One day's meals. Only the selected page carries resolved statuses; the
/// neighbours a `PageView` pre-builds render from the same day list.
class _DayPage extends StatelessWidget {
  const _DayPage({required this.viewModel, required this.index});

  final WeekViewModel viewModel;
  final int index;

  @override
  Widget build(BuildContext context) {
    final day = viewModel.days[index];
    final presentations = viewModel.mealsForIndex(index);

    return ListView(
      padding: AppTheme.pagePadding.add(const EdgeInsets.only(bottom: 32)),
      children: <Widget>[
        DayStripHeading(date: day.date, now: viewModel.now),
        const SizedBox(height: 16),
        if (presentations.isEmpty)
          const _EmptyDayNote()
        else
          StaggeredEntrance(
            children: <Widget>[
              for (final presentation in presentations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MealCard(
                    // Status is part of the key so a meal that opens while the
                    // tab is alive rebuilds and honours `initiallyExpanded`.
                    // Without it the card keeps whatever state it had when the
                    // IndexedStack first built this page.
                    key: ValueKey<String>(
                      '${presentation.day.dateKey}-'
                      '${presentation.meal.type.jsonValue}-'
                      '${presentation.status.name}',
                    ),
                    presentation: presentation,
                    initiallyExpanded: presentation.status.isServing,
                    pairAlternatives: viewModel.pairsAlternatives,
                    onExpansionChanged: (expanded) {
                      if (expanded) viewModel.logMealExpanded(presentation);
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Shown when a day carries no meals at all.
class _EmptyDayNote extends StatelessWidget {
  const _EmptyDayNote();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 48),
    child: ErrorState(
      icon: Icons.no_meals_rounded,
      title: Strings.homeNoMealsTitle,
      message: Strings.homeNoMealsBody,
    ),
  );
}
