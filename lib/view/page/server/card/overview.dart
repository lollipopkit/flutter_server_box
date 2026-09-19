import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/card/metric.dart';

const _tabular = [FontFeature.tabularFigures()];

/// How long back the recent strip looks.
const _kRecentWindow = Duration(hours: 24);

/// How many of them it draws. Three is what a strip is: a longer one is a log,
/// and this is not the place to read one.
const _kRecentCount = 3;

/// What the cards do not answer, under the cards.
///
/// The space below a short list of servers used to be blank. The question it
/// leaves is not about any one machine — it is whether anything has happened —
/// and that is four numbers and a few lines: how many are up, what is over the
/// line, what the whole estate is using, and what it has been doing.
class ServerOverview extends StatelessWidget {
  const ServerOverview({super.key, required this.ids});

  /// The servers the list is showing, which is what these are totals *of*: a
  /// tag that narrows the list narrows the summary with it, or the two would
  /// be answering about different sets of machines.
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_Totals(ids: ids), const SizedBox(height: 9), _Recent()],
      ),
    );
  }
}

class _Totals extends ConsumerWidget {
  const _Totals({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var up = 0;
    var memUsed = 0.0;
    var memTotal = 0.0;
    var rx = 0.0;
    var tx = 0.0;
    final over = <(String, ServerMetric)>[];

    for (final id in ids) {
      final srv = ref.watch(serverProvider(id));
      if (srv.conn.index >= ServerConn.connected.index) up++;
      if (srv.conn != ServerConn.finished) continue;

      final ss = srv.status;
      if (ss.mem.total > 0) {
        // KiB as the status reports them; turned into bytes once, at the end.
        memTotal += ss.mem.total.toDouble();
        memUsed += (ss.mem.total - ss.mem.free).toDouble();
      }
      rx += ss.netSpeed.speedInBytesOf() ?? 0;
      tx += ss.netSpeed.speedOutBytesOf() ?? 0;

      for (final m in serverCardReadings(srv).all) {
        if (m.over) over.add((srv.spi.name, m));
      }
    }

    final memPercent = memTotal <= 0 ? null : memUsed / memTotal * 100;

    return LayoutBuilder(
      builder: (_, cons) {
        // Four across where there is room for four; two otherwise, which is
        // where a phone lands. Never one: these are read against each other.
        final columns = cons.maxWidth >= 640 ? 4 : 2;
        final width = (cons.maxWidth - 9 * (columns - 1)) / columns;
        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            SizedBox(
              width: width,
              child: _Total(
                title: libL10n.conn,
                value: '$up / ${ids.length}',
                note: up == ids.length
                    ? libL10n.all
                    : '${ids.length - up} ${libL10n.disconnected}',
                warn: up < ids.length,
              ),
            ),
            SizedBox(
              width: width,
              child: _Total(
                title: l10n.alerts,
                value: '${over.length}',
                note: over.isEmpty
                    ? ''
                    : '${over.first.$1} · ${over.first.$2.label} '
                          '${over.first.$2.value}',
                warn: over.isNotEmpty,
              ),
            ),
            SizedBox(
              width: width,
              child: _Total(
                title: libL10n.memory,
                value: memPercent == null
                    ? '--'
                    : '${(memPercent * 10).round() / 10}%',
                note: memTotal <= 0
                    ? ''
                    : '${(memUsed * 1024).bytes2Str} / '
                          '${(memTotal * 1024).bytes2Str}',
              ),
            ),
            SizedBox(
              width: width,
              child: _Total(
                title: libL10n.traffic,
                value: '${(rx + tx).bytes2Str}/s',
                note: '↓ ${rx.bytes2Str}/s · ↑ ${tx.bytes2Str}/s',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.title,
    required this.value,
    required this.note,
    this.warn = false,
  });

  final String title;
  final String value;
  final String note;

  /// Whether the number is the reason to be looking at this row.
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 21,
                height: 1.2,
                fontWeight: FontWeight.w500,
                fontFeatures: _tabular,
                color: warn ? StatePalette.warn : null,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 3),
            Text(
              note,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// What has happened to these machines lately.
///
/// Connection attempts, because they are the only thing this app records the
/// time of. A reading crossing a threshold is on the card it belongs to and in
/// the count above; nothing keeps a history of *when* it crossed, so nothing
/// here claims to.
class _Recent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilt with the rest of the strip, which is once per poll: the query is
    // one indexed range over a table capped at a hundred rows per server.
    final events = Stores.connectionStats.recent(
      limit: _kRecentCount,
      within: _kRecentWindow,
    );
    if (events.isEmpty) return const SizedBox.shrink();

    return CardX(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                children: [
                  Text(
                    l10n.recentConnections.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _kRecentWindow.toAgoStr,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final event in events) _RecentRow(event: event),
        ],
      ),
    );
  }
}

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
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? StatePalette.running : StatePalette.failed,
            ),
          ),
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
