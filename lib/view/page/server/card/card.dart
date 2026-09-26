import 'dart:ui' show lerpDouble;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/motion.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/arrival.dart';
import 'package:server_box/view/page/server/card/compact.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/focus.dart';
import 'package:server_box/view/page/server/card/fold.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/notices.dart';
import 'package:server_box/view/page/server/card/shape_cross.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/card/title.dart';
import 'package:server_box/view/page/server/metric_row.dart';

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
class ServerCard extends StatelessWidget {
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
  /// under it — see [ServerCardFold] — and which reading leads is chosen
  /// beside its name instead of by pressing a row that may not be there. See
  /// [ServerCardSwitch].
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
  Widget build(BuildContext context) {
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
        child: ServerCardClocks(
          hasBody: _hasBody,
          expanded: expanded,
          duration: context.motion(kServerCardArrive),
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
                : context.motion(kServerCardArrive),
            curve: Curves.fastEaseInToSlowEaseOut,
            alignment: Alignment.topCenter,
            child: switch (shaped) {
              _ when compact => _compact(),
              // The same structure for the whole of the movement, so the card
              // under it is one element throughout and not rebuilt from
              // nothing when the cross ends.
              true => ShapeCross(
                t: cross,
                fromHeight: _compactHeight,
                from: cross < 1 ? _compact() : null,
                to: _full(context, arrival, fold),
                minToWidth: UIs.columnWidth,
              ),
              false => _full(context, arrival, fold),
            },
          ),
        ),
      ),
    );
  }

  /// How tall a line or a tile is, which is what [ServerCardLine] and
  /// [ServerCardTile] size themselves to.
  double get _compactHeight => switch (density) {
    ServerListDensity.grid =>
      isMobile ? ServerCardSizes.tileTouch : ServerCardSizes.tile,
    _ => isMobile ? ServerCardSizes.rowTouch : ServerCardSizes.row,
  };

  /// Whether there are readings to draw — see [serverCardHasBody].
  ///
  /// One definition, because going from false to true is what
  /// [ServerCardClocks] reads as the first sample landing — so it has to be
  /// the same question both shapes ask before drawing any.
  bool get _hasBody => serverCardHasBody(srv);

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
    Animation<double> arrival,
    Animation<double> fold,
  ) {
    final t = openness;

    // What the card says about a machine with nothing to show, and which of
    // the page's two shapes it is on its way to — see [ServerNoticeForm].
    // Decided from where the card is going, like [twoColumns] below.
    final notice = ServerNotice.onCard(srv);
    final hasContent = serverDetailHasContent(srv);
    // Only what has been sampled is drawn. A machine that failed keeps its
    // last numbers on its own page, where there is room to say how old they
    // are; on a card the error is the more useful of the two.
    final hasBody = _hasBody;
    final stale = serverCardStaleSince(srv);

    final readings = hasBody ? serverCardReadings(srv) : null;
    final focus = readings == null
        ? null
        : readings.all.firstWhereOrNull((m) => m.kind == promoted) ??
              readings.all.firstOrNull;

    // Two columns at the far end, or one. Decided from where the card is
    // going rather than from where it is, so the reservation grows evenly
    // instead of appearing the moment the card passes 800pt.
    final twoColumns = pageWidth >= ServerCardSizes.columnsWidth;
    // Only a page with readings has the facts beside them: a machine with
    // nothing to show is one notice across the whole width.
    final asideAtEnd = twoColumns && hasContent
        ? ServerCardSizes.aside + ServerCardSizes.asideGap
        : 0.0;

    // The page's image, which the card has not: its room is kept from the
    // first frame, growing with the card, so what is under it lands where
    // the page puts it rather than a picture's height too high. The image
    // itself comes in with the page — see `ServerDetailPage._buildLogo`. Its
    // height is a share of the width the page lays it out at, which is this
    // card's at the far end. A box of no height at rest rather than none, so
    // the blocks under it are the same children of the same column on every
    // frame.
    final logoRoom = t > 0 && hasContent && srv.getLogoUrl(context) != null
        ? ((pageWidth - 2 * ServerCardSizes.pageSide - asideAtEnd) *
                  ServerCardSizes.logoHeightRatio +
              2 * ServerCardSizes.logoPad) *
            t
        : 0.0;

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: logoRoom),
        if (stale != null)
          ServerCardStale(at: stale, spi: srv.spi, openness: t),
        // The name goes as the page's own bar takes it: by the time the
        // readings are the page, what they are of is at the top of the window
        // with the switcher between machines beside it.
        ServerCardTitle(srv: srv, openness: t, selected: selected),
        if (notice != null)
          ServerCardNotice(
            notice: notice,
            openness: t,
            form: hasContent ? ServerNoticeForm.card : ServerNoticeForm.page,
          ),
        if (readings != null)
          _body(
            context,
            readings,
            focus: focus,
            stale: stale != null,
            twoColumns: twoColumns,
            arrival: arrival,
            fold: fold,
          ),
      ],
    );

    final reserved = asideAtEnd * t;

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
  /// another — see [ServerCardArriving]. When that is, is [ServerCardClocks]'s
  /// to say: this is mounted far more often than a machine answers.
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
    required bool stale,
    required bool twoColumns,
    required Animation<double> arrival,
    required Animation<double> fold,
  }) {
    final t = openness;
    final duration = context.motion(kServerCardArrive);
    final others = [
      for (final m in readings.all)
        if (m.kind != focus?.kind) m,
    ];
    // Laid out as unfolded for as long as any of that is showing, which is
    // longer than [expanded] says on the way back: the rows are what the
    // height being given up is the height of.
    final unfolded = expanded || fold.value > 0;
    final rows = _rows(context, readings, focus: focus, unfolded: unfolded);
    final over = readings.all.firstWhereOrNull((m) => m.over);
    final foot = over == null ? null : ServerCardFoot(over: over);
    // One reading has nothing under it to fold, and the page has a row for
    // every one of them.
    final foldable = focus != null && others.isNotEmpty;
    // Which end the control is at, or was last at: it keeps the face of the
    // one it is leaving until it has arrived — see [ServerCardFold] for why.
    final atUnfolded = expanded ? fold.value >= 1 : fold.value > 0;
    // What the machine reports and the card is not drawing, at each end.
    // Counted from what is drawn rather than from the five slots the card has
    // room for: a reading promoted from outside them is drawn, and counting
    // slots would call it unseen.
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
                  ServerCardArriving(
                    clock: arrival,
                    duration: duration,
                    of: sweep,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: lerpDouble(ServerCardSizes.gap, 0, t)!,
                        ),
                        child: ServerCardFocus(
                          metric: focus,
                          others: others,
                          name: srv.spi.name,
                          openness: t,
                          stale: stale,
                          twoColumns: twoColumns,
                          expanded: expanded,
                          fold: fold,
                          selected: selected,
                          onTap: onTap,
                          onPromote: onPromote,
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
                  child: ServerCardArriving(
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
            // than the control made wider — see [ServerCardFold] — and only
            // once it has arrived, since folded this line is what the reading
            // is of.
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
                child: ServerCardArrives(
                  clock: arrival,
                  duration: duration,
                  // With what it is drawn on: the reading, or the last row.
                  at: expanded ? sweep - (foot == null ? 1 : 2) : 0,
                  of: sweep,
                  child: ServerCardFold(
                    unseenFolded: unseenFolded,
                    unseenUnfolded: unseenUnfolded,
                    atUnfolded: atUnfolded,
                    fold: fold,
                    expanded: expanded,
                    openness: t,
                    // While a set is being built up a press means "this one
                    // too", wherever on the card it lands — see [_row].
                    onTap: selected == null ? onToggleExpanded : onTap,
                  ),
                ),
              ),
          ],
        ),
        if (foot != null)
          ServerCardArriving(
            clock: arrival,
            duration: duration,
            from: sweep - 1,
            of: sweep,
            children: [foot],
          ),
      ],
    );
  }

  /// One line, or one tile.
  ///
  /// Both answer a narrower question than the card does — which machine to
  /// look at — so both are the same three things: whether it is up, what it is
  /// called, and the one reading that is being watched. Everything else is a
  /// tap away, and a list of forty is not read by reading forty of anything.
  Widget _compact() {
    final readings = _hasBody ? serverCardReadings(srv) : null;
    final focus = readings == null
        ? null
        : readings.all.firstWhereOrNull((m) => m.kind == promoted) ??
              readings.all.firstOrNull;

    // Connected, but the numbers have stopped. Both shapes say so — the tile
    // by going grey, the line by what it puts in its right column.
    final stale = readings == null ? null : serverStaleSince(srv);

    return density == ServerListDensity.grid
        ? ServerCardTile(
            srv: srv,
            readings: readings,
            focus: focus,
            stale: stale != null,
            selected: selected,
          )
        : ServerCardLine(
            srv: srv,
            readings: readings,
            focus: focus,
            stale: stale,
            selected: selected,
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
    // to the rest of them is on its last line — see [ServerCardFocus].
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
        ServerCardReveal(
          shown: 1 - t,
          child: Padding(
            padding: const EdgeInsets.only(bottom: ServerCardSizes.gap),
            child: Divider(
              height: Hairline.thickness,
              thickness: Hairline.thickness,
              color: Hairline.color(context),
            ),
          ),
        ),
      ..._spaced(rows, onCard, focus: focus),
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

  /// Builds [rows] with transition-aware gaps around rows not shown on cards.
  List<Widget> _spaced(
    List<ServerMetric> rows,
    Set<ServerMetricKind> onCard, {
    required ServerMetric? focus,
  }) {
    final t = openness;
    final gap = SizedBox(height: lerpDouble(ServerCardSizes.rowGap, 0, t));
    final out = <Widget>[];
    var cardRowAbove = false;
    for (final m in rows) {
      if (onCard.contains(m.kind)) {
        if (cardRowAbove) out.add(gap);
        out.add(_row(m));
        cardRowAbove = true;
        continue;
      }
      final row = _row(m, promoted: m.kind == focus?.kind);
      out.add(
        ServerCardReveal(
          shown: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cardRowAbove ? [gap, row] : [row, gap],
          ),
        ),
      );
    }
    return out;
  }

  Widget _row(ServerMetric m, {bool promoted = false}) {
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
}
