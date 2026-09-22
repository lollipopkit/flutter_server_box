import 'package:flutter/widgets.dart';

/// Every measurement a server card is built from, at both of its sizes.
///
/// A card and the detail it grows into are one widget at two settings, so each
/// value that the movement changes is a pair here rather than a number at each
/// end. Anything absent from this list is the same at both sizes on purpose —
/// a name that grew as the card did would be a second thing moving.
abstract final class ServerCardSizes {
  /// Inside the card, around everything.
  static const pad = 13.0;
  static const openPad = 17.0;

  /// Between the blocks of one card: the title, the chart, the rows.
  static const gap = 9.0;
  static const openGap = 13.0;

  /// Tall enough to read a shape in on a card, and the detail page's focus
  /// chart at the other end — the movement ends where the page begins, so the
  /// page draws its chart at these same numbers rather than its own.
  ///
  /// On the page a height, not a minimum: every state of the block — a chart,
  /// one with a legend under it, a request in flight, a metric with nothing
  /// stored — is this tall, so moving between metrics does not move the rows
  /// below.
  static const chart = 44.0;
  static const openChart = 216.0;
  static const openChartNarrow = 140.0;

  /// What the detail page keeps beside the readings for the facts about the
  /// machine, and the gap before it.
  ///
  /// Reserved while the card is still growing, so the chart arrives at the
  /// width it will have rather than at the card's full width and then
  /// shrinking by a third the moment the page takes over.
  static const aside = 330.0;
  static const asideGap = 13.0;

  /// From here the detail puts the facts beside the readings rather than under
  /// them.
  ///
  /// Below it the chart would be left under 400pt, which is too narrow to read
  /// a shape in — and the facts are what can afford to wait, since they are
  /// the part of the page that does not move.
  static const columnsWidth = 800.0;

  /// What the card adds to the grid's own padding once it is the page.
  ///
  /// The page insets its readings by 13 at the sides and 4 above; the grid
  /// insets its cards by 8 and 4. This is the difference, so the two line up
  /// without the grid having to change — see the comment on the masonry's
  /// padding.
  ///
  /// The top inset is zero so detail readings align with the card's grid
  /// position. The grid supplies the remaining top padding.
  static const openInset = EdgeInsets.fromLTRB(5, 0, 5, 9);

  /// What the page with nothing to show insets its notice by, over the page's
  /// own inset.
  ///
  /// The design's 26 all round, less the 13 at the sides and 4 above that the
  /// page puts round everything — the same box the readings are laid out in,
  /// which is what a card grows into whichever page it finds. The block
  /// carries the difference, as with [openInset], so it lands at the page's
  /// 26 without the page around it changing.
  static const noticeInset = EdgeInsets.fromLTRB(13, 22, 13, 0);

  /// What the page insets its readings by at the sides: the 13 that
  /// [openInset] and the grid's own 8 add up to.
  ///
  /// What a card's content is as wide as at the far end is the page's width
  /// less twice this, and less the facts column where there is one — which
  /// is how the card knows the height of an image it does not draw. See
  /// `ServerCard._full`.
  static const pageSide = 13.0;

  /// The large image at the top of a server's page: how tall it is for the
  /// width it is given, and the air over and under it.
  ///
  /// Here because the card growing into that page has no image and keeps its
  /// room instead, so what is under the image lands where the page puts it.
  static const logoHeightRatio = 0.3;
  static const logoPad = 13.0;

  /// The line above the chart, once the readings are the page.
  ///
  /// Stated rather than natural, and honoured at both ends of the movement:
  /// the page puts a window picker and a device control up there and the card
  /// has neither, so a row that took the height of what is in it would put the
  /// chart six points lower on the page than the card had it — which is the
  /// whole page landing shifted at the moment it takes over.
  ///
  /// Also worth having on its own: what is in that row changes with the
  /// metric, and a chart that moves when a device control appears is a chart
  /// that moves for no reason anyone asked for.
  static const openHead = 30.0;

  /// The line under the chart: what the reading is of and, folded, the way to
  /// the rest of the readings beside it.
  ///
  /// Stated rather than natural, and the same folded or not. The control is
  /// taller than the text and only there folded, so a line as tall as what is
  /// in it would be one height folded and another unfolded — and the text
  /// would move down the moment the control arrived, on a press that is about
  /// what is under it.
  static const underLine = 23.0;

  static const rowGap = 7.0;

  /// What the detail page insets its focus card by, and so what the reading
  /// drawn in full grows its inset to.
  ///
  /// One value for both ends of a movement that starts inside a card: two
  /// numbers that drifted apart would land the page shifted.
  static const focusPad = EdgeInsets.fromLTRB(17, 13, 17, 13);

  /// The column the row labels line up in, which is what lets the numbers on
  /// the right of six cards be compared down a page.
  static const label = 58.0;
  static const openLabel = 84.0;

  /// One line per machine, and one tile per machine.
  ///
  /// The taller of each pair is what a finger needs; the shorter is what a
  /// pointer can hit, and the height saved is more machines on screen. Both
  /// are the design's numbers.
  static const row = 40.0;
  static const rowTouch = 48.0;
  static const tile = 44.0;
  static const tileTouch = 56.0;

  static const bar = 3.0;
  static const name = 15.0;
  static const big = 21.0;
  static const dot = 7.0;

  /// The slot the one thing to do about a machine sits in.
  ///
  /// Named because a line keeps it empty in the one state that has nothing to
  /// offer, and an empty slot of a different width is a column that moves.
  static const action = 27.0;
}
