import 'package:flutter/material.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_theme.dart';
import '../models/meal_item.dart';
import '../viewmodels/meal_presentation.dart';
import 'meal_item_tile.dart';
import 'staggered_entrance.dart';
import 'variant_pair_tile.dart';

/// Renders a meal's dishes in menu order.
///
/// Consecutive veg/non-veg entries are folded into a single
/// [VariantPairTile], so a paired alternative reads as one choice rather than
/// two separate dishes. Order is preserved: pairs stay where the mess printed
/// them.
class MealItemsList extends StatelessWidget {
  /// Creates a list for [items].
  const MealItemsList({
    required this.items,
    super.key,
    this.dimmed = false,
    this.onAccent = false,
    this.animate = true,
  });

  /// The dishes, in menu order.
  final List<MealItem> items;

  /// Desaturates every row, used for meals that have closed.
  final bool dimmed;

  /// Renders for the saturated now-serving card.
  final bool onAccent;

  /// Plays the staggered entrance.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    var i = 0;
    while (i < items.length) {
      final current = items[i];
      final next = (i + 1 < items.length) ? items[i + 1] : null;

      if (current.isPaired && next != null && next.isPaired) {
        rows.add(
          VariantPairTile(
            items: <MealItem>[current, next],
            dimmed: dimmed,
            onAccent: onAccent,
          ),
        );
        i += 2;
        continue;
      }

      rows.add(MealItemTile(item: current, dimmed: dimmed, onAccent: onAccent));
      i += 1;
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    if (!animate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    }
    return StaggeredEntrance(children: rows);
  }
}

/// A collapsed meal summary that expands to show its dishes.
///
/// State is read at a glance: closed meals are dimmed and desaturated,
/// upcoming meals are neutral, and nothing here is ever saturated — the
/// now-serving card owns the only accent on screen.
class MealCard extends StatefulWidget {
  /// Creates a card for [presentation].
  const MealCard({
    required this.presentation,
    super.key,
    this.initiallyExpanded = false,
  });

  /// The meal and the state to draw it in.
  final MealPresentation presentation;

  /// Whether the card starts open.
  final bool initiallyExpanded;

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;
    final meal = widget.presentation.meal;
    final status = widget.presentation.status;
    final isClosed = status.isClosed;

    final titleColor = isClosed ? colors.closedText : colors.textPrimary;
    final subtitleColor = isClosed ? colors.closedText : colors.textSecondary;

    return Semantics(
      button: true,
      expanded: _expanded,
      label: Strings.mealName(meal.type),
      hint: _expanded ? Strings.a11yCollapseMeal : Strings.a11yExpandMeal,
      child: Material(
        color: isClosed ? colors.closedSurface : colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _toggle,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(
                color: status.isUpcoming
                    ? colors.hairline
                    : colors.hairline.withValues(alpha: 0.45),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  Strings.mealName(meal.type),
                                  style: textTheme.titleLarge?.copyWith(
                                    color: titleColor,
                                  ),
                                ),
                              ),
                              if (status.isServing) ...<Widget>[
                                const SizedBox(width: 8),
                                _StatusDot(color: colors.accent),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${Strings.formatWindow(meal.startTime, meal.endTime)}'
                            '  ·  ${Strings.itemCount(meal.itemCount)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8, right: 6),
                          child: MealItemsList(
                            items: meal.items,
                            dimmed: isClosed,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small accent dot marking the meal that is open right now.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
