import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/motion.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/view/widget/dist_icon.dart';

/// How long a card takes to turn over, and the design's number for it.
const _kFlipDuration = Duration(milliseconds: 377);

/// How much of the card's height a menu may take before it scrolls.
///
/// A card grows to fit its menu — that is what makes the turn read as one
/// object rather than as a panel appearing — but a machine that can be reached
/// six ways has a menu twice the height of the card it is on, and a column
/// that tall in a grid of short ones is a hole the rest of the page falls
/// into.
const _kMenuMaxHeight = 360.0;

/// A card and its other side, turned between.
///
/// A card is big enough to hold what can be done to the machine it is of, so a
/// long press turns it over rather than covering it: the actions arrive where
/// the machine is rather than where the finger was, and nothing else on the
/// page moves to make room. Half a turn about the vertical, with each face
/// drawn for the half of it that faces the reader, so there is nothing to
/// cross at the midpoint.
class CardFlip extends StatefulWidget {
  const CardFlip({
    super.key,
    required this.flipped,
    required this.front,
    required this.back,
  });

  final bool flipped;
  final Widget front;
  final Widget back;

  @override
  State<CardFlip> createState() => _CardFlipState();
}

class _CardFlipState extends State<CardFlip>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: _kFlipDuration,
    value: widget.flipped ? 1 : 0,
  );
  late final _curve = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.fastEaseInToSlowEaseOut,
    reverseCurve: Curves.fastEaseInToSlowEaseOut,
  );

  @override
  void didUpdateWidget(CardFlip old) {
    super.didUpdateWidget(old);
    if (old.flipped == widget.flipped) return;
    _ctrl.duration = context.motion(_kFlipDuration);
    widget.flipped ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      // The two faces are different heights and the card is one object, so the
      // height goes with the turn. It starts at the midpoint, which is where
      // the face changes, and runs on a little past the end of the turn.
      duration: context.motion(_kFlipDuration),
      curve: Curves.fastEaseInToSlowEaseOut,
      alignment: Alignment.topCenter,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (_, _) {
          final t = _curve.value;
          if (t <= 0) return widget.front;
          if (t >= 1) return widget.back;
          final facing = t < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              // Enough for the turn to read as one rather than as a squash,
              // and not so much that the near edge swings over its neighbour.
              ..setEntry(3, 2, 0.0015)
              ..rotateY(facing ? t * math.pi : (t - 1) * math.pi),
            child: facing ? widget.front : widget.back,
          );
        },
      ),
    );
  }
}

/// The other side of a card: what can be done to the machine it is of.
///
/// The same set in the same order as every other way of asking for it — see
/// `serverActions`. What this shape adds is the room for each entry to say
/// what it is *of*: the address that would be copied, the session that would
/// be opened. A menu over a pointer has no such room and does not try.
class ServerCardMenu extends StatelessWidget {
  const ServerCardMenu({
    super.key,
    required this.spi,
    required this.actions,
    required this.onClose,
  });

  final Spi spi;
  final List<ContextMenuAction> actions;

  /// Turning the card back over, which is also what a tap anywhere else does.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CardX(
      // A step above the card's own surface: the back of a card is not the
      // page, and at the same colour the turn ends on something that looks
      // like the card it started from.
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _head(context),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _kMenuMaxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final action in actions) _row(context, action),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Which machine this is the other side of, and the way back to it.
  Widget _head(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          ...?switch (distIcon(spi.id, size: 15)) {
            final mark? => [mark, const SizedBox(width: 7)],
            null => null,
          },
          Flexible(
            child: Text(
              spi.name,
              style: const TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(9),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.flip_to_front, size: 17, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ContextMenuAction action) {
    final color = action.destructive ? UIs.textRed.color : null;
    return InkWell(
      onTap: () {
        // Turned back first: an action that opens a dialog or a page of its
        // own would otherwise leave the card face down behind it.
        onClose();
        action.onTap();
      },
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
        child: Row(
          children: [
            Icon(action.icon, size: 18, color: color ?? Colors.grey),
            const SizedBox(width: 11),
            Flexible(
              child: Text(
                action.text,
                style: TextStyle(fontSize: 13, height: 1.2, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            if (action.note case final note?) ...[
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  note,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
