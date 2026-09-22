import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/overview.dart';
import 'package:server_box/view/widget/edge_fade_scroll.dart';

/// The room that strip keeps above and below itself, for both of its faces.
///
/// 12 of visible gap on each side. Above, the bar is 40 tall and its tallest
/// control, the density tabs, is about 32 centred in it: 4 of the bar's own,
/// and this adds 8. Below, the grid's 4 and a card's margin of 4 follow this
/// 4, which is also what is between two cards. It was 0 above and 9 below,
/// which drew as 4 and 17: the summary read as part of the bar, and the cards
/// as a separate block under it.
const _kStripInset = EdgeInsets.only(top: 8, bottom: 4);

/// One machine's pill in that strip, which is the design's height for it and
/// not the strip's.
const _kPillHeight = 28.0;

/// The strip between the bar and what is under it.
///
/// Two things in one place, and one question: which machine. With nothing
/// open it is what the whole list adds up to; with a machine open it is the
/// rest of the list, as pills. So they are one slot at one height, and going
/// from one to the other turns the slot over — each face through a quarter
/// turn, so the strip is edge-on halfway and there is nothing to cross
/// there. Faded past each other instead, they read as two unrelated rows
/// swapping places.
///
/// Pinned rather than scrolling with the list, which the overview used to
/// do: it shares a slot with the switcher now, and the switcher is over the
/// page rather than in it.
class ServerStrip extends StatelessWidget {
  const ServerStrip({
    super.key,
    required this.ids,
    required this.openId,
    required this.open,
    required this.onOpen,
  });

  /// The list as it is drawn: what the overview adds up, and the pills.
  final List<String> ids;

  /// The machine that is open, or null for the grid.
  final String? openId;

  /// How far the open card has grown into the page: 0 is the grid, 1 the
  /// detail. The strip turns over with it.
  final Animation<double> open;

  /// Opens the machine whose pill was tapped.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    // Both faces built once, out here: the builder below runs on every frame
    // of the movement and returns one of these two, which Flutter skips
    // rebuilding because it is the widget it already has.
    final front = RepaintBoundary(
      child: Padding(
        // Lined up with the cards: the grid's own inset plus a card's margin.
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ServerOverview(ids: ids, open: openId != null),
      ),
    );
    final back = RepaintBoundary(child: _buildSwitcher(context));

    // Around the turn rather than inside each face: one definition for both,
    // so what is below starts in the same place whichever face is up, and the
    // axis of the turn is the middle of the strip rather than of the strip
    // plus its gap.
    return Padding(
      padding: _kStripInset,
      child: AnimatedBuilder(
        animation: open,
        builder: (_, _) {
          final t = open.value;
          final facing = t < 0.5;
          // Inside the turn at rest as well, with nothing to turn by. Handed
          // back bare at 0 and at 1, a face had a different parent on the
          // frame the turn started or stopped and was built again from
          // nothing — and the pills keep a scroll position and work out their
          // faded edges a frame after they are mounted. The identity is
          // painted as an offset of zero, so it costs no layer and the text
          // in it is drawn as it would be without.
          final turning = t > 0 && t < 1;
          return Transform(
            alignment: Alignment.center,
            transform: turning
                ? (Matrix4.identity()
                    // Enough for the turn to read as one rather than as a
                    // squash, and not so much that the near edge swings out
                    // past the bar above.
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(facing ? -t * math.pi : (1 - t) * math.pi))
                : Matrix4.identity(),
            child: facing ? front : back,
          );
        },
      ),
    );
  }

  /// Which machine is on screen, and the rest of them.
  ///
  /// A row of the list that has made way, so it belongs where the list was.
  Widget _buildSwitcher(BuildContext context) {
    final openId = this.openId;
    final at = openId == null ? -1 : ids.indexOf(openId);

    // No gap of its own: [_kStripInset] is around both faces.
    return SizedBox(
      key: const ValueKey('switcher'),
      height: kServerStripHeight,
      child: EdgeFadeScroll(
        builder: (_, controller) => ListView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          // Lined up with the cards under it rather than with the window:
          // this is a row of the list, so its first pill starts where the
          // cards start. The pills carry two of their own.
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            for (final (i, id) in ids.indexed)
              _buildSwitcherPill(context, id, current: i == at),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitcherPill(
    BuildContext context,
    String id, {
    required bool current,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer(
      builder: (_, ref, _) {
        final srv = ref.watch(serverProvider(id));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Center(
            // Its own height rather than the strip's: the strip is as tall as
            // the overview it shares a slot with, and a pill stretched to that
            // is a button the size of a card.
            child: SizedBox(
              height: _kPillHeight,
              child: Material(
            color: current
                ? scheme.secondaryContainer
                : scheme.surfaceContainerHighest,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: current ? null : () => onOpen(id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: serverStateDot(srv),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      srv.spi.name,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1,
                        fontWeight: current
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: current
                            ? scheme.onSecondaryContainer
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ),
            ),
          ),
        );
      },
    );
  }
}
