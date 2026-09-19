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
    final compact = openness <= 0 && density != ServerListDensity.cards;
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
      radius: compact
          ? const BorderRadius.all(Radius.circular(9))
          : null,
      margin: switch (density) {
        _ when openness > 0 => EdgeInsets.lerp(
          const EdgeInsets.all(4),
          EdgeInsets.zero,
          openness,
        ),
        _ when !compact => null,
        ServerListDensity.rows => const EdgeInsets.symmetric(vertical: 1),
        _ => EdgeInsets.zero,
      },
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
        child: AnimatedSize(
          // Off while the card is growing into the page: its height is
          // already being animated, by the lerps inside it, and a second
          // animation easing towards a target that moves every frame lags
          // behind the width — which is the card's own height arriving after
          // everything else driven by the same movement.
          // Not zero: `RenderAnimatedSize` completes a zero-length animation
          // inside its own `performLayout`, which is a render object dirtying
          // itself mid-layout.
          duration: openness > 0
              ? const Duration(milliseconds: 1)
              : context.motion(Durations.medium3),
          curve: Curves.fastEaseInToSlowEaseOut,
          alignment: Alignment.topCenter,
          child: compact
              ? _compact(context, ref)
              : _full(context, ref),
        ),
      ),
    );
  }

  /// The card, and the readings block of the page it becomes.
  ///
  /// One tree for both, because the movement between them is a hero: the chart
  /// and the rows are the same widgets the whole way, so what travels is them
  /// and not a picture of them. Every measurement that differs between the two
  /// ends is a lerp on [openness], and at 1 this is laid out exactly as
  /// `ServerDetailPage` lays its readings out — which is what lets the page
  /// take over without anything moving.
  Widget _full(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
        if (busy) _progress(context),
        if (err != null && !auth) _error(context, err),
        if (focus != null) ...[
          SizedBox(height: lerpDouble(ServerCardSizes.gap, 0, t)),
          _focus(
            context,
            focus,
            theme: theme,
            stale: stale != null,
            twoColumns: twoColumns,
          ),
        ],
        if (readings != null)
          ..._rows(
            context,
            readings,
            focus: focus,
            theme: theme,
            scheme: scheme,
          ),
        ?_foot(context, readings),
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
      padding: EdgeInsets.lerp(
        const EdgeInsets.all(ServerCardSizes.pad),
        ServerCardSizes.openInset,
        t,
      )!,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ServerCardSizes.collapsed,
        ),
        child: reserved <= 0
            ? column
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: column),
                  // Empty: what goes here is the page's, and it arrives with
                  // the page. What this is for is the width.
                  SizedBox(width: reserved),
                ],
              ),
      ),
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
    final readings = srv.conn == ServerConn.finished && !serverNeverSampled(srv)
        ? serverCardReadings(srv)
        : null;
    final focus = readings == null
        ? null
        : readings.all.firstWhereOrNull((m) => m.kind == promoted) ??
              readings.all.firstOrNull;

    return density == ServerListDensity.grid
        ? _tile(context, readings, focus)
        : _line(context, readings, focus);
  }

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
  Widget _tile(
    BuildContext context,
    ServerCardReadings? readings,
    ServerMetric? focus,
  ) {
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
    required ThemeData theme,
    required bool stale,
    required bool twoColumns,
  }) {
    final t = openness;
    final height = lerpDouble(
      ServerCardSizes.chart,
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
            Icon(m.icon, size: 18, color: m.color),
            const SizedBox(width: 9),
            Text(
              m.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
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
        SizedBox(height: lerpDouble(ServerCardSizes.gap, 0, t)),
        _chart(m, stale: stale, height: height, t: t),
        // Under the chart on the card; on the page it is up in the head row,
        // where it arrives with the page.
        if (m.note.isNotEmpty && t < 1)
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1 - t,
              child: Opacity(
                opacity: 1 - t,
                child: Padding(
                  padding: const EdgeInsets.only(top: ServerCardSizes.gap),
                  child: Text(
                    m.note,
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
            ),
          ),
      ],
    );

    return _surface(context, t, child: body, padding: _kFocusPad);
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final axis = _kChartAxis.transform(t);
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
        // Grey rather than the card dimmed as a whole: pressing the opacity
        // down would take the text with it, and the numbers are still worth
        // reading. What is out of date is the shape.
        series: [HistorySeries(m.label, stale ? Colors.grey : m.color, m.samples)],
        format: m.format,
        times: m.times,
        // The same window the page draws live: from the first sample to now,
        // so a machine that stopped answering leaves the same trailing gap at
        // both ends of the movement.
        window: m.times.isEmpty
            ? null
            : (from: m.times.first, to: now > m.times.last ? now : m.times.last),
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
  List<Widget> _rows(
    BuildContext context,
    ServerCardReadings readings, {
    required ServerMetric? focus,
    required ThemeData theme,
    required ColorScheme scheme,
  }) {
    final t = openness;
    // On the card, the five slots minus the one drawn above. On the page,
    // every reading the machine has — including the promoted one, which is
    // where a different one is chosen from. The ones the card had no room for
    // grow in as it opens rather than appearing when the page takes over.
    final onCard = {
      for (final m in readings.shown)
        if (m.kind != focus?.kind) m.kind,
    };
    final rows = t > 0
        ? readings.all
        : readings.shown.where((m) => m.kind != focus?.kind).toList();
    if (rows.isEmpty && readings.more == 0) return const [];

    return [
      SizedBox(height: lerpDouble(ServerCardSizes.gap, 7, t)),
      // One card's worth of hairline at rest, and nothing once each row is a
      // card: a line between two separate surfaces is a line about neither.
      if (t < 1)
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
      // A machine reporting more than fits says how many rather than growing
      // taller than its neighbours: the cards are scanned down a column, and
      // one card a line longer than the rest is what breaks that.
      if (readings.more > 0 && t < 1)
        Opacity(
          opacity: 1 - t,
          child: Padding(
            padding: const EdgeInsets.only(top: ServerCardSizes.rowGap),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '+${readings.more} ${libL10n.more}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
        ),
    ];
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
      color: m.color,
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
