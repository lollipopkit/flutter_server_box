import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// A server's name, carried from its card to the detail page's bar when
/// opening the card pushes a page.
///
/// Only then: where the card grows into the page instead, card and page are
/// one route, and two heroes of one tag in a route is an assertion the next
/// time anything is pushed from it. So each side says whether it is a side of
/// a push — the card when it does not open in place, the page when it is not
/// hosted inside the tab.
///
/// Nor with less motion asked for: a name flying across the screen is the
/// thing that asks for, and the page's own fade carries the change without it.
class ServerNameHero extends StatelessWidget {
  const ServerNameHero({
    super.key,
    required this.id,
    required this.enabled,
    required this.child,
  });

  final String id;
  final bool enabled;
  final Widget child;

  static Object tagOf(String id) => 'server_name_$id';

  @override
  Widget build(BuildContext context) {
    if (!enabled || context.reduceMotion) return child;
    return Hero(
      tag: tagOf(id),
      transitionOnUserGestures: true,
      flightShuttleBuilder: _shuttle,
      child: child,
    );
  }

  /// The two names crossfading, each scaled into the box the flight is at.
  ///
  /// The card's is 15pt and the bar's 20, in boxes of their own widths: the
  /// default shuttle lays the destination's text out in every box between,
  /// which reflows and ellipsizes it frame by frame. Scaled, a name is one
  /// shape growing. Each keeps the text style it had where it came from — the
  /// flight is drawn in the overlay, which has none.
  static Widget _shuttle(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    // Towards the page on a push; a pop runs the same route's animation back.
    final toward = direction == HeroFlightDirection.push
        ? animation
        : ReverseAnimation(animation);
    Widget side(BuildContext of, Animation<double> opacity) => FadeTransition(
      opacity: opacity,
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(of).style,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: (of.widget as Hero).child,
          ),
        ),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          side(fromContext, ReverseAnimation(toward)),
          side(toContext, toward),
        ],
      ),
    );
  }
}
