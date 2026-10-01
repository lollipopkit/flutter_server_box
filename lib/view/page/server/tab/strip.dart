import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/server/card/overview.dart';

/// The room that strip keeps above and below itself.
///
/// 12 of visible gap on each side. Above, the bar is 40 tall and its tallest
/// control, the density tabs, is about 32 centred in it: 4 of the bar's own,
/// and this adds 8. Below, the grid's 4 and a card's margin of 4 follow this
/// 4, which is also what is between two cards. It was 0 above and 9 below,
/// which drew as 4 and 17: the summary read as part of the bar, and the cards
/// as a separate block under it.
const _kStripInset = EdgeInsets.only(top: 8, bottom: 4);

/// What the whole list adds up to, between the bar and the list.
///
/// Folds up as a machine opens and unfolds as it closes, on the same movement
/// as the card: the machine has the page then, and the rest of the list is the
/// column beside it, so a summary of the list has nothing left to be over. It
/// takes its gap with it, so the page starts where the bar ends.
///
/// Pinned rather than scrolling with the list, which the overview used to do:
/// it is part of the page's head, and the list scrolls under it.
class ServerStrip extends StatelessWidget {
  const ServerStrip({
    super.key,
    required this.ids,
    required this.openId,
    required this.open,
  });

  /// The list as it is drawn: what the overview adds up.
  final List<String> ids;

  /// The machine that is open, or null for the grid.
  final String? openId;

  /// How far the open card has grown into the page: 0 is the grid, 1 the
  /// detail. The strip folds up with it.
  final Animation<double> open;

  @override
  Widget build(BuildContext context) {
    final shown = ReverseAnimation(open);
    final strip = SizeTransition(
      // Folds towards the bar it hangs from, so its bottom edge is what moves
      // and the list under it rides up with that edge.
      alignment: Alignment.topCenter,
      sizeFactor: shown,
      child: FadeTransition(
        opacity: shown,
        child: Padding(
          padding: _kStripInset,
          child: RepaintBoundary(
            child: Padding(
              // Lined up with the cards: the grid's own inset plus a card's
              // margin.
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ServerOverview(ids: ids, open: openId != null),
            ),
          ),
        ),
      ),
    );
    // Not built at all once folded: a strip of no height is still a poll's
    // worth of rebuilding, and its words are still found by anything asking
    // what the page says.
    return AnimatedBuilder(
      animation: open,
      child: strip,
      builder: (_, child) => open.value < 1 ? child! : const SizedBox.shrink(),
    );
  }
}
