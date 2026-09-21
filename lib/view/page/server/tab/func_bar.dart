import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

/// The row of things that can be done to the open machine.
///
/// The tab's rather than the page's, so that stepping to another machine
/// leaves it where it is. The page slides — that is what says which way
/// through the list the step went — and a row of the same buttons sliding
/// with it is the one part of that movement that says nothing at all. What
/// does differ between two machines changes in place, a slot at a time; see
/// [ServerFuncBtns].
class ServerOpenFuncBar extends ConsumerWidget {
  const ServerOpenFuncBar({
    super.key,
    required this.id,
    required this.open,
    required this.visible,
  });

  /// The machine that is open.
  final String id;

  /// How far the open card has grown into the page: 0 is the grid, 1 the
  /// detail. The row rises and sinks with it.
  final Animation<double> open;

  /// Whether the row is wanted, which is the page under it not being read
  /// past.
  final ValueListenable<bool> visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final si = ref.watch(serverProvider(id));
    final (entries: btns, any: any) = serverDetailFuncBtns(si);
    // A machine with nothing to show yet keeps the row, greyed: the
    // entries have not gone away, there is simply no connection to do any
    // of them through, and the positions are worth keeping. A machine that
    // is reachable and can serve none of them has no row — what belongs in
    // its place is the page's own explanation.
    final show = serverDetailHasContent(si) ? any : btns.isNotEmpty;
    if (!show) return const SizedBox.shrink();
    // Rises with the card and sinks with it, rather than arriving on its
    // own once the movement is over and vanishing when it starts back.
    // That leaves [HideOnScroll] doing only what it is for — getting out
    // of the way of a page being read past — so its own arrival is off.
    return AnimatedBuilder(
      animation: open,
      child: RepaintBoundary(
        child: HideOnScroll.driven(
          visible: visible,
          enterDelay: Duration.zero,
          enterDuration: Duration.zero,
          child: ServerFuncBar(spi: si.spi, btns: btns),
        ),
      ),
      builder: (_, child) {
        final t = open.value;
        // The same two layers at rest as on the way, rather than the row
        // handed back bare once the card has stopped. That was a
        // different parent at 1 from the one at anything less, so the row
        // was unmounted and built again on the last frame of the way in
        // and the first of the way back — and [HideOnScroll] spends the
        // first frames after it is mounted off the edge it sits on, so
        // the row went out just as the card started to shrink. At 1 both
        // cost nothing: full opacity paints the child directly, and a
        // translation by zero is an offset.
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * kFuncBarHeight * 0.5),
            child: child,
          ),
        );
      },
    );
  }
}
