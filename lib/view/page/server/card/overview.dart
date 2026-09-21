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
import 'package:server_box/view/page/server/card/pressure.dart';
import 'package:server_box/view/page/server/reading_text.dart';

/// How long back the recent list looks.
const _kRecentWindow = Duration(hours: 24);

/// How many of them it draws. Three is what a strip is: a longer one is a log,
/// and this is not the place to read one.
const _kRecentCount = 3;

/// The strip's own height, and the design's.
///
/// Also the height of the machine switcher that turns over into this strip's
/// slot while a server is open — see `ServerStrip` — so the slot is one
/// height whichever face is up.
const kServerStripHeight = 46.0;

/// One fleet reading's bar: short enough that three of them and their numbers
/// fit beside everything else on one line.
const _kBarWidth = 52.0;
const _kBarHeight = 4.0;

/// From here there is room for a bar each. Below it the three share one.
const _kSeparateBars = 760.0;

/// The one bar's share of its section: the least it is drawn at, the width of
/// one reading's name and number after it, and the gap before each.
///
/// The same rule a line in the list shares its bar by: a third of what there
/// is and never under 48, which is about what three stretches of colour can
/// still be told apart in. The numbers get the rest and go from the right as
/// the width does. 66 is "DIS 100.0%" at these sizes — at the size the text
/// is drawn at, so it is scaled with it: see [ServerOverview._pressure].
const _kPressureMin = 48.0;
const _kValueWidth = 66.0;
const _kValueGap = 11.0;

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
  const ServerOverview({super.key, required this.ids, this.open = false});

  /// The servers the list is showing, which is what these are totals *of*: a
  /// tag that narrows the list narrows the summary with it, or the two would
  /// be answering about different sets of machines.
  final List<String> ids;

  /// Whether one of those machines is open, which is what this strip turns
  /// over to make room for.
  ///
  /// It closes when that happens: the slot is one height on both of its faces,
  /// and a face that is three rows taller than the other turns into a shape
  /// that is not there.
  final bool open;

  @override
  ConsumerState<ServerOverview> createState() => _ServerOverviewState();
}

class _ServerOverviewState extends ConsumerState<ServerOverview> {
  bool _expanded = false;

  @override
  void didUpdateWidget(ServerOverview old) {
    super.didUpdateWidget(old);
    if (widget.open && _expanded) _expanded = false;
  }

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

    // No gap of its own above or below: the slot this sits in keeps it, for
    // this and for the switcher that takes its place — see the server tab's
    // `_kStripInset`.
    return CardX(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: AnimatedSize(
        duration: context.motion(Durations.medium2),
        curve: Curves.fastEaseInToSlowEaseOut,
        alignment: Alignment.topCenter,
        // Around the list as well as the line: what the list opens with
        // depends on whether the line had room to say it — see [_strip].
        child: LayoutBuilder(
          builder: (_, cons) {
            final showLast = cons.maxWidth >= _kShowLast;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: kServerStripHeight,
                  child: _strip(context, totals, events, cons.maxWidth),
                ),
                if (_expanded) ...[
                  // What the dot was the colour of, when the line was too
                  // narrow to say: a dot that opens onto three connections
                  // that went fine has not said why it is amber.
                  if (!showLast)
                    if (totals.over case final over?)
                      _RecentRow(said: _saidOver(over)),
                  for (final event in events) _RecentRow(said: _saidOf(event)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The line itself: three sections with a hairline between them.
  ///
  /// What gives as the width goes is detail, never a section. The last thing
  /// that happened loses its words first and keeps its colour — see [_more] —
  /// and then the three bars become one, which is the three of them laid end
  /// to end the way a tile in the list draws a machine. They used to be
  /// dropped instead, memory and then the disk, so a phone was told about the
  /// processors and nothing else: the one of the three that says least about
  /// whether anything needs looking at.
  Widget _strip(
    BuildContext context,
    _Totals totals,
    List<ConnectionStat> events,
    double width,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final separate = width >= _kSeparateBars;
    final showLast = width >= _kShowLast;
    // A phone gives up the word and half the room between sections.
    final compact = width < 480;
    final said = _said(totals, events);

    return Row(
      children: [
        _online(totals, compact: compact),
        _divider(context),
        if (separate)
          _bars(totals, compact: compact)
        else
          Expanded(child: _pressure(totals, compact: compact)),
        if (said != null) _divider(context),
        if (showLast)
          Expanded(
            child: said == null
                ? const SizedBox.shrink()
                : _last(context, said, events, scheme: scheme),
          )
        else ...[
          if (separate) const Spacer(),
          if (said != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: _more(
                scheme: scheme,
                // The line had no room to say it, so the colour is all of it
                // — and there is something behind it whenever there is one.
                dot: said.color,
                opens: true,
              ),
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
              fontFeatures: kTabularFigures,
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
  Widget _bars(_Totals totals, {required bool compact}) {
    // One colour for all three, and it is the theme's. These are not three
    // readings being told apart — each is named at the head of its own bar —
    // they are three lengths being read across one strip, and three hues
    // there is the strip competing with the cards under it for the one thing
    // colour is spent on. The one over its line is the exception, below.
    final color = ChartPalette.accent;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (at, one) in totals.shares.indexed) ...[
            if (at > 0) const SizedBox(width: 17),
            Text(
              one.short,
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
                    one.over ? StatePalette.warn : color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              ReadingFmt.pct(one.pct),
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w500,
                fontFeatures: kTabularFigures,
                color: one.over ? StatePalette.warn : color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The same three as one bar, for a line with no room for a bar each.
  ///
  /// [PressureBar] is what a tile in the list draws one machine as, at the
  /// same weights — so this is that reading for the whole list, and can be
  /// read against the tiles under it. The names are in the colours of their
  /// stretches, which is what makes three colours in one bar three readings
  /// rather than a gradient. The numbers go from the right as the width does
  /// and the bar stays, which is the order a line in the list gives them up
  /// in.
  Widget _pressure(_Totals totals, {required bool compact}) {
    final shares = totals.shares;
    final segments = pressureOf(
      (kind) => switch (shares.firstWhereOrNull((s) => s.kind == kind)?.pct) {
        final pct? => pct / 100,
        null => null,
      },
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
      child: LayoutBuilder(
        builder: (context, cons) {
          final bar = cons.maxWidth / 3 < _kPressureMin
              ? _kPressureMin
              : cons.maxWidth / 3;
          // As wide as the longest of them at the size the text is drawn at.
          // It was 66 whatever that was: a phone with its text turned down
          // had a fifth of each as slack, and one with it turned up had its
          // numbers cut short.
          final slot = MediaQuery.textScalerOf(context).scale(_kValueWidth);
          final room = ((cons.maxWidth - bar) / (slot + _kValueGap))
              .floor()
              .clamp(0, shares.length);

          return Row(
            children: [
              Expanded(child: PressureBar(segments: segments)),
              for (final one in shares.take(room))
                Padding(
                  padding: const EdgeInsets.only(left: _kValueGap),
                  child: SizedBox(
                    width: slot,
                    // The name against its number, and what the slot has left
                    // over before the two of them. The name was at one end
                    // and the number at the other, so the slack was between a
                    // name and what it is the name of — "CPU      2.6%" — and
                    // wider than the gap to the next reading, which is the
                    // one that should say where one ends.
                    //
                    // The slot stays as wide as the longest, so the bar does
                    // not change width as a number gains a digit, and ends
                    // where it did: the number is still against the right.
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          one.short,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1,
                            color: pressureColor(one.kind, over: one.over),
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            ReadingFmt.pct(one.pct),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w500,
                              fontFeatures: kTabularFigures,
                              color: one.over ? StatePalette.warn : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The one thing worth saying, or null when there is nothing.
  ///
  /// A reading over the line outranks anything that has merely happened, and
  /// carries no time because nothing records when a reading crossed — what it
  /// says is the state now. Otherwise this is the last connection attempt,
  /// which is the one thing this app does record the time of.
  _Said? _said(_Totals totals, List<ConnectionStat> events) =>
      switch ((totals.over, events.firstOrNull)) {
        (final over?, _) => _saidOver(over),
        (_, final event?) => _saidOf(event),
        _ => null,
      };

  /// [said] in words, and the way to the rest.
  Widget _last(
    BuildContext context,
    _Said said,
    List<ConnectionStat> events, {
    required ColorScheme scheme,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 9, 0),
      child: Row(
        children: [
          _Dot(said.color),
          const SizedBox(width: 9),
          Text(
            said.name,
            style: TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w500,
              color: said.color,
            ),
            maxLines: 1,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              said.text,
              style: const TextStyle(fontSize: 12, height: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (said.at case final at?) ...[
            const SizedBox(width: 9),
            Text(
              at,
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: Colors.grey,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
          const SizedBox(width: 9),
          // No dot of its own: the one at the head of these words is it.
          _more(scheme: scheme, opens: events.isNotEmpty),
        ],
      ),
    );
  }

  /// The way to the rest of what has happened, and what colour the last of it
  /// was.
  ///
  /// A dot rather than a count. The count was of what the list holds, which is
  /// capped at [_kRecentCount] — so it said "+3" on every install with a day's
  /// use behind it, and what a line with no room for words most needs to say
  /// is whether the last thing that happened went well. [dot] is null where
  /// the words are on the line and carry their own.
  ///
  /// [opens] is whether there is anything to open onto; without it this is
  /// the dot alone.
  Widget _more({
    required ColorScheme scheme,
    required bool opens,
    Color? dot,
  }) {
    if (!opens) {
      return dot == null ? const SizedBox.shrink() : _Dot(dot);
    }
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 26,
        padding: EdgeInsets.fromLTRB(dot == null ? 5 : 9, 0, 5, 0),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[_Dot(dot), const SizedBox(width: 3)],
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

/// From here the last thing that happened is said in words on the line.
const _kShowLast = 820.0;

/// One thing worth saying: whose it is, what, how it went and when.
typedef _Said = ({Color color, String name, String text, String? at});

/// A reading past its line, which is a state and so has no time.
_Said _saidOver((String, ServerMetric) over) => (
  color: StatePalette.warn,
  name: over.$1,
  text: '${over.$2.label} ${over.$2.value} · ${over.$2.note}',
  at: null,
);

/// A connection attempt, in the machine's own words when it failed: the result
/// name alone says which of five kinds it was, and the message is the part
/// anyone can act on.
_Said _saidOf(ConnectionStat e) {
  final ok = e.result == ConnectionResult.success;
  return (
    color: ok ? StatePalette.running : StatePalette.failed,
    name: e.serverName,
    text: ok
        ? '${libL10n.conn} · ${e.durationMs} ms'
        : (e.errorMessage.isEmpty ? e.result.name : e.errorMessage),
    at: e.timestamp.toAgoStr(),
  );
}

/// One of the three things a list is using, as a share of what it has.
typedef _Share = ({ServerMetricKind kind, String short, double? pct, bool over});

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

  /// The three as the line draws them, in the order [PressureBar] lays them
  /// end to end — which is the order they were dropped in when they were.
  ///
  /// Three letters each, because what is being read is the bar beside the
  /// name and a full word would take the width the bar needs.
  List<_Share> get shares => [
    for (final (kind, name, pct) in [
      (ServerMetricKind.cpu, 'CPU', cpu),
      (ServerMetricKind.mem, libL10n.memory, mem),
      (ServerMetricKind.disk, libL10n.disk, disk),
    ])
      (
        kind: kind,
        short: name.length <= 4
            ? name.toUpperCase()
            : name.substring(0, 3).toUpperCase(),
        pct: pct,
        over: (pct ?? 0) >= kServerAlertPercent,
      ),
  ];
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

/// One of the things worth saying, once the strip is opened out.
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.said});

  final _Said said;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Hairline.color(context))),
      ),
      child: Row(
        children: [
          _Dot(said.color),
          const SizedBox(width: 11),
          SizedBox(
            width: 96,
            child: Text(
              said.name,
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
              said.text,
              style: const TextStyle(fontSize: 12, height: 1.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (said.at case final at?) ...[
            const SizedBox(width: 11),
            Text(
              at,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                color: Colors.grey,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
