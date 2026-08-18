import 'package:flutter/material.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/date_utils.dart';
import '../models/menu_day.dart';

/// The horizontal date selector above the week view.
///
/// Today is visually anchored with an accent ring so it stays findable after
/// scrolling, and the strip keeps the selection centred as it changes.
class DayStrip extends StatefulWidget {
  /// Creates a strip over [days].
  const DayStrip({
    required this.days,
    required this.selectedIndex,
    required this.todayIndex,
    required this.onSelected,
    super.key,
  });

  /// Every day in the document, ascending.
  final List<MenuDay> days;

  /// Index of the selected day.
  final int selectedIndex;

  /// Index of today, or `-1` when the month does not cover it.
  final int todayIndex;

  /// Called when a cell is tapped.
  final ValueChanged<int> onSelected;

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  final ScrollController _controller = ScrollController();

  static const double _cellWidth = 60;
  static const double _cellSpacing = 8;
  static const double _stripHeight = 78;

  @override
  void initState() {
    super.initState();
    // The initial scroll has to wait for the viewport to exist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centreOn(widget.selectedIndex, animate: false);
    });
  }

  @override
  void didUpdateWidget(DayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _centreOn(widget.selectedIndex, animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls so the cell at [index] sits near the middle of the viewport.
  void _centreOn(int index, {required bool animate}) {
    if (!_controller.hasClients || index < 0) return;

    final viewport = _controller.position.viewportDimension;
    final target =
        (index * (_cellWidth + _cellSpacing)) - (viewport / 2) + (_cellWidth / 2);
    final clamped = target.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );

    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(clamped);
      return;
    }
    _controller.animateTo(
      clamped,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _stripHeight,
    child: ListView.separated(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: AppTheme.pagePadding,
      itemCount: widget.days.length,
      separatorBuilder: (context, index) =>
          const SizedBox(width: _cellSpacing),
      itemBuilder: (context, index) => _DayCell(
        day: widget.days[index],
        selected: index == widget.selectedIndex,
        isToday: index == widget.todayIndex,
        width: _cellWidth,
        onTap: () => widget.onSelected(index),
      ),
    ),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.width,
    required this.onTap,
  });

  final MenuDay day;
  final bool selected;
  final bool isToday;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final background = selected ? colors.accent : colors.surface;
    final foreground = selected ? colors.onAccent : colors.textPrimary;
    final labelColor = selected
        ? colors.onAccent.withValues(alpha: 0.8)
        : colors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: '${Strings.a11ySelectDay}: ${Strings.formatDayHeading(day.date)}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: width,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.chipRadius + 2),
          border: Border.all(
            color: isToday && !selected ? colors.accent : colors.hairline,
            width: isToday && !selected ? 1.6 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.chipRadius + 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  day.weekday.toUpperCase(),
                  style: AppTypography.eyebrow(labelColor),
                ),
                const SizedBox(height: 6),
                Text(
                  day.date.day.toString(),
                  style: AppTypography.dayStripNumber(
                    foreground,
                    selected: selected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact heading showing which date the body is displaying.
class DayStripHeading extends StatelessWidget {
  /// Creates a heading for [date].
  const DayStripHeading({required this.date, required this.now, super.key});

  /// The date being shown.
  final DateTime date;

  /// The current instant, used for the "Today"/"Tomorrow" label.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;
    final offset = daysBetween(now, date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          Strings.formatDayHeading(date),
          style: textTheme.titleLarge?.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(width: 10),
        if (offset >= 0 && offset <= 1)
          Text(
            Strings.relativeDay(offset).toUpperCase(),
            style: AppTypography.eyebrow(colors.accent),
          ),
      ],
    );
  }
}
