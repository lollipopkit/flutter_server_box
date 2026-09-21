import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/pressure.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/card/title.dart';
import 'package:server_box/view/page/server/reading_text.dart';

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

/// A line: the state, the name, how long it has been up, what it is carrying
/// as one bar with the numbers beside it, and what the network is doing.
///
/// Every one of them the same height, whatever the machine has to say. That
/// is the whole point of this shape — a machine that cannot be reached must
/// not push the forty under it down — so what a failure gets is the middle
/// of the line, where the bars would have been.
class ServerCardLine extends StatelessWidget {
  const ServerCardLine({
    super.key,
    required this.srv,
    required this.readings,
    required this.focus,
    this.stale,
    this.selected,
  });

  final ServerState srv;

  /// What there is to draw, or null before the machine has answered with a
  /// sample.
  final ServerCardReadings? readings;

  /// The one reading being watched.
  final ServerMetric? focus;

  /// Since when the numbers have not moved, while connected.
  final DateTime? stale;

  /// Whether this machine is one of the ones being acted on, or null when
  /// nothing is — see `ServerCard.selected`.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final readings = this.readings;
    final focus = this.focus;
    final (word, wordColor) = _lineState(stale);

    return SizedBox(
      height: isMobile ? ServerCardSizes.rowTouch : ServerCardSizes.row,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: LayoutBuilder(
          builder: (_, cons) {
            // Columns are dropped from the right as the width goes, in the
            // order they are worth least: the rate first, then the numbers
            // beside the bar — which [ServerCardLoad] decides, having the
            // width to decide by — then how long it has been up. The name, the
            // bar and the one reading being watched never go.
            final wide = cons.maxWidth;
            return Row(
              children: [
                if (selected case final selected?)
                  ServerCardCheck(selected: selected),
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
                  Expanded(child: _lineMiddle())
                else
                  Expanded(
                    child: ServerCardLoad(
                      readings: readings,
                      focus: focus,
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
                        fontFeatures: kTabularFigures,
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
                        fontFeatures: kTabularFigures,
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
                if (srv.conn.busy)
                  const SizedBox(width: ServerCardSizes.action)
                else
                  ServerCardConnAction(srv: srv),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Where this machine stands, for the right of a line.
  ///
  /// One column in one place, so it can be read down a list of forty rather
  /// than each row having to be looked at to find out whether it said
  /// anything. Beside it is [ServerCardConnAction] — the one thing to *do*
  /// about each state, and the same mapping the card uses, so a machine offers
  /// the same control whichever shape the list is in.
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
  Widget _lineMiddle() {
    if (srv.conn.busy) {
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
class ServerCardLoad extends StatelessWidget {
  const ServerCardLoad({
    super.key,
    required this.readings,
    required this.focus,
    this.stale = false,
  });

  final ServerCardReadings? readings;

  /// The reading this machine is watched by.
  final ServerMetric focus;

  /// Whether the numbers have stopped, which greys the bar.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final readings = this.readings;
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
                  fontFeatures: kTabularFigures,
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
}

/// A tile: a state, a name and one number.
///
/// What a wall of forty is for. A machine that cannot be reached keeps the
/// tile's height and loses the bar, because a grid whose tiles are different
/// heights is not a grid.
class ServerCardTile extends StatelessWidget {
  const ServerCardTile({
    super.key,
    required this.srv,
    required this.readings,
    required this.focus,
    this.stale = false,
    this.selected,
  });

  final ServerState srv;

  /// What there is to draw, or null before the machine has answered with a
  /// sample.
  final ServerCardReadings? readings;

  /// The one reading being watched.
  final ServerMetric? focus;

  /// Whether the numbers have stopped, which greys the bar.
  final bool stale;

  /// Whether this machine is one of the ones being acted on, or null when
  /// nothing is — see `ServerCard.selected`.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final focus = this.focus;
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
                if (selected case final selected?)
                  ServerCardCheck(selected: selected),
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
                    fontFeatures: kTabularFigures,
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
}
