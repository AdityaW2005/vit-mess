import 'package:flutter/material.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_typography.dart';

/// Renders a countdown with per-character transitions.
///
/// Purely presentational: the ticking itself lives in `HomeViewModel`, which
/// owns the `Timer.periodic`. This widget only animates between the values it
/// is handed, so there is no timer here to leak.
class CountdownTimer extends StatelessWidget {
  /// Creates a countdown display.
  const CountdownTimer({
    required this.remaining,
    required this.color,
    super.key,
    this.compact = false,
  });

  /// Time left to display.
  final Duration remaining;

  /// Colour of the numerals.
  final Color color;

  /// Uses the smaller scale, for the "up next" state.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = compact
        ? AppTypography.countdownCompact(color)
        : AppTypography.countdown(color);
    final text = Strings.formatCountdown(remaining);
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          for (var i = 0; i < text.length; i++)
            _CountdownGlyph(
              // Keying on position keeps each slot stable, so only the glyphs
              // that actually changed animate.
              key: ValueKey<int>(i),
              character: text[i],
              style: style,
              animate: animate,
            ),
        ],
      ),
    );
  }
}

class _CountdownGlyph extends StatelessWidget {
  const _CountdownGlyph({
    required this.character,
    required this.style,
    required this.animate,
    super.key,
  });

  final String character;
  final TextStyle style;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final glyph = Text(character, key: ValueKey<String>(character), style: style);

    if (!animate) return glyph;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: <Widget>[...previousChildren, ?currentChild],
      ),
      child: glyph,
    );
  }
}
