import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// Shared-element [Hero] shuttle reused across Status tab card types (Server
/// name/chart, BMC status, Uptimer heartbeat strip) when opening pushes a
/// separate route on narrow layouts.
///
/// Both ends are laid out at their own resting sizes and crossfaded via
/// [FadeTransition] inside a [FittedBox] + [RepaintBoundary] so neither side
/// reflows or repaints frame-by-frame during flight.
final class SharedElementHero extends StatelessWidget {
  final Object tag;
  final bool enabled;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final bool preserveTextStyle;
  final Widget child;

  const SharedElementHero({
    super.key,
    required this.tag,
    required this.enabled,
    required this.child,
    this.fit = BoxFit.fill,
    this.alignment = Alignment.center,
    this.preserveTextStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || context.reduceMotion) return child;
    return Hero(
      tag: tag,
      transitionOnUserGestures: true,
      flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) => _shuttle(
        animation: anim,
        direction: dir,
        fromContext: fromCtx,
        toContext: toCtx,
        fit: fit,
        alignment: alignment,
        preserveTextStyle: preserveTextStyle,
      ),
      child: child,
    );
  }

  static Widget _shuttle({
    required Animation<double> animation,
    required HeroFlightDirection direction,
    required BuildContext fromContext,
    required BuildContext toContext,
    required BoxFit fit,
    required AlignmentGeometry alignment,
    required bool preserveTextStyle,
  }) {
    final toward = direction == HeroFlightDirection.push
        ? animation
        : ReverseAnimation(animation);

    Widget side(BuildContext of, Animation<double> opacity) {
      final rawChild = (of.widget as Hero).child;
      final size = switch (of.findRenderObject()) {
        final RenderBox box when box.hasSize => box.size,
        _ => null,
      };
      // If a non-text child has not been laid out yet, skip FittedBox so
      // flex-based widgets (e.g. heartbeat strips, charts) never receive
      // unbounded constraints.
      if (!preserveTextStyle && size == null) {
        return FadeTransition(
          opacity: opacity,
          child: RepaintBoundary(child: rawChild),
        );
      }
      final content = preserveTextStyle
          ? rawChild
          : SizedBox.fromSize(size: size, child: rawChild);
      Widget fitted = FittedBox(
        fit: fit,
        alignment: alignment,
        child: content,
      );
      if (preserveTextStyle) {
        fitted = DefaultTextStyle(
          style: DefaultTextStyle.of(of).style,
          child: Align(alignment: alignment, child: fitted),
        );
      }
      return FadeTransition(
        opacity: opacity,
        child: RepaintBoundary(child: fitted),
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
