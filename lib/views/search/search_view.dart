import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/result.dart';
import '../../viewmodels/search_view_model.dart';
import '../../widgets/error_state.dart';
import '../../widgets/meal_item_tile.dart';

/// Searches every dish in the month.
///
/// Built around the question students actually ask — "when is chicken biryani
/// next?" — so results run from today forwards, grouped by date, each labelled
/// with how far away it is.
class SearchView extends StatefulWidget {
  /// Creates the search screen.
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SearchViewModel>().initialize();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    context.read<SearchViewModel>().clear();
    _focusNode.requestFocus();
  }

  Future<void> _import() async {
    final viewModel = context.read<SearchViewModel>();
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
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Consumer<SearchViewModel>(
        builder: (context, viewModel, _) {
          // With no menu on the device there is nothing to search, so the
          // import prompt replaces the whole screen rather than sitting under
          // a search box that cannot work.
          if (viewModel.hasError) {
            return ErrorState.forFailure(
              kind: viewModel.errorKind ?? FailureKind.unknown,
              message: viewModel.errorMessage ?? Strings.failureUnknown,
              onImport: _import,
              busy: viewModel.isImporting,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: AppTheme.pagePadding.add(
                  const EdgeInsets.only(top: 8, bottom: 14),
                ),
                child: Text(
                  Strings.searchTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: context.mess.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: AppTheme.pagePadding,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onChanged: viewModel.setQuery,
                  decoration: InputDecoration(
                    hintText: Strings.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: viewModel.hasQuery
                        ? IconButton(
                            tooltip: Strings.searchClear,
                            onPressed: _clear,
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                ),
              ),
              if (viewModel.hasQuery && viewModel.groups.isNotEmpty)
                Padding(
                  padding: AppTheme.pagePadding.add(
                    const EdgeInsets.only(top: 16),
                  ),
                  child: Text(
                    Strings.resultCount(viewModel.resultCount).toUpperCase(),
                    style: AppTypography.eyebrow(context.mess.textMuted),
                  ),
                ),
              Expanded(child: _SearchBody(viewModel: viewModel)),
            ],
          );
        },
      ),
    ),
  );
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({required this.viewModel});

  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hasQuery) {
      return const ErrorState(
        icon: Icons.search_rounded,
        title: Strings.searchEmptyTitle,
        message: Strings.searchEmptyBody,
      );
    }

    if (viewModel.hasNoResults) {
      return const ErrorState(
        icon: Icons.no_food_rounded,
        title: Strings.searchNoResultsTitle,
        message: Strings.searchNoResultsBody,
      );
    }

    final groups = viewModel.groups;
    return ListView.builder(
      padding: AppTheme.pagePadding.add(
        const EdgeInsets.only(top: 12, bottom: 32),
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) => _ResultGroupCard(group: groups[index]),
    );
  }
}

/// One date's worth of matches.
class _ResultGroupCard extends StatelessWidget {
  const _ResultGroupCard({required this.group});

  final SearchDayGroup group;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: colors.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(
                  child: Text(
                    Strings.formatDayLong(group.day.date),
                    style: textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  Strings.relativeDay(group.daysFromToday).toUpperCase(),
                  style: AppTypography.eyebrow(colors.accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final hit in group.hits)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: MealItemTile(item: hit.item),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _MealChip(label: Strings.mealName(hit.meal.type)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Which meal a hit belongs to.
class _MealChip extends StatelessWidget {
  const _MealChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.accentTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: AppTypography.eyebrow(colors.accent)),
    );
  }
}
