import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/reading_text.dart';

/// How many readings the card is not showing, and the way to them and back.
///
/// The count and the arrow are one control. A machine reporting more than
/// fits still says how many rather than growing taller than its neighbours:
/// the cards are scanned down a column, and one card a line longer than the
/// rest is what breaks that. Those are on the page, and reachable from
/// `ServerCardSwitch`.
///
/// One control in both places, which is what lets it travel between them —
/// and lets the ink of the press that sent it go with it, rather than be
/// cut off with a control that was taken away.
///
/// **Its box is the same from the press until it has arrived.** Ink is
/// placed from the top left of the box it was started in, and heads for the
/// middle of it. This was made as wide as the line on the press that
/// unfolded it, so the ripple under the finger was suddenly that far from
/// the *left* of the card, and spent the way down crossing to the middle of
/// the line. What it counts changes on the press as well, which is a
/// narrower or a wider box, and the same thing by less.
///
/// So it has the face of the end it is leaving ([atUnfolded]) the whole way,
/// and what the other end counts comes in over it without taking any room
/// — see [ServerCardFoldFace].
///
/// The card's, so it goes with the card's own surface on the way to the
/// page, which is early: by then it is held to the bottom of rows that are
/// growing in under it.
class ServerCardFold extends StatelessWidget {
  const ServerCardFold({
    super.key,
    required this.unseenFolded,
    required this.unseenUnfolded,
    required this.atUnfolded,
    required this.fold,
    required this.expanded,
    required this.openness,
    required this.onTap,
  });

  /// What the machine reports and the card is not drawing, folded.
  final int unseenFolded;

  /// The same, unfolded.
  final int unseenUnfolded;

  /// Which end the control is at, or was last at.
  final bool atUnfolded;

  /// How far the rows are unfolded.
  final Animation<double> fold;

  /// Whether the rows are to be showing — see `ServerCard.expanded`.
  final bool expanded;

  /// How far the card is on its way to the page — see `ServerCard.openness`.
  final double openness;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = openness;
    final folding = ReverseAnimation(fold);
    return IgnorePointer(
      ignoring: t > 0,
      child: Opacity(
        opacity: cardSurfaceAt(t),
        child: Semantics(
          button: true,
          label: expanded ? libL10n.fold : libL10n.more,
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: onTap,
            child: ServerCardFoldFace(
              unseen: atUnfolded ? unseenUnfolded : unseenFolded,
              shown: atUnfolded ? fold : folding,
              // Only on the way: at rest the other end's count is nowhere.
              incoming: atUnfolded == expanded
                  ? 0
                  : (atUnfolded ? unseenFolded : unseenUnfolded),
              arriving: atUnfolded ? folding : fold,
              fold: fold,
            ),
          ),
        ),
      ),
    );
  }
}

/// What [ServerCardFold] looks like, which is also what
/// `ServerCardFocus._under` keeps room for.
///
/// [unseen] is the count it is as wide as, there by as much as [shown].
/// [incoming] is the one it is on its way to saying, there by as much as
/// [arriving] and drawn over the first from a box of no width — so the two
/// cross, ending where the first ends, and the control is no wider or
/// narrower for it until it is rebuilt at the far end with that count as
/// its own.
///
/// One arrow that turns. It was two, because each of the two places this
/// was drawn only ever had it in one state and there was never a turn to
/// see; now it is one control going from one to the other, and there is.
class ServerCardFoldFace extends StatelessWidget {
  const ServerCardFoldFace({
    super.key,
    required this.unseen,
    required this.shown,
    required this.fold,
    this.incoming = 0,
    this.arriving = kAlwaysDismissedAnimation,
  });

  final int unseen;
  final Animation<double> shown;

  /// How far the rows are unfolded, which is how far the arrow has turned.
  final Animation<double> fold;

  final int incoming;
  final Animation<double> arriving;

  @override
  Widget build(BuildContext context) {
    Widget count(int unseen, Animation<double> opacity) => FadeTransition(
      opacity: opacity,
      child: Text(
        '+$unseen ${libL10n.more}',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.grey,
          fontFeatures: kTabularFigures,
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );

    return SizedBox(
      height: ServerCardSizes.underLine,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Off whatever is beside it, inside the ink so the two are one
          // target.
          const SizedBox(width: 9),
          if (unseen > 0) count(unseen, shown),
          if (incoming > 0)
            SizedBox(
              width: 0,
              child: OverflowBox(
                alignment: Alignment.centerRight,
                minWidth: 0,
                maxWidth: double.infinity,
                child: count(incoming, arriving),
              ),
            ),
          RotationTransition(
            turns: fold.drive(Tween(begin: 0, end: 0.5)),
            child: const Icon(Icons.expand_more, size: 17, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
