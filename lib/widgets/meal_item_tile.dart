import 'package:flutter/material.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/dish_classifier.dart';
import '../models/meal_item.dart';

/// The standard Indian veg / non-veg mark: a square outline with a filled
/// circle inside.
///
/// A highlighted dish draws its mark at full strength — green for the marquee
/// vegetarian dishes, red for anything non-veg. Everyday staples keep a muted
/// mark so the highlight stays worth looking for.
class VariantMark extends StatelessWidget {
  /// Creates a mark for [highlight].
  const VariantMark({
    required this.highlight,
    super.key,
    this.size = 14,
    this.dimmed = false,
    this.onAccent = false,
  });

  /// What the dish was classified as.
  final DishHighlight highlight;

  /// Outer square edge length.
  final double size;

  /// Desaturates the mark for closed meals.
  final bool dimmed;

  /// Renders for the saturated now-serving card.
  final bool onAccent;

  /// The mark colour for [highlight] in the current theme.
  static Color colorFor(
    BuildContext context,
    DishHighlight highlight, {
    bool onAccent = false,
  }) {
    final colors = context.mess;
    return switch (highlight) {
      DishHighlight.veg => onAccent ? colors.vegOnAccent : colors.veg,
      DishHighlight.nonVeg => onAccent ? colors.nonVegOnAccent : colors.nonVeg,
      DishHighlight.none => onAccent
          ? colors.onAccent.withValues(alpha: 0.55)
          : colors.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(context, highlight, onAccent: onAccent);
    final effective = dimmed ? color.withValues(alpha: 0.45) : color;
    final strong = highlight.isHighlighted;

    return Semantics(
      label: switch (highlight) {
        DishHighlight.veg => Strings.a11yVegItem,
        DishHighlight.nonVeg => Strings.a11yNonVegItem,
        DishHighlight.none => null,
      },
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // A highlighted mark carries a faint wash inside the square, which
            // is what makes it read from arm's length.
            color: strong
                ? effective.withValues(alpha: onAccent ? 0.22 : 0.14)
                : Colors.transparent,
            border: Border.all(color: effective, width: strong ? 1.8 : 1.4),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            child: Container(
              width: size * (strong ? 0.56 : 0.5),
              height: size * (strong ? 0.56 : 0.5),
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
/// Staples stay quiet; the dish that decides the meal — paneer, mushroom,
/// chicken, fish — is lifted with a saturated mark, a tinted strip and a
/// heavier name, so a student can find it without reading the list.
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
    final highlight = item.highlight;
    final isHighlighted = highlight.isHighlighted;

    final markColor = VariantMark.colorFor(
      context,
      highlight,
      onAccent: onAccent,
    );

    final textColor = onAccent
        ? colors.onAccent
        : (dimmed
              ? colors.closedText
              : (isHighlighted ? markColor : colors.textPrimary));

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          // Nudged down so the mark optically aligns with the first text
          // line at any text scale.
          padding: const EdgeInsets.only(top: 3),
          child: VariantMark(
            highlight: highlight,
            dimmed: dimmed && !onAccent,
            onAccent: onAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.name,
            style: textTheme.bodyLarge?.copyWith(
              color: textColor,
              fontWeight: (isHighlighted || onAccent)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ],
    );

    if (!isHighlighted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: row,
      );
    }

    // The tinted strip is deliberately faint: the now-serving card is still
    // the only saturated element on the screen.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: markColor.withValues(alpha: onAccent ? 0.14 : 0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: markColor, width: 3),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(9, 7, 10, 7),
        child: row,
      ),
    );
  }
}
