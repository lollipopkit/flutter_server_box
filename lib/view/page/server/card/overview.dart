import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/context/motion.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/card/metric.dart';

const _tabular = [FontFeature.tabularFigures()];

/// How long back the recent list looks.
const _kRecentWindow = Duration(hours: 24);

/// How many of them it draws. Three is what a strip is: a longer one is a log,
/// and this is not the place to read one.
const _kRecentCount = 3;

/// The strip's own height, and the design's.
const _kStripHeight = 46.0;

/// One fleet reading's bar: short enough that three of them and their numbers
/// fit beside everything else on one line.
const _kBarWidth = 52.0;
const _kBarHeight = 4.0;

/// What the cards do not answer, above the cards.
///
/// One line: how many machines are up, what the whole estate is using, and the
/// last thing that happened. It is what decides whether to read further down,
/// so it comes before the thing it is deciding about — as four cards and a
/// table *under* the list it was answering a question nobody had got to yet.
///
/// The rest of what happened is not gone: the count at the right end opens the
/// strip into the list it summarises.
class ServerOverview extends ConsumerStatefulWidget {
  const ServerOverview({super.key, required this.ids});

  /// The servers the list is showing, which is what these are totals *of*: a
  /// tag that narrows the list narrows the summary with it, or the two would
  /// be answering about different sets of machines.
  final List<String> ids;

  @override
  ConsumerState<ServerOverview> createState() => _ServerOverviewState();
}

class _ServerOverviewState extends ConsumerState<ServerOverview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.ids.isEmpty) return const SizedBox.shrink();

    final totals = _read(ref);
    // Rebuilt with the rest of the strip, which is once per poll: the query is
    // one indexed range over a table capped at a hundred rows per server.
    final events = Stores.connectionStats.recent(
      limit: _kRecentCount,
      within: _kRecentWindow,
    );

    return Padding(
      // The design's gap between this and the first row of cards. The grid
      // brings none of its own above the header.
      padding: const EdgeInsets.only(bottom: 9),
      child: CardX(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: AnimatedSize(
          duration: context.motion(Durations.medium2),
          curve: Curves.fastEaseInToSlowEaseOut,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _kStripHeight,
                child: LayoutBuilder(
                  builder: (_, cons) =>
                      _strip(context, totals, events, cons.maxWidth),
                ),
              ),
              if (_expanded)
                for (final event in events) _RecentRow(event: event),
            ],
          ),
        ),
      ),
    );
  }

  /// The line itself: three sections with a hairline between them.
  ///
  /// Sections are dropped from the right as the width goes, in the order they
  /// are worth least — what has happened before what the estate is using,
  /// because the second is the one being scanned. The way into the list is
  /// never dropped.
  Widget _strip(
    BuildContext context,
    _Totals totals,
    List<ConnectionStat> events,
    double width,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final bars = switch (width) {
      >= 760 => 3,
      >= 600 => 2,
      _ => 1,
    };
    final showLast = width >= 820;
    // A phone keeps the count, one bar and the way into the list, and gives up
    // the word and half the room between sections to do it.
    final compact = width < 480;

    return Row(
      children: [
        _online(totals, compact: compact),
        _divider(context),
        _bars(totals, count: bars, compact: compact),
        if (showLast || events.isNotEmpty) _divider(context),
        if (showLast)
          Expanded(child: _last(context, totals, events, scheme: scheme))
        else ...[
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 9),
            child: _more(events, scheme: scheme),
          ),
        ],
      ],
    );
  }

  Widget _divider(BuildContext context) => VerticalDivider(
    width: Hairline.thickness,
    thickness: Hairline.thickness,
    color: Hairline.color(context),
  );

  /// How many of them answered, which is the first thing a list of machines is
  /// looked at for.
  Widget _online(_Totals totals, {required bool compact}) {
    final all = totals.up == totals.count;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(all ? StatePalette.running : StatePalette.warn),
          const SizedBox(width: 7),
          Text(
            '${totals.up} / ${totals.count}',
            style: const TextStyle(
              fontSize: 15,
              height: 1,
              fontWeight: FontWeight.w500,
              fontFeatures: _tabular,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 7),
            Text(
              l10n.online,
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// What the whole estate is using, as three bars.
  ///
  /// Memory and disk are summed — bytes are bytes, wherever they are — and the
  /// processors are averaged, because a fleet has no single one to be a share
  /// of.
  Widget _bars(_Totals totals, {required int count, required bool compact}) {
    final all = <({String k, double? pct, String v, Color color})>[
      (
        k: 'CPU',
        pct: totals.cpu,
        v: _pct(totals.cpu),
        color: ChartPalette.cpu,
      ),
      (
        k: libL10n.memory,
        pct: totals.mem,
        v: _pct(totals.mem),
        color: ChartPalette.mem,
      ),
      (
        k: libL10n.disk,
        pct: totals.disk,
        v: _pct(totals.disk),
        color: ChartPalette.disk,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (at, one) in all.take(count).indexed) ...[
            if (at > 0) const SizedBox(width: 17),
            Text(
              // Three letters, because what is being read is the bar beside it
              // and a full word would take the width the bar needs.
              one.k.length <= 4
                  ? one.k.toUpperCase()
                  : one.k.substring(0, 3).toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                height: 1,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: _kBarWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kBarHeight),
                child: LinearProgressIndicator(
                  value: (one.pct ?? 0) / 100,
                  minHeight: _kBarHeight,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    (one.pct ?? 0) >= kServerAlertPercent
                        ? StatePalette.warn
                        : one.color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              one.v,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w500,
                fontFeatures: _tabular,
                color: (one.pct ?? 0) >= kServerAlertPercent
                    ? StatePalette.warn
                    : one.color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The one thing worth saying, and the way to the rest.
  ///
  /// A reading over the line outranks anything that has merely happened, and
  /// carries no time because nothing records when a reading crossed — what it
  /// says is the state now. Otherwise this is the last connection attempt,
  /// which is the one thing this app does record the time of.
  Widget _last(
    BuildContext context,
    _Totals totals,
    List<ConnectionStat> events, {
    required ColorScheme scheme,
  }) {
    final over = totals.over;
    final event = events.firstOrNull;
    final (color, name, text, at) = switch ((over, event)) {
      ((final name, final m)?, _) => (
        StatePalette.warn,
        name,
        '${m.label} ${m.value} · ${m.note}',
        null,
      ),
      (_, final e?) => (
        e.result == ConnectionResult.success
            ? StatePalette.running
            : StatePalette.failed,
        e.serverName,
        e.result == ConnectionResult.success
            ? '${libL10n.conn} · ${e.durationMs} ms'
            : (e.errorMessage.isEmpty ? e.result.name : e.errorMessage),
        e.timestamp.toAgoStr(),
      ),
      _ => (Colors.grey, '', '', null),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 9, 0),
      child: Row(
        children: [
          if (name.isNotEmpty) ...[
            _Dot(color),
            const SizedBox(width: 9),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              maxLines: 1,
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (at != null) ...[
            const SizedBox(width: 9),
            Text(
              at,
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: Colors.grey,
                fontFeatures: _tabular,
              ),
            ),
          ],
          const SizedBox(width: 9),
          _more(events, scheme: scheme),
        ],
      ),
    );
  }

  /// How much more there is, and the way to it.
  Widget _more(List<ConnectionStat> events, {required ColorScheme scheme}) {
    if (events.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 26,
        padding: const EdgeInsets.fromLTRB(7, 0, 5, 0),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+${events.length}',
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: Colors.grey,
                fontFeatures: _tabular,
              ),
            ),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: context.motion(Durations.short4),
              child: const Icon(
                Icons.expand_more,
                size: 17,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Everything the line is a summary of, read once.
  _Totals _read(WidgetRef ref) {
    var up = 0;
    var memUsed = 0.0;
    var memTotal = 0.0;
    var diskUsed = 0.0;
    var diskTotal = 0.0;
    var cpuSum = 0.0;
    var cpuCount = 0;
    (String, ServerMetric)? over;

    for (final id in widget.ids) {
      final srv = ref.watch(serverProvider(id));
      if (srv.conn.index >= ServerConn.connected.index) up++;
      if (srv.conn != ServerConn.finished) continue;

      final ss = srv.status;
      if (ss.mem.total > 0) {
        memTotal += ss.mem.total.toDouble();
        memUsed += (ss.mem.total - ss.mem.free).toDouble();
      }
      if (ss.disk.isNotEmpty) {
        final usage = ss.diskUsage ?? DiskUsage.parse(ss.disk);
        diskTotal += usage.size.toDouble();
        diskUsed += usage.used.toDouble();
      }
      if (ss.cpu.usedPercent(coreIdx: 0) case final used?) {
        cpuSum += used;
        cpuCount++;
      }

      // The first one found, which is the first machine in the list that has
      // one: a line with room for one of them says which, not how many.
      if (over == null) {
        for (final m in serverCardReadings(srv).all) {
          if (m.over) {
            over = (srv.spi.name, m);
            break;
          }
        }
      }
    }

    return _Totals(
      count: widget.ids.length,
      up: up,
      cpu: cpuCount == 0 ? null : cpuSum / cpuCount,
      mem: memTotal <= 0 ? null : memUsed / memTotal * 100,
      disk: diskTotal <= 0 ? null : diskUsed / diskTotal * 100,
      over: over,
    );
  }
}

String _pct(double? v) =>
    v == null ? '--' : '${(v * 10).round() / 10}%';

/// What the line says, worked out once.
class _Totals {
  const _Totals({
    required this.count,
    required this.up,
    required this.cpu,
    required this.mem,
    required this.disk,
    required this.over,
  });

  final int count;
  final int up;
  final double? cpu;
  final double? mem;
  final double? disk;

  /// The first reading past the line, and whose it is.
  final (String, ServerMetric)? over;
}

/// What a machine's state looks like at seven pixels across, which is the
/// same seven pixels the cards use.
class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// One of the things that have happened, once the strip is opened out.
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.event});

  final ConnectionStat event;

  @override
  Widget build(BuildContext context) {
    final ok = event.result == ConnectionResult.success;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Hairline.color(context))),
      ),
      child: Row(
        children: [
          _Dot(ok ? StatePalette.running : StatePalette.failed),
          const SizedBox(width: 11),
          SizedBox(
            width: 96,
            child: Text(
              event.serverName,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              // What happened, in the machine's own words when it failed: the
              // result name alone says which of five kinds it was, and the
              // message is the part anyone can act on.
              ok
                  ? '${libL10n.conn} · ${event.durationMs} ms'
                  : (event.errorMessage.isEmpty
                        ? event.result.name
                        : event.errorMessage),
              style: const TextStyle(fontSize: 12, height: 1.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 11),
          Text(
            event.timestamp.toAgoStr(),
            style: const TextStyle(
              fontSize: 11,
              height: 1.3,
              color: Colors.grey,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}
