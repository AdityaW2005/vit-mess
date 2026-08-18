import 'package:flutter/material.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/date_utils.dart';
import 'countdown_timer.dart';
import 'meal_card.dart';

/// The hero card: what is being served, and how long is left.
///
/// This is the only saturated element on the screen. When a meal is open it
/// carries the saffron gradient; between meals it drops to a neutral surface
/// with an accent rule, so "open" and "not open" are distinguishable from
/// across the room.
class NowServingCard extends StatelessWidget {
  /// Creates the hero card.
  const NowServingCard({
    required this.focus,
    required this.remaining,
    required this.now,
    super.key,
  });

  /// The meal to lead with: serving now, or the next to open.
  final MealFocus focus;

  /// Time until the meal closes (when serving) or opens (when upcoming).
  final Duration remaining;

  /// The instant the ViewModel last observed.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;
    final serving = focus.isServingNow;

    final foreground = serving ? colors.onAccent : colors.textPrimary;
    final subdued = serving
        ? colors.onAccent.withValues(alpha: 0.78)
        : colors.textSecondary;

    final dayOffset = focus.daysFrom(now);
    final eyebrow = serving
        ? Strings.homeNowServing
        : '${Strings.homeUpNext}  ·  ${Strings.relativeDay(dayOffset)}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius + 6),
        border: serving ? null : Border.all(color: colors.hairline),
        color: serving ? null : colors.surface,
        gradient: serving
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[colors.heroGradientStart, colors.heroGradientEnd],
              )
            : null,
        boxShadow: serving
            ? <BoxShadow>[
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.28),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow.toUpperCase(),
            style: AppTypography.eyebrow(subdued),
          ),
          const SizedBox(height: 10),

          // Meal name and serving window.
          Text(
            Strings.mealName(focus.meal.type),
            style: textTheme.displaySmall?.copyWith(color: foreground),
          ),
          const SizedBox(height: 4),
          Text(
            Strings.formatWindow(focus.meal.startTime, focus.meal.endTime),
            style: textTheme.bodyMedium?.copyWith(color: subdued),
          ),

          const SizedBox(height: 18),

          // The countdown — the largest thing on the screen.
          Text(
            serving ? Strings.homeClosesIn : Strings.homeStartsIn,
            style: AppTypography.eyebrow(subdued),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountdownTimer(
              remaining: remaining,
              color: foreground,
              compact: !serving,
            ),
          ),

          const SizedBox(height: 18),
          Divider(
            color: serving
                ? colors.onAccent.withValues(alpha: 0.24)
                : colors.hairline,
            height: 1,
          ),
          const SizedBox(height: 8),

          // The full item list, so the answer needs no further taps.
          MealItemsList(items: focus.meal.items, onAccent: serving),
        ],
      ),
    );
  }
}
