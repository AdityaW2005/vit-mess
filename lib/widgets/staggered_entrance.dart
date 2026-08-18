import 'package:flutter/material.dart';

/// Fades and slides its children in, one shortly after the next.
///
/// Owns a single [AnimationController] and gives each child an [Interval] on
/// it, which is far cheaper than a controller per row. The whole sequence is
/// capped so a thirteen-item meal does not take longer to appear than a
/// three-item one.
///
/// Honours the platform's reduce-motion setting: when animations are
/// disabled, children are placed immediately with no transition.
class StaggeredEntrance extends StatefulWidget {
  /// Creates a staggered entrance around [children].
  const StaggeredEntrance({
    required this.children,
    super.key,
    this.stagger = const Duration(milliseconds: 40),
    this.itemDuration = const Duration(milliseconds: 260),
    this.slideOffset = 12,
  });

  /// The widgets to reveal, in order.
  final List<Widget> children;

  /// Delay between consecutive children.
  final Duration stagger;

  /// How long a single child takes to arrive.
  final Duration itemDuration;

  /// How far, in logical pixels, a child slides up as it fades in.
  final double slideOffset;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _totalDuration,
  );

  /// Nothing may run longer than 300ms, so the stagger is compressed rather
  /// than allowed to grow with the list.
  static const Duration _maxTotal = Duration(milliseconds: 300);

  Duration get _totalDuration {
    final naive =
        widget.itemDuration + widget.stagger * (widget.children.length - 1);
    return naive > _maxTotal ? _maxTotal : naive;
  }

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(StaggeredEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different list — a new day, or a switched tier — replays the entrance.
    if (oldWidget.children.length != widget.children.length) {
      _controller
        ..duration = _totalDuration
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || widget.children.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.children,
      );
    }

    final count = widget.children.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          _StaggeredChild(
            controller: _controller,
            interval: _intervalFor(i, count),
            slideOffset: widget.slideOffset,
            child: widget.children[i],
          ),
      ],
    );
  }

  Interval _intervalFor(int index, int count) {
    if (count <= 1) return const Interval(0, 1, curve: Curves.easeOutCubic);
    // Each child occupies the same slice; slices overlap so the sequence reads
    // as one motion rather than a queue.
    const span = 0.55;
    final step = (1.0 - span) / (count - 1);
    final begin = (index * step).clamp(0.0, 1.0 - span);
    return Interval(begin, begin + span, curve: Curves.easeOutCubic);
  }
}

class _StaggeredChild extends StatelessWidget {
  const _StaggeredChild({
    required this.controller,
    required this.interval,
    required this.slideOffset,
    required this.child,
  });

  final AnimationController controller;
  final Interval interval;
  final double slideOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(parent: controller, curve: interval);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * slideOffset),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}
