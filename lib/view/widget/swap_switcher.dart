import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// One thing in a place replaced by another: the outgoing fades, the arriving
/// fades in growing from 0.9 about the centre (the design system's
/// `--transition-swap`). No direction is drawn: which comes next is picked
/// from a list, not stepped through.
///
/// [child] must be keyed by what it shows, or nothing crosses.
class SwapSwitcher extends StatelessWidget {
  const SwapSwitcher({super.key, required this.child});

  final Widget child;

  /// `medium2`, as the server page's list ⇄ globe swap is: a scale needs room
  /// to read as a movement, and at 150 ms it has arrived before the eye has
  /// decided anything moved.
  static const duration = Durations.medium2;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(duration),
      reverseDuration: context.motion(duration),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: _transition,
      layoutBuilder: _layout,
      child: child,
    );
  }

  static Widget _transition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      // `drive` rather than a `CurvedAnimation`, which owns resources and
      // would be built and dropped on every frame of the transition.
      child: ScaleTransition(
        scale: animation.drive(Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic))),
        child: child,
      ),
    );
  }

  static Widget _layout(Widget? current, List<Widget> previous) =>
      Stack(fit: StackFit.expand, children: [...previous, ?current]);
}
