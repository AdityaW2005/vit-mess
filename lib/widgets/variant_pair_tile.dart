import 'package:flutter/material.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_theme.dart';
import '../models/meal_item.dart';
import 'meal_item_tile.dart';

/// A paired veg / non-veg alternative, rendered as one tile.
///
/// The contract lists these as two adjacent items, but they are a single
/// choice: the mess serves one *or* the other depending on your tier. Drawing
/// them as two unrelated rows would read as two extra dishes, so they share a
/// bordered container with a divider and an explicit "or".
class VariantPairTile extends StatelessWidget {
  /// Creates a tile for [items], normally two entries.
  const VariantPairTile({
    required this.items,
    super.key,
    this.dimmed = false,
    this.onAccent = false,
  });

  /// The paired alternatives, in menu order.
  final List<MealItem> items;

  /// Desaturates the tile, used for meals that have closed.
  final bool dimmed;

  /// Renders for the saturated now-serving card rather than a plain surface.
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;

    // A pair that lost its partner during parsing degrades to a plain row
    // rather than drawing an empty half.
    if (items.length == 1) {
      return MealItemTile(item: items.first, dimmed: dimmed, onAccent: onAccent);
    }
    if (items.isEmpty) return const SizedBox.shrink();

    final borderColor = onAccent
        ? colors.onAccent.withValues(alpha: 0.28)
        : colors.hairline;
    final fillColor = onAccent
        ? colors.onAccent.withValues(alpha: 0.08)
        : colors.surfaceRaised.withValues(alpha: dimmed ? 0.45 : 1);

    return Semantics(
      label: Strings.a11yPairedItem,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(AppTheme.chipRadius),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) _PairDivider(onAccent: onAccent),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: MealItemTile(
                  item: items[i],
                  dimmed: dimmed,
                  onAccent: onAccent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The hairline between the two halves, carrying a small "or" label.
class _PairDivider extends StatelessWidget {
  const _PairDivider({required this.onAccent});

  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final lineColor = onAccent
        ? colors.onAccent.withValues(alpha: 0.24)
        : colors.hairline;
    final labelColor = onAccent
        ? colors.onAccent.withValues(alpha: 0.7)
        : colors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: lineColor, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              Strings.variantOr,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(child: Divider(color: lineColor, height: 1)),
        ],
      ),
    );
  }
}
