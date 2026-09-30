import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// The chart a card draws in full, carried to the one at the top of the
/// detail page when opening the card pushes a page.
///
/// On the same terms as [ServerNameHero]: only on a push, since a card that
/// grows into the page is already that movement and shares its route with the
/// page; and not with less motion asked for. Both ends draw the reading the
/// card has promoted, which the page opens on.
class ServerChartHero extends StatelessWidget {
  const ServerChartHero({
    super.key,
    required this.id,
    required this.enabled,
    required this.child,
  });

  final String id;
  final bool enabled;
  final Widget child;

  static Object tagOf(String id) => 'server_chart_$id';

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

  /// The two charts crossfading, each laid out at the size it has at its own
  /// end and stretched into the box the flight is at.
  ///
  /// Laid out in the flight's box instead, a chart would be laid out afresh
  /// on every frame — its axis labels re-spaced and its line re-plotted at
  /// each height — and the card's is a third of the page's height.
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
    Widget side(BuildContext of, Animation<double> opacity) {
      final child = (of.widget as Hero).child;
      final size = switch (of.findRenderObject()) {
        final RenderBox box when box.hasSize => box.size,
        _ => null,
      };
      return FadeTransition(
        opacity: opacity,
        child: size == null
            ? child
            : FittedBox(
                fit: BoxFit.fill,
                child: SizedBox.fromSize(size: size, child: child),
              ),
      );
    }

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
