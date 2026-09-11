import 'package:flutter/material.dart';

/// Fades and lifts a timeline entry into place the first time it is shown.
///
/// A conversation grows at the bottom while the reader is looking at it, and
/// an entry that simply exists on the next frame reads as the page jumping
/// rather than as something arriving. This is most of the difference between
/// a result appearing and a result being noticed.
///
/// Played once, by a controller that stops when it finishes: there is one of
/// these per entry, and a long conversation must not be a long conversation's
/// worth of running animations.
class AgentEntryAppear extends StatefulWidget {
  const AgentEntryAppear({super.key, required this.child, this.animate = true});

  final Widget child;

  /// False for entries that were already on screen. The caller knows which
  /// those are — a rebuild is not an arrival, and replaying the animation
  /// whenever an old entry scrolls back into view is what makes a list feel
  /// cheap.
  final bool animate;

  @override
  State<AgentEntryAppear> createState() => _AgentEntryAppearState();
}

class _AgentEntryAppearState extends State<AgentEntryAppear>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Durations.medium1,
    // Already finished for anything that was here before, so the first frame
    // is the settled one rather than a flash of the entry sliding in.
    value: widget.animate ? 0 : 1,
  );

  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        // A short lift, not a slide across the page: the entry belongs where
        // it is, and only has to look like it arrived there.
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
