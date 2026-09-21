import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/context/motion.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/pressure.dart';
import 'package:server_box/view/page/server/card/shape_cross.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/widget/dist_icon.dart';

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

  /// Tall enough to read a shape in on a card, and the detail page's own
  /// `_kFocusChartHeight` at the other end — the movement ends where the page
  /// begins, so the two numbers have to be the same one.
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
  /// them — the page's own `_kColumnsWidth`.
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
}

const _tabular = [FontFeature.tabularFigures()];

/// The slot the one thing to do about a machine sits in.
///
/// Named because a line keeps it empty in the one state that has nothing to
/// offer, and an empty slot of a different width is a column that moves.
const _kLineActionWidth = 27.0;

/// How long the readings take to fill a card once the first sample lands.
///
/// The design's number, and it is the height as well as the contents: the card
/// grows out of its title over this, and what fills it comes in over the same
/// stretch — so a machine answering is one movement rather than a box growing
/// and then filling.
const _kArrive = Duration(milliseconds: 377);

/// How far apart the blocks of that come in.
///
/// Small enough that six of them are a sweep down the card rather than six
/// separate arrivals — six at 20 is 100ms, inside the 377 the whole thing
/// takes — and large enough to have a direction, which is what says the card
/// filled rather than appeared.
const _kArriveStep = Duration(milliseconds: 20);

/// How a card's rows unfold, over [_kArrive].
///
/// Slow to start, which is not only how it looks. The [AnimatedSize] around
/// the card is a frame behind the first change in its child's height whatever
/// its duration is, and draws the old height for that frame — so the bottom
/// of the card is cut off by however much the rows grew in it. On the curve
/// the card's own height eases along, which starts fast, that is over ten
/// points at 60 Hz: all of the inset under the control and some of the
/// control. On this one it is under a point.
const _kFoldCurve = Curves.easeInOutCubic;

/// A line's share of the same bar: the least it is drawn at, the width of one
/// reading's name and number after it, and the gap before each.
///
/// The bar keeps a third of what the line has for both and never less than
/// 48, which is about what three stretches of colour can still be told apart
/// in. The numbers get the rest, so they are all there from about 750 points
/// of window, and the last of them — the watched one — goes at about 310.
/// 72 for a number is "DISK 100.0%" at these sizes.
const _kLoadBarMin = 48.0;
const _kLoadValueWidth = 72.0;
const _kLoadGap = 13.0;


/// What the detail page insets its focus card by, and its rows.
///
/// Named here because they are the far end of a movement that starts inside a
/// card: the two have to be the same numbers or the page arrives shifted.
const _kFocusPad = EdgeInsets.fromLTRB(17, 13, 17, 13);

/// When the chart's scale arrives, over the movement that takes the card to
/// the page.
///
/// The second half of it, not all of it. A card two lines of text tall has
/// nowhere to put five tick labels, so for the first half there is nothing to
/// draw and the chart is held exactly as it was — which is what makes it free.
/// It lands on 1 with the movement, so the page takes over a chart already
/// drawn the way the page draws it.
const _kChartAxis = Interval(0.5, 1);

/// Over how much of the same movement a line or a tile becomes the card.
///
/// Those two are not the card at a smaller size, so they cannot be a lerp of
/// it: they are crossed with it, and the height between the two is part of the
/// cross — see [ShapeCross]. They were swapped for the card on the first frame
/// of opening and swapped back on the last frame of closing, so a line went
/// from 40 tall to the height of a card between two frames, and the grid
/// reserved that height for it and moved every line under it.
///
/// The first third, easing out. The movement's own curve starts slowly, so a
/// cross that starts fast and ends slowly adds up to a height that changes at
/// close to the pace of a card's: at most 47 points a frame against a card's
/// 39, simulated at 60 Hz for a 40-point line. Easing in and out was 98, and a
/// longer window is worse rather than better — the fast part of the cross then
/// falls on the fast part of the movement.
const _kShapeCross = Interval(0, 0.3, curve: Curves.easeOutCubic);




/// One server, as the home page draws it.
///
/// The card and the detail page are the same structure at two sizes — one
/// reading drawn in full over the rest as rows — so what is on a card is what
/// opening it shows more of, rather than a summary of something else.
///
/// [openness] is how far along that movement this card is: 0 is the card in
/// the grid, 1 is the detail. Everything between is laid out, so the card is
/// never rebuilt into something else on the way.
class ServerCard extends ConsumerWidget {
  const ServerCard({
    super.key,
    required this.srv,
    required this.promoted,
    required this.onPromote,
    required this.onToggleExpanded,
    required this.onTap,
    this.onLongPress,
    this.expanded = false,
    this.openness = 0,
    this.density = ServerListDensity.cards,
    this.selected,
    this.highlighted = false,
    this.pageWidth = 0,
    this.opensInPlace = false,
  });

  final ServerState srv;

  /// Which reading is drawn in full. Null takes the first one the machine
  /// reports, which is always the CPU.
  final ServerMetricKind? promoted;

  final ValueChanged<ServerMetricKind> onPromote;

  /// Whether the rows under the reading drawn in full are showing.
  ///
  /// Folded is what a card rests at: one reading and its window, which is the
  /// thing a machine is being watched by, and a page of cards that short is
  /// twice as many machines on screen. The rest are a press away on the line
  /// under it — see [_fold] — and which reading leads is chosen beside its
  /// name instead of by pressing a row that may not be there. See [_switch].
  ///
  /// Only at rest. On the way to the page every reading has a row, and the
  /// ones the card was not showing grow in.
  final bool expanded;

  /// The line under the readings was pressed.
  final VoidCallback onToggleExpanded;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 0 is a card in the grid, 1 the detail it becomes. See the class doc.
  final double openness;

  /// Whether this machine is one of the ones being acted on, or null when
  /// nothing is being acted on at all.
  ///
  /// Three states rather than a bool: a box beside every name when nobody is
  /// selecting anything is a column of empty boxes down a page that is not
  /// about choosing.
  final bool? selected;

  /// Whether the context menu for this server is open.
  final bool highlighted;

  /// How wide the page this card is growing into will be.
  ///
  /// Known by the grid rather than measured here for two reasons: the card's
  /// own width is whatever the movement is at, so a decision taken from it
  /// would change halfway through; and the one decision taken from it —
  /// whether the facts sit beside the readings — has to be the same answer the
  /// page gives, which it asks of this same box.
  final double pageWidth;

  /// Whether a tap opens this card in place, by growing it into the detail.
  ///
  /// Such a card draws no tap ripple. `InkResponse` confirms the ripple and
  /// stops tracking it before it calls `onTap`, so the transparent
  /// `splashColor` that [build] sets once [openness] is above 0 never reaches
  /// it: the ripple kept expanding for its 375 ms fade-out, clipped to a card
  /// that was growing to the width of the page. The pressed highlight is still
  /// drawn, because that one stays tracked and does turn transparent.
  final bool opensInPlace;

  /// How much of this machine to draw.
  ///
  /// Only while it is in the grid: a row that is being opened is on its way to
  /// being the page, and the page has one shape. The height between the two is
  /// animated rather than jumped — see the [AnimatedSize] in [build].
  final ServerListDensity density;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A line or a tile at rest, which is a shape of its own rather than the
    // card at a smaller size — see [_kShapeCross].
    final shaped = density != ServerListDensity.cards;
    final compact = shaped && openness <= 0;
    final cross = shaped ? _kShapeCross.transform(openness) : 1.0;
    final card = cardColorOf(context);
    return CardX(
      // The card's own surface goes as it becomes the page: by then each block
      // inside it is a card in its own right, which is how the page draws
      // them, and one more behind all of them would be a second edge.
      //
      // Over with in the movement's first fifth, once the blocks are in — see
      // [cardSurfaceAt]. Held any longer it is a sheet the size of the whole
      // content area by the time it fades, which is a change of background
      // rather than a card becoming a page.
      color: switch (openness) {
        > 0 => Color.lerp(Colors.transparent, card, cardSurfaceAt(openness)),
        // Keep the highlight persistent while the context menu is open.
        _ when highlighted => Theme.of(context).colorScheme.secondaryContainer,
        _ => null,
      },
      // A line and a tile are read as a set rather than one at a time, so they
      // are packed tighter and cornered less than a card: the design's 9pt
      // against a card's 13, and next to nothing between them.
      //
      // Both start from what this density rests at. They started from the
      // card's, so a line went from a margin of 1 to 4 on the first frame of
      // opening and back on the last.
      radius: shaped
          ? BorderRadius.lerp(
              const BorderRadius.all(Radius.circular(9)),
              CardX.borderRadius,
              cross,
            )
          : null,
      margin: EdgeInsets.lerp(
        switch (density) {
          ServerListDensity.rows => const EdgeInsets.symmetric(vertical: 1),
          ServerListDensity.grid => EdgeInsets.zero,
          // `Card`'s own, which is what a null margin gets.
          _ => const EdgeInsets.all(4),
        },
        EdgeInsets.zero,
        openness,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        // No ink once it is on its way to being the page.
        //
        // A highlight is painted into the surrounding `Material` across the
        // whole of what it responds to, which is this entire card, and it does
        // not go through [color] — so a card opened from under the pointer
        // grew a full-size sheet of `hoverColor` that stayed after its own
        // surface had gone. That reads as exactly what it looks like: the
        // card's background expanding into the page. It only ever happened on
        // the way in, because on the way back the pointer is on whatever was
        // pressed to get there.
        //
        // And a page is not one tap target: by the end of this the rows under
        // the pointer are the things that respond, each with ink of its own.
        hoverColor: openness > 0 ? Colors.transparent : null,
        // See [opensInPlace]: the colour below cannot reach a ripple that a
        // tap has already confirmed, so such a card starts none.
        splashFactory: opensInPlace ? NoSplash.splashFactory : null,
        splashColor: openness > 0 ? Colors.transparent : null,
        highlightColor: openness > 0 ? Colors.transparent : null,
        focusColor: openness > 0 ? Colors.transparent : null,
        // Every height this card has is a consequence of what the machine said
        // — a server connecting, a reading promoted, a row arriving — and each
        // of them used to move every card below it in the column between one
        // frame and the next.
        // Above everything that changes shape, so the clocks the readings
        // come in on and unfold by are the card's, and not whichever shape
        // drew them last.
        child: _Clocks(
          hasBody: _hasBody,
          expanded: expanded,
          duration: context.motion(_kArrive),
          builder: (context, arrival, fold) => AnimatedSize(
            // Off while the card is growing into the page, and while its rows
            // are unfolding: its height is already being animated then, by the
            // lerps inside it, and a second animation easing towards a target
            // that moves every frame lags behind it — which is the card's own
            // height arriving after everything else driven by the same
            // movement.
            // Not zero: `RenderAnimatedSize` completes a zero-length animation
            // inside its own `performLayout`, which is a render object
            // dirtying itself mid-layout.
            duration: openness > 0 || fold.isAnimating
                ? const Duration(milliseconds: 1)
                : context.motion(_kArrive),
            curve: Curves.fastEaseInToSlowEaseOut,
            alignment: Alignment.topCenter,
            child: switch (shaped) {
              _ when compact => _compact(context, ref),
              // The same structure for the whole of the movement, so the card
              // under it is one element throughout and not rebuilt from
              // nothing when the cross ends.
              true => ShapeCross(
                t: cross,
                fromHeight: _compactHeight,
                from: cross < 1 ? _compact(context, ref) : null,
                to: _full(context, ref, arrival, fold),
                minToWidth: UIs.columnWidth,
              ),
              false => _full(context, ref, arrival, fold),
            },
          ),
        ),
      ),
    );
  }

  /// How tall a line or a tile is, which is what [_line] and [_tile] size
  /// themselves to.
  double get _compactHeight => switch (density) {
    ServerListDensity.grid =>
      isMobile ? ServerCardSizes.tileTouch : ServerCardSizes.tile,
    _ => isMobile ? ServerCardSizes.rowTouch : ServerCardSizes.row,
  };

  /// Whether there are readings to draw: the machine has answered, and with
  /// a sample.
  ///
  /// One definition, because going from false to true is what [_Clocks]
  /// reads as the first sample landing — so it has to be the same question
  /// both shapes ask before drawing any.
  bool get _hasBody =>
      srv.conn == ServerConn.finished && !serverNeverSampled(srv);

  /// The card, and the readings block of the page it becomes.
  ///
  /// One tree for both, because the movement between them is a hero: the chart
  /// and the rows are the same widgets the whole way, so what travels is them
  /// and not a picture of them. Every measurement that differs between the two
  /// ends is a lerp on [openness], and at 1 this is laid out exactly as
  /// `ServerDetailPage` lays its readings out — which is what lets the page
  /// take over without anything moving.
  Widget _full(
    BuildContext context,
    WidgetRef ref,
    Animation<double> arrival,
    Animation<double> fold,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = openness;

    final err = srv.status.err;
    final auth = srv.needsInteractiveAuth;
    // Only what has been sampled is drawn. A machine that failed keeps its
    // last numbers on its own page, where there is room to say how old they
    // are; on a card the error is the more useful of the two.
    final hasBody = _hasBody;
    final stale = hasBody && err == null ? serverStaleSince(srv) : null;

    final readings = hasBody ? serverCardReadings(srv) : null;
    final focus = readings == null
        ? null
        : readings.all.firstWhereOrNull((m) => m.kind == promoted) ??
              readings.all.firstOrNull;

    // Two columns at the far end, or one. Decided from where the card is
    // going rather than from where it is, so the reservation grows evenly
    // instead of appearing the moment the card passes 800pt.
    final twoColumns = pageWidth >= ServerCardSizes.columnsWidth;

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale != null) _stale(context, stale),
        // The name goes as the page's own bar takes it: by the time the
        // readings are the page, what they are of is at the top of the window
        // with the switcher between machines beside it.
        _titleSlot(context, ref, t),
        if (err != null && !auth) _error(context, err),
        if (readings != null)
          _body(
            context,
            readings,
            focus: focus,
            theme: theme,
            scheme: scheme,
            stale: stale != null,
            twoColumns: twoColumns,
            arrival: arrival,
            fold: fold,
          ),
      ],
    );

    final reserved = twoColumns
        ? (ServerCardSizes.aside + ServerCardSizes.asideGap) * t
        : 0.0;

    return Padding(
      // At rest the card's own inset. At the end, what is left of the page's
      // once the grid's own padding and this card's margin are taken off it:
      // the blocks inside carry the rest, and the grid cannot supply it
      // without changing the width of every column.
      //
      // Plus what is kept clear for the facts, as inset rather than as an
      // empty box beside the column in a `Row`: a `Row` that is only there
      // above openness 0 is a different parent on the first frame of the
      // movement and on the last, and everything under it is unmounted and
      // built again on both.
      padding:
          EdgeInsets.lerp(
            const EdgeInsets.all(ServerCardSizes.pad),
            ServerCardSizes.openInset,
            t,
          )! +
          EdgeInsets.only(right: reserved),
      // As tall as what is in it, which with nothing to report is the title.
      // It was held to 30, from when a progress line under the title made up
      // the difference; the title is 23, so without that line the other 7 sat
      // under it as a gap with nothing in it.
      child: column,
    );
  }

  /// Everything that arrives with the first sample, coming in one block after
  /// another — see [_Arriving]. When that is, is [_Clocks]'s to say: this is
  /// mounted far more often than a machine answers.
  ///
  /// Three parts of one sweep rather than one column of it, because of the
  /// control that unfolds the rows. It is on the last line of the reading
  /// folded and under the rows unfolded, and it has to get from one to the
  /// other by travelling: it is what was just pressed, and closing where it
  /// was while another opened a card's height below read as the press having
  /// removed it. So it is one control, held to the bottom of the reading and
  /// its rows together — which is the first of those places while the rows are
  /// nothing tall, the second once they are all there, and everything between
  /// on the way. See [_rows] for what keeps a line clear under them.
  ///
  /// The foot is under all of that, and is why it is the bottom of those two
  /// and not of the card.
  Widget _body(
    BuildContext context,
    ServerCardReadings readings, {
    required ServerMetric? focus,
    required ThemeData theme,
    required ColorScheme scheme,
    required bool stale,
    required bool twoColumns,
    required Animation<double> arrival,
    required Animation<double> fold,
  }) {
    final t = openness;
    final duration = context.motion(_kArrive);
    final others = [
      for (final m in readings.all)
        if (m.kind != focus?.kind) m,
    ];
    // Laid out as unfolded for as long as any of that is showing, which is
    // longer than [expanded] says on the way back: the rows are what the
    // height being given up is the height of.
    final unfolded = expanded || fold.value > 0;
    final rows = _rows(
      context,
      readings,
      focus: focus,
      unfolded: unfolded,
      theme: theme,
      scheme: scheme,
    );
    final foot = _foot(context, readings);
    // One reading has nothing under it to fold, and the page has a row for
    // every one of them.
    final foldable = focus != null && others.isNotEmpty;
    // Which end the control is at, or was last at: it keeps the face of the
    // one it is leaving until it has arrived — see [_fold] for why.
    final atUnfolded = expanded ? fold.value >= 1 : fold.value > 0;
    // What the machine reports and the card is not drawing, at each end.
    // Counted from what is drawn rather than taken from `readings.more`, which
    // is what did not fit in the five slots: a reading promoted from outside
    // them is drawn and was still being counted.
    final unseenFolded = others.length;
    final unseenUnfolded =
        others.length -
        readings.shown.where((m) => m.kind != focus?.kind).length;
    final sweep = (focus == null ? 0 : 1) + rows.length + (foot == null ? 0 : 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          fit: StackFit.passthrough,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (focus != null)
                  _Arriving(
                    clock: arrival,
                    duration: duration,
                    of: sweep,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: lerpDouble(ServerCardSizes.gap, 0, t)!,
                        ),
                        child: _focus(
                          context,
                          focus,
                          others: others,
                          theme: theme,
                          stale: stale,
                          twoColumns: twoColumns,
                          fold: fold,
                        ),
                      ),
                    ],
                  ),
                // As tall as they have unfolded to. On the way to the page
                // that is all of it — what comes in there comes in row by
                // row — and folded it is every row the page has, at the same
                // pace, so there is nothing for this to hold back.
                SizeTransition(
                  alignment: Alignment.topCenter,
                  sizeFactor: unfolded
                      ? fold.drive(Tween(begin: t, end: 1))
                      : kAlwaysCompleteAnimation,
                  child: _Arriving(
                    clock: arrival,
                    duration: duration,
                    from: focus == null ? 0 : 1,
                    of: sweep,
                    children: rows,
                  ),
                ),
              ],
            ),
            // The rest of the line under the rows, which the control has to
            // itself: the arrow alone is a target the size of a letter, on a
            // card where a miss opens the machine. Beside the control rather
            // than the control made wider — see [_fold] — and only once it
            // has arrived, since folded this line is what the reading is of.
            //
            // There whenever the control is and deaf the rest of the time,
            // rather than there only when it listens: it is before the
            // control in this list, so its arriving would make the control
            // the third child where it had been the second, and that is the
            // control taken away and built again, with its ink.
            if (foldable && t < 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: ServerCardSizes.underLine,
                child: IgnorePointer(
                  ignoring: !(t <= 0 && expanded && atUnfolded),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: selected == null ? onToggleExpanded : onTap,
                    ),
                  ),
                ),
              ),
            if (foldable && t < 1)
              Positioned(
                right: 0,
                bottom: 0,
                child: _Arrives(
                  clock: arrival,
                  duration: duration,
                  // With what it is drawn on: the reading, or the last row.
                  at: expanded ? sweep - (foot == null ? 1 : 2) : 0,
                  of: sweep,
                  child: _fold(
                    unseenFolded: unseenFolded,
                    unseenUnfolded: unseenUnfolded,
                    atUnfolded: atUnfolded,
                    fold: fold,
                  ),
                ),
              ),
          ],
        ),
        if (foot != null)
          _Arriving(
            clock: arrival,
            duration: duration,
            from: sweep - 1,
            of: sweep,
            children: [foot],
          ),
      ],
    );
  }

  /// The box that says whether this machine is one of the ones being acted
  /// on. Nothing at all when nothing is.
  Widget? _check(BuildContext context) {
    final selected = this.selected;
    if (selected == null) return null;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: Icon(
        selected ? Icons.check_box : Icons.check_box_outline_blank,
        size: 19,
        color: selected ? scheme.primary : Colors.grey,
      ),
    );
  }

  // --- The two shapes a card takes in a longer list ---

  /// One line, or one tile.
  ///
  /// Both answer a narrower question than the card does — which machine to
  /// look at — so both are the same three things: whether it is up, what it is
  /// called, and the one reading that is being watched. Everything else is a
  /// tap away, and a list of forty is not read by reading forty of anything.
  Widget _compact(BuildContext context, WidgetRef ref) {
    final readings = _hasBody ? serverCardReadings(srv) : null;
    final focus = readings == null
        ? null
        : readings.all.firstWhereOrNull((m) => m.kind == promoted) ??
              readings.all.firstOrNull;

    // Connected, but the numbers have stopped. Both shapes say so — the tile
    // by going grey, the line by what it puts in its right column.
    final stale = readings == null ? null : serverStaleSince(srv);

    return density == ServerListDensity.grid
        ? _tile(context, readings, focus, stale: stale != null)
        : _line(context, ref, readings, focus, stale: stale);
  }

  /// Whether this machine is on its way somewhere.
  ///
  /// One definition, because a line draws from it twice and the two have to
  /// agree: the progress across its middle, and the spinner's slot at its
  /// right being left empty for it. A card says it with the spinner alone —
  /// see [_connAction], which asks the same three states.
  bool get _busy => switch (srv.conn) {
    ServerConn.connecting ||
    ServerConn.connected ||
    ServerConn.loading => true,
    _ => false,
  };

  /// Where this machine stands, for the right of a line.
  ///
  /// One column in one place, so it can be read down a list of forty rather
  /// than each row having to be looked at to find out whether it said
  /// anything. Beside it is [_connAction] — the one thing to *do* about each
  /// state, and the same mapping the card uses, so a machine offers the same
  /// control whichever shape the list is in.
  ///
  /// Empty where [_lineMiddle] is already saying it. The two have different
  /// jobs — the middle is why there is no bar, this is where the machine
  /// stands — and for two of the six they are the same sentence. The middle
  /// wins, being in the place the eye is already: the bar's.
  (String, Color) _lineState(DateTime? stale) {
    if (srv.needsInteractiveAuth) return ('', StatePalette.warn);
    return switch (srv.conn) {
      ServerConn.disconnected => ('', Colors.grey),
      ServerConn.connecting ||
      ServerConn.connected ||
      ServerConn.loading => (l10n.connecting, Colors.grey),
      ServerConn.failed => (libL10n.retry, StatePalette.failed),
      // The numbers are still the most recent thing known about it, so what
      // this says is how old they are rather than that they are gone.
      ServerConn.finished when stale != null => (
        stale.toAgoStr(),
        StatePalette.warn,
      ),
      ServerConn.finished => (srv.listLine ?? '', Colors.grey),
    };
  }

  /// A line: the state, the name, how long it has been up, what it is carrying
  /// as one bar with the numbers beside it, and what the network is doing.
  ///
  /// Every one of them the same height, whatever the machine has to say. That
  /// is the whole point of this shape — a machine that cannot be reached must
  /// not push the forty under it down — so what a failure gets is the middle
  /// of the line, where the bars would have been.
  Widget _line(
    BuildContext context,
    WidgetRef ref,
    ServerCardReadings? readings,
    ServerMetric? focus, {
    DateTime? stale,
  }) {
    final (word, wordColor) = _lineState(stale);

    return SizedBox(
      height: isMobile ? ServerCardSizes.rowTouch : ServerCardSizes.row,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: LayoutBuilder(
          builder: (_, cons) {
            // Columns are dropped from the right as the width goes, in the
            // order they are worth least: the rate first, then the numbers
            // beside the bar — which [_load] decides, having the width to
            // decide by — then how long it has been up. The name, the bar and
            // the one reading being watched never go.
            final wide = cons.maxWidth;
            return Row(
              children: [
                ?_check(context),
                Container(
                  width: ServerCardSizes.dot,
                  height: ServerCardSizes.dot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: serverStateDot(srv, readings: readings),
                  ),
                ),
                const SizedBox(width: 11),
                SizedBox(
                  width: 96,
                  child: Text(
                    srv.spi.name,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 13),
                if (focus == null)
                  // Nothing to draw a bar of, so the middle says why — in the
                  // space the bars would have taken, so the row is the same
                  // height whichever of the six it is.
                  Expanded(child: _lineMiddle(context))
                else
                  Expanded(
                    child: _load(
                      context,
                      readings,
                      focus,
                      stale: stale != null,
                    ),
                  ),
                if (wide >= 700) ...[
                  const SizedBox(width: 13),
                  SizedBox(
                    width: 96,
                    child: Text(
                      readings?.all
                              .firstWhereOrNull(
                                (m) => m.kind == ServerMetricKind.net,
                              )
                              ?.note ??
                          '',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1,
                        color: Colors.grey,
                        fontFeatures: _tabular,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                // The column that is in the same place on every row, whatever
                // the state — see [_lineState]. It is what a chevron used to
                // be, which said only that a row opens, and said it forty
                // times.
                //
                // Dropped on a phone, where the row is already giving up its
                // rate column and its second reading: what it says about a
                // machine with nothing to draw is in the middle of the line
                // anyway, and the one thing to *do* is the icon after it,
                // which never goes.
                if (wide >= 560) ...[
                  const SizedBox(width: 13),
                  SizedBox(
                    width: 88,
                    child: Text(
                      word,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1,
                        color: wordColor,
                        fontFeatures: _tabular,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(width: 3),
                // A machine on its way already has a line across the middle
                // of this row; the card's spinner here would be the same
                // answer twice. The slot is kept so the column does not move.
                if (_busy)
                  const SizedBox(width: _kLineActionWidth)
                else
                  _connAction(context, ref),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The middle of a line with nothing to draw a bar of.
  ///
  /// One of three things, and never a fourth height: a machine on its way
  /// gets the same 3pt line the card gets, one that failed gets what the far
  /// end actually said, and one nobody has connected gets the word for that.
  ///
  /// The error is the message rather than "Failure": a row is where a list of
  /// forty is scanned, and `Connection refused` against `No route to host`
  /// is the difference between a machine to look at now and one to look at
  /// later. The card under it has the raw text as well; this has one line.
  Widget _lineMiddle(BuildContext context) {
    if (_busy) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: LinearProgressIndicator(
          minHeight: ServerCardSizes.bar,
          borderRadius: BorderRadius.all(
            Radius.circular(ServerCardSizes.bar),
          ),
        ),
      );
    }

    final err = srv.status.err;
    final (text, color) = switch (srv) {
      _ when srv.needsInteractiveAuth => (libL10n.tapToAuth, StatePalette.warn),
      _ when err != null => (
        err.solution ?? err.message ?? libL10n.fail,
        StatePalette.failed,
      ),
      _ => (libL10n.disconnected, Colors.grey),
    };
    return Text(
      text,
      style: TextStyle(fontSize: 12, height: 1, color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// What a line says about load: the bar a tile draws, and beside it the
  /// numbers the bar is made of.
  ///
  /// One bar, where there were two side by side. Two bars are two readings to
  /// compare across, and a list is not scanned for that: it is scanned for
  /// which machine is carrying the most, which is one length — see
  /// [serverPressure]. A line has the width a tile has not, so the readings
  /// are named and given as numbers after the bar, each name in the colour of
  /// its stretch of it.
  ///
  /// The numbers go from the right as the width does, and the bar stays. The
  /// last number to go is the reading this machine is watched by — which need
  /// not be one the bar holds, and is then the first of them.
  Widget _load(
    BuildContext context,
    ServerCardReadings? readings,
    ServerMetric focus, {
    bool stale = false,
  }) {
    final inBar = [
      for (final kind in serverPressureKinds)
        ?readings?.all.firstWhereOrNull((m) => m.kind == kind),
    ];
    final focusInBar = inBar.any((m) => m.kind == focus.kind);

    return LayoutBuilder(
      builder: (_, cons) {
        // The watched one first, because it is the last to go.
        final ranked = [focus, ...inBar.where((m) => m.kind != focus.kind)];
        // See [_kLoadBarMin] for how the width is shared.
        final bar = math.max(_kLoadBarMin, cons.maxWidth / 3);
        // At the size the text is drawn at, which is what the width is the
        // width of: left at 72, a larger text had its numbers cut short.
        final slot = MediaQuery.textScalerOf(context).scale(_kLoadValueWidth);
        final room = ((cons.maxWidth - bar) / (slot + _kLoadGap))
            .floor()
            .clamp(0, ranked.length);
        final kept = {for (final m in ranked.take(room)) m.kind};

        return Row(
          children: [
            Expanded(
              child: PressureBar(
                segments: serverPressure(readings),
                stale: stale,
              ),
            ),
            // In the bar's own order rather than by rank, so the numbers line
            // up down a list whichever reading each machine is watched by.
            if (!focusInBar && kept.contains(focus.kind))
              _loadValue(focus, name: Colors.grey, width: slot),
            for (final m in inBar)
              if (kept.contains(m.kind))
                _loadValue(
                  m,
                  name: pressureColor(m.kind, over: m.over, stale: stale),
                  width: slot,
                ),
          ],
        );
      },
    );
  }

  /// One reading's name and number, after the bar on a line.
  ///
  /// At either end of [width], unlike the same two over the list: down forty
  /// lines they are a column of names and a column of numbers, and that is
  /// what they are read as.
  Widget _loadValue(
    ServerMetric m, {
    required Color name,
    required double width,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: _kLoadGap),
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Text(
              // Three letters of it: the number beside it is what is being
              // read, and the width is the bar's.
              m.label.length <= 4
                  ? m.label.toUpperCase()
                  : m.label.substring(0, 3).toUpperCase(),
              style: TextStyle(fontSize: 10, height: 1, color: name),
              maxLines: 1,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                m.value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11,
                  height: 1,
                  color: m.over ? StatePalette.warn : null,
                  fontFeatures: _tabular,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A tile: a state, a name and one number.
  ///
  /// What a wall of forty is for. A machine that cannot be reached keeps the
  /// tile's height and loses the bar, because a grid whose tiles are different
  /// heights is not a grid.
  Widget _tile(
    BuildContext context,
    ServerCardReadings? readings,
    ServerMetric? focus, {
    bool stale = false,
  }) {
    return SizedBox(
      height: isMobile ? ServerCardSizes.tileTouch : ServerCardSizes.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ?_check(context),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: serverStateDot(srv, readings: readings),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    srv.spi.name,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  focus?.value ?? _tileWord,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    // The one word a tile has room for is also the only thing
                    // on it that can say why: red for a machine that failed,
                    // amber for one waiting to be let in, and for a reading
                    // that is over its line.
                    color: focus == null
                        ? _tileWordColor
                        : (focus.over ? StatePalette.warn : Colors.grey),
                    fontFeatures: _tabular,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
            const SizedBox(height: 5),
            PressureBar(segments: serverPressure(readings), stale: stale),
          ],
        ),
      ),
    );
  }

  /// What a tile says where a number would be.
  ///
  /// Short, because it shares a 44pt tile with a name: "Click to verify" is
  /// what a card has room for and a tile has not, and a tile that elides its
  /// own state says less than the dash it replaced.
  String get _tileWord => switch (srv.conn) {
    ServerConn.failed =>
      srv.needsInteractiveAuth ? l10n.authShort : libL10n.fail,
    _ => '—',
  };

  Color get _tileWordColor => switch (srv.conn) {
    ServerConn.failed =>
      srv.needsInteractiveAuth ? StatePalette.warn : StatePalette.failed,
    _ => Colors.grey,
  };

  // --- The title, which every state has ---

  /// The name row, and how much of it is left.
  ///
  /// It goes as the card becomes the page: by then the window's own bar names
  /// the machine and carries the switcher to the others, and a second name
  /// under it would be the page saying what it is twice. Collapsed rather than
  /// faded alone, or the block below would arrive 23pt lower than the page
  /// puts it.
  Widget _titleSlot(BuildContext context, WidgetRef ref, double t) {
    if (t <= 0) return _title(context, ref);
    if (t >= 1) return const SizedBox.shrink();
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1 - t,
        child: Opacity(opacity: 1 - t, child: _title(context, ref)),
      ),
    );
  }

  Widget _title(BuildContext context, WidgetRef ref) {
    final line = srv.needsInteractiveAuth ? libL10n.tapToAuth : srv.listLine;

    return LayoutBuilder(
      builder: (_, cons) => Row(
        children: [
          // The name and its arrow take what is left after the line on the
          // right, and no more: in a row a text is given its intrinsic width,
          // so a long name never gets to elide — it pushes the row past the
          // card instead.
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?_check(context),
                // Before the name, at the size of it: which distribution a
                // machine runs is what a list of servers is scanned for, and
                // it reads faster as a shape than as a word. The gap goes with
                // it — marks switched off has to mean no pixels.
                ...?switch (distIcon(srv.spi.id, size: 17)) {
                  final mark? => [mark, const SizedBox(width: 7)],
                  null => null,
                },
                Flexible(
                  child: Text(
                    srv.spi.name,
                    style: const TextStyle(
                      fontSize: ServerCardSizes.name,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 17, color: Colors.grey),
              ],
            ),
          ),
          if (line != null)
            ConstrainedBox(
              // Capped because it is the unbounded one now, and its length is
              // not ours to choose: a long uptime, or whatever
              // `server_card_top_right` prints.
              constraints: BoxConstraints(
                maxWidth: cons.maxWidth.isFinite
                    ? cons.maxWidth * 0.5
                    : double.infinity,
              ),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: Colors.grey,
                  fontFeatures: _tabular,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(width: 7),
          _connAction(context, ref),
        ],
      ),
    );
  }

  /// What the right of the title offers, which is different in every
  /// connection state and is the only control a collapsed card has.
  Widget _connAction(BuildContext context, WidgetRef ref) {
    final (child, onTap) = switch (srv.conn) {
      ServerConn.connecting ||
      ServerConn.loading ||
      ServerConn.connected => (
        const SizedBox.square(dimension: 19, child: SizedLoading(19, padding: 2)),
        null,
      ),
      ServerConn.failed => (
        Icon(
          srv.needsInteractiveAuth ? Icons.lock_outline : Icons.refresh,
          size: 19,
          color: Colors.grey,
        ),
        () {
          // The user asking again *is* the new information: without this the
          // request is dropped by the backoff the previous failures installed.
          TryLimiter.reset(srv.spi.id);
          ref.read(serversProvider.notifier).refresh(spi: srv.spi);
        },
      ),
      ServerConn.disconnected => (
        const Icon(MingCute.link_3_line, size: 19, color: Colors.grey),
        () => ref.read(serversProvider.notifier).refresh(spi: srv.spi),
      ),
      ServerConn.finished => (
        const Icon(MingCute.unlink_2_line, size: 17, color: Colors.grey),
        () => ref.read(serversProvider.notifier).closeServer(id: srv.spi.id),
      ),
    };

    final wrapped = SizedBox(
      height: 23,
      width: _kLineActionWidth,
      child: Center(child: child),
    );
    if (onTap == null) return wrapped;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: wrapped,
    );
  }

  // --- The states that are not a body ---

  // Connecting is not one of them. The height does not move and the spinner
  // in [_connAction]'s slot says something is happening; a line under the
  // title as well was the same answer twice, which is what a line in the
  // list already declines to do by giving up its spinner for the one across
  // its middle.
  //
  // Not a skeleton either. A skeleton grows to the height of a success first
  // and has to shrink back when the answer is that there is nothing — which
  // is the one movement a list of cards cannot afford.

  /// What went wrong, and what was actually said.
  ///
  /// Both, because the first is this app's guess and the second is the only
  /// thing a search engine or a bug report can use.
  Widget _error(BuildContext context, Err err) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: ServerCardSizes.gap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              err.solution ?? libL10n.fail,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: StatePalette.warn,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (err.message case final message? when message.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.grey,
                  fontFamily: 'monospace',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The connection is up and the numbers have stopped.
  ///
  /// The numbers stay exactly as they were: the last reading is still the most
  /// recent thing known about the machine, and falling back to the connecting
  /// state would throw that away. What changes is that the chart goes grey and
  /// this says how old they are.
  Widget _stale(BuildContext context, DateTime at) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: ServerCardSizes.gap),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 15, color: StatePalette.warn),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              l10n.lastSampleFmt(at.toAgoStr()),
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: StatePalette.warn,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- The body ---

  /// One reading drawn in full: what it is, what it says now, and the window
  /// this app kept of it.
  ///
  /// At rest it is a block inside the card. At the far end it is a card of its
  /// own with the page's own 17/13 inset, which is the shape the detail draws
  /// — so the surface grows under the chart rather than appearing around it.
  ///
  /// The number moves as it goes: on the card it sits at the right of the
  /// label's line, and on the page it is a headline of its own underneath.
  /// Both are drawn, crossing over, and the headline's line grows from nothing
  /// — so what reads is one number travelling down and getting bigger.
  Widget _focus(
    BuildContext context,
    ServerMetric m, {
    required List<ServerMetric> others,
    required ThemeData theme,
    required bool stale,
    required bool twoColumns,
    required Animation<double> fold,
  }) {
    final t = openness;
    // With something under it to fold away. A machine that reports the one
    // reading has nothing under it either way, and is drawn as unfolded.
    final foldable = others.isNotEmpty;
    // Anything at all to plot. A reading the history does not keep has a
    // number and nothing to draw it against; the card held the chart's room
    // for it anyway, and a box with nothing in it reads as a chart that
    // failed to load. One sample is enough: [MetricChart] draws it as a
    // point, and holding out for the line would be a poll's wait on every
    // connection for a card that already has something to show.
    //
    // Only at rest. The page has a chart's room whatever is in it, so the box
    // grows from nothing on the way there rather than from a card's worth —
    // the same rule the rows that are not on the card grow in by.
    final drawn = m.samples.any((v) => v != null);
    final height = lerpDouble(
      drawn ? ServerCardSizes.chart : 0,
      twoColumns
          ? ServerCardSizes.openChart
          : ServerCardSizes.openChartNarrow,
      t,
    )!;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: t <= 0
              ? null
              : lerpDouble(ServerCardSizes.big, ServerCardSizes.openHead, t),
          child: Row(
          children: [
            Icon(m.icon, size: 18, color: ChartPalette.accent),
            const SizedBox(width: 9),
            Text(
              m.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            // The card's only. On the page every reading has a row, and
            // pressing one is how a different one is chosen there.
            if (others.isNotEmpty && t < 1)
              Opacity(opacity: 1 - t, child: _switch(others, moving: t > 0)),
            const Spacer(),
            if (t < 1)
              Opacity(
                opacity: 1 - t,
                child: Text(
                  m.value,
                  style: const TextStyle(
                    fontSize: ServerCardSizes.big,
                    height: 1,
                    fontFeatures: _tabular,
                  ),
                ),
              ),
          ],
          ),
        ),
        if (t > 0) _headline(m, t),
        if (drawn) SizedBox(height: lerpDouble(ServerCardSizes.gap, 0, t)),
        if (drawn || t > 0) _chart(m, stale: stale, height: height, t: t),
        // Under the chart on the card; on the page it is up in the head row,
        // where it arrives with the page.
        //
        // A reading that says nothing about itself still has the line while
        // it is folded, for the control that is on it — and gives it up as
        // that leaves, rather than on the frame it sets off.
        if ((m.note.isNotEmpty || foldable) && t < 1)
          SizeTransition(
            alignment: Alignment.topCenter,
            sizeFactor: m.note.isNotEmpty
                ? AlwaysStoppedAnimation(1 - t)
                : fold.drive(Tween(begin: 1 - t, end: 0)),
            child: Opacity(
              opacity: 1 - t,
              child: Padding(
                // Less than a gap by what the line has over its text, which
                // is centred in it — so the text is a gap under the chart.
                padding: const EdgeInsets.only(top: ServerCardSizes.gap - 4),
                child: _under(
                  m.note,
                  unseen: others.length,
                  fold: foldable ? fold : kAlwaysCompleteAnimation,
                ),
              ),
            ),
          ),
      ],
    );

    return _surface(context, t, child: body, padding: _kFocusPad);
  }

  /// The line under the chart: what the reading is of, and folded, the way
  /// to the rest of the readings at the end of it.
  ///
  /// Folded, this is the last line of the card, so the control is on it rather
  /// than on a line of its own under a rule — which was a third of the card's
  /// height spent on saying there is more. The note starts at the left then,
  /// because it is sharing the line and a caption centred in what is left of
  /// one is centred on nothing.
  ///
  /// Unfolded, the line is the note's alone and it is a caption again, under
  /// the middle of the chart. It travels there along [fold], as the control
  /// leaves for the line under the rows.
  ///
  /// The control itself is not in this row. It is one control in both places
  /// and is drawn over the card — see [_body] — so what is here is the room
  /// it takes while it is on this line: its own face, not drawn, closing as
  /// it goes. A width would have to be guessed, and what it says is as long
  /// as the language makes it.
  Widget _under(
    String note, {
    required int unseen,
    required Animation<double> fold,
  }) {
    return SizedBox(
      height: ServerCardSizes.underLine,
      child: Row(
        children: [
          Expanded(
            child: AlignTransition(
              alignment: fold.drive(
                AlignmentTween(
                  begin: Alignment.centerLeft,
                  end: Alignment.center,
                ),
              ),
              child: Text(
                note,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizeTransition(
            axis: Axis.horizontal,
            // Closing towards the edge of the card it sits against.
            alignment: Alignment.centerRight,
            sizeFactor: ReverseAnimation(fold),
            // Nothing once it has gone: the room is closed by then. Asked of
            // where it is going as well as where it is, because on the way
            // back this is built before the clock has moved.
            child: !expanded || fold.value < 1
                ? Visibility.maintain(
                    visible: false,
                    child: _foldFace(
                      unseen,
                      shown: kAlwaysCompleteAnimation,
                      fold: fold,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// Beside the name of the reading drawn in full: which one that is.
  ///
  /// Pressing a row is the other way, and on a card at rest there are no rows
  /// — see [expanded]. Here it does not depend on what is unfolded, and it
  /// reaches the readings the card has no slot for as well.
  ///
  /// No taller than the line it is on. That line takes the height of what is
  /// in it at rest and a stated one from the first frame of the movement, so
  /// anything taller than the number beside it is a chart that jumps by the
  /// difference on that frame.
  Widget _switch(List<ServerMetric> others, {required bool moving}) {
    return IgnorePointer(
      // On its way out, so not something to press.
      ignoring: moving,
      child: Builder(
        // The button's own box, which is what the menu hangs off.
        builder: (context) => Semantics(
          button: true,
          label: libL10n.switch_,
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            // While a set is being built up a press means "this one too",
            // wherever on the card it lands — see [_row].
            onTap: selected == null
                ? () => _pickReading(context, others)
                : onTap,
            child: const SizedBox(
              width: _kLineActionWidth,
              height: ServerCardSizes.big,
              child: Icon(Icons.unfold_more, size: 15, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  /// Raises the readings this machine has, to choose the one drawn in full.
  ///
  /// Every one but the one already there: choosing that would do nothing, and
  /// it is named an inch above the menu. What each reads now is beside its
  /// name, because that is usually the reason for picking it.
  void _pickReading(BuildContext context, List<ServerMetric> others) {
    final box = context.findRenderObject();
    // Under the button in every window, a phone's included: what it hangs off
    // is a control the size of a finger, not a card the height of the screen,
    // so there is always somewhere to put it. A sheet only when there is
    // nothing to measure.
    final at = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset(0, box.size.height))
        : null;
    showContextMenu(
      context,
      [
        for (final m in others)
          ContextMenuAction(
            icon: m.icon,
            text: m.label,
            note: m.value,
            onTap: () => onPromote(m.kind),
          ),
      ],
      title: srv.spi.name,
      at: at,
      sheet: at == null,
    );
  }

  /// The window of this reading.
  ///
  /// The page's own chart, at both ends of the movement — so there is nothing
  /// to swap when the page takes over, only a scale and a set of lines growing
  /// in beside a line that has not moved. A card the height of two lines of
  /// text cannot carry five tick labels, so at rest it has none; the gutter
  /// they sit in is a width, and the plot narrows into it rather than jumping
  /// when it appears.
  Widget _chart(
    ServerMetric m, {
    required bool stale,
    required double height,
    required double t,
  }) {
    final axis = _kChartAxis.transform(t);
    // Grey rather than the card dimmed as a whole: pressing the opacity down
    // would take the text with it, and the numbers are still worth reading.
    // What is out of date is the shape.
    final series = [
      HistorySeries(
        m.label,
        stale ? Colors.grey : ChartPalette.accent,
        m.samples,
      ),
    ];
    // The chart height must follow the parent transition so it does not freeze
    // at an intermediate value during the reverse animation.
    return SizedBox(
      height: height,
      child: Held(
      // Nothing about the chart changes over the first half of the movement:
      // the axis is not in yet and the line is the same line. Held there, the
      // box goes on growing around a chart that is laid out and painted but
      // never built — see [Held], and see [_kChartAxis] for why letting go
      // halfway is continuous.
      hold: t > 0 && axis <= 0,
      child: MetricChart(
      MetricChartSpec(
        series: series,
        format: m.format,
        times: m.times,
        // The same window the page draws live, so the line is where it was at
        // both ends of the movement — and a machine that stopped answering
        // leaves the same trailing gap at both.
        window: watchedWindow(
          m.times,
          series,
          until: stale ? DateTime.now().millisecondsSinceEpoch : null,
        ),
        binaryScale: m.binary,
        height: height,
        fill: true,
        axis: axis,
      ),
      ),
      ),
    );
  }

  /// The number on its own line, growing in under the label as the card
  /// becomes the page.
  Widget _headline(ServerMetric m, double t) {
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: t,
        child: Opacity(
          opacity: t,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  m.value,
                  style: const TextStyle(fontSize: 27, fontFeatures: _tabular),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    m.bigNote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A block that is part of the card at rest and a card of its own at the
  /// end.
  ///
  /// The surface is there from the start of the movement and the inset arrives
  /// with everything else, so what happens is a surface growing under contents
  /// that are already travelling — rather than one appearing around them at
  /// the point they stop.
  Widget _surface(
    BuildContext context,
    double t, {
    required Widget child,
    required EdgeInsets padding,
  }) {
    if (t <= 0) return child;
    return CardX(
      // In before the card's own surface starts going — see [build] and
      // [blockSurfaceAt].
      color: Color.lerp(Colors.transparent, cardColorOf(context), blockSurfaceAt(t)),
      margin: EdgeInsets.lerp(EdgeInsets.zero, const EdgeInsets.all(4), t),
      child: Padding(
        padding: EdgeInsets.lerp(EdgeInsets.zero, padding, t)!,
        child: child,
      ),
    );
  }

  /// The rest of the readings, one line each.
  ///
  /// The one being drawn above is not repeated here on the card: it is the
  /// same reading, and a row for it would be a second copy of the number at
  /// the top. On the page it comes back — there is room, and the row is where
  /// a different one is chosen from.
  ///
  /// [unfolded] is whether they are laid out as showing, which [_body] says:
  /// how much of that is showing yet is its to draw.
  List<Widget> _rows(
    BuildContext context,
    ServerCardReadings readings, {
    required ServerMetric? focus,
    required bool unfolded,
    required ThemeData theme,
    required ColorScheme scheme,
  }) {
    final t = openness;
    // On the card, the five slots minus the one drawn above — or none of
    // them, folded. On the page, every reading the machine has, including the
    // promoted one, which is where a different one is chosen from. The ones
    // the card was not showing grow in as it opens rather than appearing when
    // the page takes over, and folded that is all of them.
    final resting = unfolded
        ? [
            for (final m in readings.shown)
              if (m.kind != focus?.kind) m,
          ]
        : const <ServerMetric>[];
    final onCard = {for (final m in resting) m.kind};
    final rows = t > 0 ? readings.all : resting;
    // Folded and at rest there is nothing under the reading at all: the way
    // to the rest of them is on its last line — see [_under].
    if (rows.isEmpty) return const [];

    return [
      // From nothing when folded, where there was nothing: a gap that is
      // there at any openness above 0 and not at 0 is every card under this
      // one moving by it on the first frame of opening.
      SizedBox(
        height: lerpDouble(unfolded ? ServerCardSizes.gap : 0, 7, t),
      ),
      // One card's worth of hairline at rest, and nothing once each row is a
      // card: a line between two separate surfaces is a line about neither.
      // None folded, for the same reason as the gap.
      if (unfolded && t < 1)
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1 - t,
            child: Opacity(
              opacity: 1 - t,
              child: Padding(
                padding: const EdgeInsets.only(bottom: ServerCardSizes.gap),
                child: Divider(
                  height: Hairline.thickness,
                  thickness: Hairline.thickness,
                  color: Hairline.color(context),
                ),
              ),
            ),
          ),
        ),
      ..._spaced(
        context,
        rows,
        onCard,
        focus: focus,
        theme: theme,
        scheme: scheme,
      ),
      // A line kept clear for the way back, which is drawn over it rather
      // than in it — see [_body]. Goes as the card becomes the page, so what
      // is under it is not a line lower until the last frame.
      if (unfolded && t < 1)
        SizedBox(
          height:
              (ServerCardSizes.rowGap + ServerCardSizes.underLine) * (1 - t),
        ),
    ];
  }

  /// How many readings the card is not showing, and the way to them and back.
  ///
  /// The count and the arrow are one control. A machine reporting more than
  /// fits still says how many rather than growing taller than its neighbours:
  /// the cards are scanned down a column, and one card a line longer than the
  /// rest is what breaks that. Those are on the page, and reachable from
  /// [_switch].
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
  /// — see [_foldFace].
  ///
  /// The card's, so it goes with the card's own surface on the way to the
  /// page, which is early: by then it is held to the bottom of rows that are
  /// growing in under it.
  Widget _fold({
    required int unseenFolded,
    required int unseenUnfolded,
    required bool atUnfolded,
    required Animation<double> fold,
  }) {
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
            // While a set is being built up a press means "this one too",
            // wherever on the card it lands — see [_row].
            onTap: selected == null ? onToggleExpanded : onTap,
            child: _foldFace(
              atUnfolded ? unseenUnfolded : unseenFolded,
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

  /// What [_fold] looks like, which is also what [_under] keeps room for.
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
  Widget _foldFace(
    int unseen, {
    required Animation<double> shown,
    required Animation<double> fold,
    int incoming = 0,
    Animation<double> arriving = kAlwaysDismissedAnimation,
  }) {
    Widget count(int unseen, Animation<double> opacity) => FadeTransition(
      opacity: opacity,
      child: Text(
        '+$unseen ${libL10n.more}',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.grey,
          fontFeatures: _tabular,
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

  /// Builds [rows] with transition-aware gaps around rows not shown on cards.
  List<Widget> _spaced(
    BuildContext context,
    List<ServerMetric> rows,
    Set<ServerMetricKind> onCard, {
    required ServerMetric? focus,
    required ThemeData theme,
    required ColorScheme scheme,
  }) {
    final t = openness;
    final gap = SizedBox(height: lerpDouble(ServerCardSizes.rowGap, 0, t));
    final out = <Widget>[];
    var cardRowAbove = false;
    for (final m in rows) {
      if (onCard.contains(m.kind)) {
        if (cardRowAbove) out.add(gap);
        out.add(_row(context, m, theme: theme, scheme: scheme));
        cardRowAbove = true;
        continue;
      }
      final row = _row(
        context,
        m,
        theme: theme,
        scheme: scheme,
        promoted: m.kind == focus?.kind,
      );
      out.add(
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(
              opacity: t,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cardRowAbove ? [gap, row] : [row, gap],
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }

  Widget _row(
    BuildContext context,
    ServerMetric m, {
    required ThemeData theme,
    required ColorScheme scheme,
    bool promoted = false,
  }) {
    return MetricRow(
      icon: m.icon,
      label: m.label,
      color: ChartPalette.accent,
      value: m.value,
      note: m.note,
      percent: m.percent,
      over: m.over,
      selected: promoted,
      openness: openness,
      barMax: pageWidth,
      // While a set is being built up a tap means "this one too", wherever on
      // the card it lands: a row that promoted a reading instead would be the
      // one part of the card that did something else.
      onTap: selected == null ? () => onPromote(m.kind) : onTap,
    );
  }

  /// The one thing worth saying about this machine, or nothing.
  ///
  /// Drawn only when a reading is over the line: a footer that is always there
  /// is a line of text on every card that nobody reads, and this one has to be
  /// read the once it appears.
  Widget? _foot(BuildContext context, ServerCardReadings? readings) {
    if (readings == null) return null;
    final over = readings.all.firstWhereOrNull((m) => m.over);
    if (over == null) return null;

    return Padding(
      padding: const EdgeInsets.only(top: ServerCardSizes.rowGap),
      child: Row(
        children: [
          Container(
            width: ServerCardSizes.dot,
            height: ServerCardSizes.dot,
            decoration: const BoxDecoration(
              color: StatePalette.warn,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${over.label} ${over.value} · ${over.note}',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: StatePalette.warn,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The two movements a card has of its own, and when each of them starts.
///
/// **When its readings come in: once, as its machine first answers. Not when
/// what draws them is mounted**, which is what this used to be — [_Arriving]
/// ran its own tween from 0 wherever it was built. A card is mounted far more
/// often than a machine answers: the grid is dropped while a machine is open
/// and mounted again for the way back, a line's card is built on the first
/// frame of opening it, a tag is picked, the globe is left. Each of those
/// played the fill again, and around the opening movement that was the
/// readings going out and coming back before the card started shrinking, and
/// again once it had landed.
///
/// So the clock is here, above every shape the card takes, and what starts it
/// is [hasBody] going from false to true *between two builds of the same
/// card*. A card mounted with readings already had them, and its clock starts
/// at the end — the rule `AnimatedMasonry` follows for its own children, and
/// for the same reason: something is only new against what was already on
/// screen without it.
///
/// **And how far its rows are unfolded**, by the same rule: what moves it is
/// [expanded] changing between two builds, and a card mounted unfolded is
/// unfolded. It is a clock rather than the card's [AnimatedSize] because of
/// what that does with a taller child: lays it out at its full height at once
/// and uncovers it. Nothing under the rows travels — it is where it will end
/// up from the first frame, behind the clip — and the one thing under them is
/// the control that was just pressed. Along this the rows are as tall as they
/// have got to, and what is under them is moved by that.
class _Clocks extends StatefulWidget {
  const _Clocks({
    required this.hasBody,
    required this.expanded,
    required this.duration,
    required this.builder,
  });

  final bool hasBody;
  final bool expanded;
  final Duration duration;
  final Widget Function(
    BuildContext context,
    Animation<double> arrival,
    Animation<double> fold,
  )
  builder;

  @override
  State<_Clocks> createState() => _ClocksState();
}

class _ClocksState extends State<_Clocks> with TickerProviderStateMixin {
  late final _arrival = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.hasBody ? 1 : 0,
  );

  late final _fold = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.expanded ? 1 : 0,
  )..addStatusListener(_onFoldStatus);

  /// Built again as the fold comes to rest, because [ServerCard.build] asks
  /// whether it is moving. Its setting off needs nothing: that is
  /// [didUpdateWidget], and a build follows it.
  void _onFoldStatus(AnimationStatus status) {
    if (!status.isAnimating) setState(() {});
  }

  @override
  void didUpdateWidget(_Clocks old) {
    super.didUpdateWidget(old);
    _arrival.duration = widget.duration;
    _fold.duration = widget.duration;
    if (widget.hasBody && !old.hasBody) _arrival.forward(from: 0);
    if (widget.expanded != old.expanded) {
      _fold.animateTo(widget.expanded ? 1 : 0, curve: _kFoldCurve);
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    _fold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _arrival, _fold);
}

/// A column whose children come in one after another along [clock].
///
/// A stretch of a sweep rather than always the whole of one: [from] is where
/// in it the first of [children] is and [of] how many there are in all. What
/// comes in is not all in one column — see [ServerCard._body] — and it is
/// still one movement down the card.
class _Arriving extends StatelessWidget {
  const _Arriving({
    required this.clock,
    required this.duration,
    required this.of,
    required this.children,
    this.from = 0,
  });

  final Animation<double> clock;
  final Duration duration;
  final int from;
  final int of;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed)
          _Arrives(
            clock: clock,
            duration: duration,
            at: from + i,
            of: of,
            child: child,
          ),
      ],
    );
  }
}

/// One child's stretch of that sweep: the [at]th [of] them.
///
/// [Opacity] rather than a fade transition with a controller of its own:
/// there is one clock for the whole card, and each child reads its own stretch
/// of it. Six controllers on forty cards is forty times what this costs.
///
/// The clock is [_Clocks]'s rather than this widget's own, so being mounted
/// again is not arriving again. Once it has run, a poll rebuilds the children
/// and nothing fades.
class _Arrives extends StatelessWidget {
  const _Arrives({
    required this.clock,
    required this.duration,
    required this.at,
    required this.of,
    required this.child,
  });

  final Animation<double> clock;
  final Duration duration;
  final int at;
  final int of;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    final step = _kArriveStep.inMilliseconds;
    // The last child still has the fade's own length to run in, so the steps
    // before it share what is left rather than pushing it past the end.
    final fade = math.max(1, total - step * math.max(0, of - 1));
    final stretch = Interval(
      (at * step) / total,
      ((at * step) + fade) / total,
      curve: Curves.easeOut,
    );

    return AnimatedBuilder(
      animation: clock,
      child: child,
      builder: (_, child) =>
          Opacity(opacity: stretch.transform(clock.value), child: child),
    );
  }
}
