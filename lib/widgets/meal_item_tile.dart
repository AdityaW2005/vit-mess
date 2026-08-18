import 'package:flutter/material.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_theme.dart';
import '../models/meal_item.dart';

/// The standard Indian veg / non-veg mark: a square outline with a filled
/// circle inside.
class VariantMark extends StatelessWidget {
  /// Creates a mark for [variant].
  ///
  /// A `null` variant draws a neutral mark, which is what unmarked items get.
  const VariantMark({required this.variant, super.key, this.size = 14, this.dimmed = false});

  /// Which mark to draw.
  final ItemVariant? variant;

  /// Outer square edge length.
  final double size;

  /// Desaturates the mark for closed meals.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final color = switch (variant) {
      ItemVariant.veg => colors.veg,
      ItemVariant.nonVeg => colors.nonVeg,
      null => colors.textMuted,
    };
    final effective = dimmed ? color.withValues(alpha: 0.45) : color;

    return Semantics(
      label: switch (variant) {
        ItemVariant.veg => Strings.a11yVegItem,
        ItemVariant.nonVeg => Strings.a11yNonVegItem,
        null => null,
      },
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: effective, width: 1.4),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            child: Container(
              width: size * 0.5,
              height: size * 0.5,
              decoration: BoxDecoration(
                color: effective,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One dish in a meal's list.
///
/// Deliberately plain: the item list is what a student scans, so nothing here
/// competes with the countdown above it.
class MealItemTile extends StatelessWidget {
  /// Creates a tile for [item].
  const MealItemTile({
    required this.item,
    super.key,
    this.dimmed = false,
    this.onAccent = false,
  });

  /// The dish to render.
  final MealItem item;

  /// Desaturates the row, used for meals that have closed.
  final bool dimmed;

  /// Renders for the saturated now-serving card rather than a plain surface.
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    final textColor = onAccent
        ? colors.onAccent
        : (dimmed ? colors.closedText : colors.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            // Nudged down so the mark optically aligns with the first text
            // line at any text scale.
            padding: const EdgeInsets.only(top: 3),
            child: VariantMark(
              variant: item.variant,
              dimmed: dimmed && !onAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: textTheme.bodyLarge?.copyWith(
                color: textColor,
                fontWeight: onAccent ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
