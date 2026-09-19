import 'dart:ui' show FontFeature, lerpDouble;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/spark.dart';
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

  /// Tall enough to read a shape in on a card, tall enough to read a value off
  /// on the page it becomes.
  static const chart = 44.0;
  static const openChart = 210.0;

  static const rowGap = 7.0;

  /// The column the row labels line up in, which is what lets the numbers on
  /// the right of six cards be compared down a page.
  static const label = 58.0;
  static const openLabel = 84.0;

  /// The least a card with nothing to report takes: a title and no more.
  static const collapsed = 30.0;

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
    required this.onTap,
    this.onLongPress,
    this.openness = 0,
    this.density = ServerListDensity.cards,
  });

  final ServerState srv;

  /// Which reading is drawn in full. Null takes the first one the machine
  /// reports, which is always the CPU.
  final ServerMetricKind? promoted;

  final ValueChanged<ServerMetricKind> onPromote;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 0 is a card in the grid, 1 the detail it becomes. See the class doc.
  final double openness;

  /// How much of this machine to draw.
  ///
  /// Only while it is in the grid: a row that is being opened is on its way to
  /// being the page, and the page has one shape. The height between the two is
  /// animated rather than jumped — see the [AnimatedSize] in [build].
  final ServerListDensity density;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = openness <= 0 && density != ServerListDensity.cards;
    return CardX(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        // Every height this card has is a consequence of what the machine said
        // — a server connecting, a reading promoted, a row arriving — and each
        // of them used to move every card below it in the column between one
        // frame and the next.
        child: AnimatedSize(
          duration: Durations.medium3,
          curve: Curves.fastEaseInToSlowEaseOut,
          alignment: Alignment.topCenter,
          child: compact
              ? _compact(context, ref)
              : _full(context, ref),
        ),
      ),
    );
  }

  Widget _full(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = openness;

    final err = srv.status.err;
    final auth = srv.needsInteractiveAuth;
    final busy = switch (srv.conn) {
      ServerConn.connecting ||
      ServerConn.connected ||
      ServerConn.loading => true,
      _ => false,
    };
    // Only what has been sampled is drawn. A machine that failed keeps its
    // last numbers on its own page, where there is room to say how old they
    // are; on a card the error is the more useful of the two.
    final hasBody =
        srv.conn == ServerConn.finished && !serverNeverSampled(srv);
    final stale = hasBody && err == null ? serverStaleSince(srv) : null;

    final readings = hasBody ? serverCardReadings(srv) : null;
    final focus = readings == null
        ? null
        : readings.all.firstWhereOrNull((m) => m.kind == promoted) ??
              readings.all.firstOrNull;

    final children = <Widget>[
      if (stale != null) _stale(context, stale),
      _title(context, ref),
      if (busy) _progress(context),
      if (err != null && !auth) _error(context, err),
      if (focus != null) ...[
        SizedBox(height: lerpDouble(ServerCardSizes.gap, 17, t)),
        _focus(context, focus, stale: stale != null),
      ],
      if (readings != null)
        ..._rows(context, readings, focus: focus, scheme: scheme),
      ?_foot(context, readings),
    ];

    return Padding(
      padding: EdgeInsets.all(
        lerpDouble(ServerCardSizes.pad, ServerCardSizes.openPad, t)!,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ServerCardSizes.collapsed,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
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
    final readings = srv.conn == ServerConn.finished && !serverNeverSampled(srv)
        ? serverCardReadings(srv)
        : null;
    final focus = readings == null
        ? null
        : readings.all.firstWhereOrNull((m) => m.kind == promoted) ??
              readings.all.firstOrNull;

    return density == ServerListDensity.grid
        ? _tile(context, focus)
        : _line(context, readings, focus);
  }

  /// What a machine's state looks like at seven pixels across.
  Color _dot(ServerCardReadings? readings) => switch (srv.conn) {
    ServerConn.finished =>
      readings != null && readings.all.any((m) => m.over)
          ? StatePalette.warn
          : StatePalette.running,
    ServerConn.failed => StatePalette.failed,
    ServerConn.connecting ||
    ServerConn.connected ||
    ServerConn.loading => StatePalette.warn,
    ServerConn.disconnected => StatePalette.idle,
  };

  /// A line: the state, the name, how long it has been up, two readings and
  /// what the network is doing.
  ///
  /// Every one of them the same height, whatever the machine has to say. That
  /// is the whole point of this shape — a machine that cannot be reached must
  /// not push the forty under it down — so what a failure gets is the middle
  /// of the line, where the bars would have been.
  Widget _line(
    BuildContext context,
    ServerCardReadings? readings,
    ServerMetric? focus,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final second = readings?.shown.firstWhereOrNull(
      (m) => m.kind != focus?.kind && m.percent != null,
    );

    return SizedBox(
      height: isMobile ? ServerCardSizes.rowTouch : ServerCardSizes.row,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: LayoutBuilder(
          builder: (_, cons) {
            // Columns are dropped from the right as the width goes, in the
            // order they are worth least: the rate first, then the second
            // reading, then how long it has been up. The name and the one
            // reading being watched never go.
            final wide = cons.maxWidth;
            return Row(
              children: [
                Container(
                  width: ServerCardSizes.dot,
                  height: ServerCardSizes.dot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _dot(readings),
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
                if (wide >= 560) ...[
                  const SizedBox(width: 13),
                  SizedBox(
                    width: 72,
                    child: Text(
                      srv.listLine ?? '',
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
                const SizedBox(width: 13),
                if (focus == null)
                  // Nothing to draw a bar of, so the line says why in the
                  // space the bars would have taken.
                  Expanded(
                    child: Text(
                      srv.needsInteractiveAuth
                          ? libL10n.tapToAuth
                          : (srv.listLine ?? libL10n.disconnected),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1,
                        color: srv.conn == ServerConn.failed
                            ? StatePalette.failed
                            : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else ...[
                  Expanded(child: _rowReading(focus, scheme)),
                  if (second != null && wide >= 420) ...[
                    const SizedBox(width: 13),
                    Expanded(child: _rowReading(second, scheme)),
                  ],
                ],
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
                const SizedBox(width: 7),
                const Icon(Icons.chevron_right, size: 17, color: Colors.grey),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rowReading(ServerMetric m, ColorScheme scheme) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            // Three letters of the name, because the bar beside it is what is
            // being read and a full label would take the width the bar needs.
            m.label.length <= 4
                ? m.label.toUpperCase()
                : m.label.substring(0, 3).toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              height: 1,
              color: Colors.grey,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: m.percent == null
              ? Text(
                  m.value,
                  style: const TextStyle(fontSize: 11, height: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: m.percent!.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      m.over ? StatePalette.warn : m.color,
                    ),
                  ),
                ),
        ),
        if (m.percent != null) ...[
          const SizedBox(width: 7),
          SizedBox(
            width: 46,
            child: Text(
              m.value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                fontFeatures: _tabular,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ],
    );
  }

  /// A tile: a state, a name and one number.
  ///
  /// What a wall of forty is for. A machine that cannot be reached keeps the
  /// tile's height and loses the bar, because a grid whose tiles are different
  /// heights is not a grid.
  Widget _tile(BuildContext context, ServerMetric? focus) {
    final scheme = Theme.of(context).colorScheme;
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
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _dot(null),
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
                    color: focus?.over == true
                        ? StatePalette.warn
                        : Colors.grey,
                    fontFeatures: _tabular,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
            const SizedBox(height: 5),
            // The slot is kept even with nothing in it, so a machine that is
            // down does not make its tile a different height from the rest.
            ClipRRect(
              borderRadius: BorderRadius.circular(ServerCardSizes.bar),
              child: LinearProgressIndicator(
                value: focus?.percent?.clamp(0.0, 1.0) ?? 0,
                minHeight: ServerCardSizes.bar,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  focus?.over == true
                      ? StatePalette.warn
                      : (focus?.color ?? Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What a tile says where a number would be.
  String get _tileWord => switch (srv.conn) {
    ServerConn.failed =>
      srv.needsInteractiveAuth ? libL10n.tapToAuth : libL10n.fail,
    _ => '—',
  };

  // --- The title, which every state has ---

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

    final wrapped = SizedBox(height: 23, width: 27, child: Center(child: child));
    if (onTap == null) return wrapped;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: wrapped,
    );
  }

  // --- The states that are not a body ---

  /// Connecting: the height does not move and a line under the title says
  /// something is happening.
  ///
  /// Not a skeleton. A skeleton grows to the height of a success first and has
  /// to shrink back when the answer is that there is nothing — which is the
  /// one movement a list of cards cannot afford.
  Widget _progress(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: ServerCardSizes.gap),
      child: LinearProgressIndicator(
        minHeight: ServerCardSizes.bar,
        borderRadius: BorderRadius.all(Radius.circular(ServerCardSizes.bar)),
      ),
    );
  }

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
  Widget _focus(BuildContext context, ServerMetric m, {required bool stale}) {
    final t = openness;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(m.icon, size: 18, color: m.color),
            const SizedBox(width: 9),
            Text(
              m.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              m.value,
              style: const TextStyle(
                fontSize: ServerCardSizes.big,
                height: 1,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: ServerCardSizes.gap),
        Sparkline(
          samples: m.samples,
          // Grey rather than dimmed as a whole: pressing the card's opacity
          // down would take the text with it, and the numbers are still worth
          // reading. What is out of date is the shape.
          color: stale ? Colors.grey : m.color,
          height: lerpDouble(
            ServerCardSizes.chart,
            ServerCardSizes.openChart,
            t,
          )!,
          // A share is drawn against its full so that two cards are
          // comparable; a rate has no full and is drawn against its own peak.
          max: m.percent == null ? null : 100,
        ),
        if (m.note.isNotEmpty) ...[
          const SizedBox(height: ServerCardSizes.gap),
          Text(
            m.note,
            style: const TextStyle(fontSize: 11, height: 1.4, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// The rest of the readings, one line each.
  ///
  /// The one being drawn above is not repeated here: it is the same reading,
  /// and a row for it would be a second copy of the number already at the top
  /// of the card.
  List<Widget> _rows(
    BuildContext context,
    ServerCardReadings readings, {
    required ServerMetric? focus,
    required ColorScheme scheme,
  }) {
    final rows = readings.shown
        .where((m) => m.kind != focus?.kind)
        .toList();
    if (rows.isEmpty && readings.more == 0) return const [];

    return [
      const SizedBox(height: ServerCardSizes.gap),
      Divider(
        height: Hairline.thickness,
        thickness: Hairline.thickness,
        color: Hairline.color(context),
      ),
      const SizedBox(height: ServerCardSizes.gap),
      for (final (at, m) in rows.indexed) ...[
        if (at > 0) const SizedBox(height: ServerCardSizes.rowGap),
        _row(context, m, scheme: scheme),
      ],
      // A machine reporting more than fits says how many rather than growing
      // taller than its neighbours: the cards are scanned down a column, and
      // one card a line longer than the rest is what breaks that.
      if (readings.more > 0)
        Padding(
          padding: const EdgeInsets.only(top: ServerCardSizes.rowGap),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '+${readings.more} ${libL10n.more}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ),
    ];
  }

  Widget _row(
    BuildContext context,
    ServerMetric m, {
    required ColorScheme scheme,
  }) {
    final t = openness;
    final percent = m.percent;

    final row = Row(
      children: [
        Icon(m.icon, size: 17, color: Colors.grey),
        const SizedBox(width: 9),
        SizedBox(
          width: lerpDouble(
            ServerCardSizes.label,
            ServerCardSizes.openLabel,
            t,
          ),
          child: Text(
            m.label,
            style: const TextStyle(fontSize: 12, height: 1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: percent == null
              // A rate has no full, so the space a bar would take says what
              // the number is of instead.
              ? Text(
                  m.note,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(ServerCardSizes.bar),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0.0, 1.0),
                    minHeight: ServerCardSizes.bar,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      m.over ? StatePalette.warn : m.color,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 9),
        Text(
          m.value,
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w500,
            fontFeatures: _tabular,
          ),
        ),
      ],
    );

    // Tapping a row promotes it, which is the one thing a card lets you do to
    // it without leaving the list. The ink extends past the row on both sides
    // so that the target is something a finger can find, which the row's own
    // 17pt of icon is not.
    return InkWell(
      onTap: () => onPromote(m.kind),
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: row,
      ),
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
