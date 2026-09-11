import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A horizontal scroll view that fades whichever end still has content behind
/// it.
///
/// A row that ends at its viewport's edge reads as a row that ends. Both bars
/// that float over a page — the settings tabs and a server's function buttons —
/// are as wide as what is on them until they are not, and the moment they are
/// not is exactly when nothing says so.
///
/// The mask is alpha rather than a colour. Where these are used the thing
/// behind the fade is either the page itself or the bar's own surface, and a
/// colour picked for one is wrong over the other.
///
/// The scroll view is built rather than passed, because it has to take the
/// controller this reads its position from, and a controller owned out here
/// would be one more thing for every caller to dispose.
class EdgeFadeScroll extends StatefulWidget {
  const EdgeFadeScroll({super.key, required this.builder, this.fade = 32});

  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  /// How much of an end the fade covers when a row runs off it.
  ///
  /// Wide enough that what is fading reads as something continuing, narrow
  /// enough that it is not mistaken for the row being dim.
  final double fade;

  @override
  State<EdgeFadeScroll> createState() => _EdgeFadeScrollState();
}

class _EdgeFadeScrollState extends State<EdgeFadeScroll> {
  /// Read for how much is off each end, not to scroll anything.
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // There is no position to measure until the first layout, and nothing
    // notifies when one arrives. Without this the far end of a row too wide
    // for its window is cut off square until the first drag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The fade is as wide as what is hidden, up to [EdgeFadeScroll.fade]: a row
  /// one pixel from its end is a row at its end, and a mask that ignored that
  /// would leave the last item permanently half faded.
  Shader _edgeFade(Rect rect, double before, double after) {
    final fade = widget.fade;
    final leading = (math.min(before, fade) / rect.width).clamp(0.0, 1.0);
    final trailing = math.max(
      leading,
      1 - (math.min(after, fade) / rect.width).clamp(0.0, 1.0),
    );
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Colors.transparent,
        Colors.black,
        Colors.black,
        Colors.transparent,
      ],
      stops: [0, leading, trailing, 1],
    ).createShader(rect);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt on scroll through the controller, and on a change of metrics
    // that no scroll caused — these rows grow and shrink with what is on
    // them, which is what decides whether there is anything off the end.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        return false;
      },
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.builder(context, _controller),
        builder: (context, child) {
          final position = _controller.positions.length == 1
              ? _controller.position
              : null;
          final before = position?.extentBefore ?? 0;
          final after = position?.extentAfter ?? 0;
          // Nothing off either end: no mask at all rather than one that does
          // nothing, because the mask is a `saveLayer`.
          if (before < 0.5 && after < 0.5) return child!;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => _edgeFade(rect, before, after),
            child: child,
          );
        },
      ),
    );
  }
}
