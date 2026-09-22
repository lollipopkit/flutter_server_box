import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/detail/metric_model.dart';

/// A part of the focus card that eases to the height of what is in it.
///
/// The page's own cards open and close at this pace — see
/// `ServerDetailReadoutCard`.
class ServerDetailEased extends StatelessWidget {
  const ServerDetailEased({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: Durations.short4,
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: child,
  );
}

/// What the chart's place holds when the reading's section of the status
/// failed: that it did, what the machine said, what to do about it, and the
/// way to all of what it said.
///
/// Not a banner over the page — the other readings are fine, and a failure
/// that takes the page with it hides everything that worked. And not the
/// height of the chart it replaces: it was a line of grey monospace centred
/// in 216 points of nothing, which read as a chart that had not loaded yet
/// rather than as something having gone wrong.
///
/// What the machine said is cut to a few lines here. A missing command is
/// one line and a Python traceback is forty, and the card is for knowing
/// which; the whole of it is a press away, where it can be selected.
class ServerDetailReadingFailed extends StatelessWidget {
  const ServerDetailReadingFailed({
    super.key,
    required this.label,
    required this.error,
    required this.wide,
  });

  /// The reading's name, which is what the whole of [error] is shown under.
  final String label;

  /// What the reading's section of the status said instead of a reading.
  final String error;

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const mono = TextStyle(fontSize: 12, height: 1.5, fontFamily: 'monospace');

    return Padding(
      padding: EdgeInsets.only(top: wide ? 17 : 13, bottom: wide ? 9 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, size: 18, color: scheme.error),
              UIs.width7,
              Text(
                libL10n.fail,
                style: TextStyle(
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: scheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            // As wide as what it says where there is room, and the card's
            // width on a phone, where what it says is wider than that anyway.
            width: wide ? null : double.infinity,
            padding: wide
                ? const EdgeInsets.symmetric(horizontal: 13, vertical: 9)
                : const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: UIs.halfAlpha,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              error.trim(),
              style: mono,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(l10n.metricUnavailableTip, style: UIs.text13Grey),
          ),
          const SizedBox(height: 9),
          Btn.row(
            icon: const Icon(Icons.bug_report_outlined, size: 17),
            text: l10n.viewError,
            mainAxisSize: MainAxisSize.min,
            onTap: () => context.showRoundDialog(
              title: label,
              child: SingleChildScrollView(
                child: SelectableText(error.trim(), style: mono),
              ),
              // Closed through the dialog's own context rather than this
              // card's: a poll that brings the reading back replaces the card
              // with the chart while the dialog is still open, and a context
              // that is no longer mounted has no navigator to pop.
              actionsBuilder: (ctx) => [
                TextButton(
                  onPressed: () => Pfs.copy(error.trim()),
                  child: Text(libL10n.copy),
                ),
                TextButton(
                  onPressed: () => ctx.popDialog(),
                  child: Text(libL10n.close),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The chart's place, holding a sentence instead of a chart.
///
/// The same block either way — a request in flight and a metric with nothing
/// stored are both "no line yet", and the card is one height whatever it is
/// showing. [waiting] adds the progress line: an indeterminate 3pt rule
/// rather than a spinner, because what is waiting is this strip and not the
/// page.
class ServerDetailChartNotice extends StatelessWidget {
  const ServerDetailChartNotice({
    super.key,
    required this.height,
    required this.text,
    this.waiting = false,
  });

  final double height;
  final String text;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          if (waiting)
            const LinearProgressIndicator(minHeight: 3, backgroundColor: Colors.transparent),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: UIs.text12Grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What goes with the headline where there is one column: what the number
/// is out of, then each of [stats], all written the way the first is.
///
/// Wrapped rather than cut short. A rate's line is a rate, its direction,
/// the other direction, a peak and a window, which is more than a phone is
/// wide — and the last of those is the one that says what the chart under
/// it covers. The number is about two of these lines tall, so a second run
/// still ends level with it.
class ServerDetailFacts extends StatelessWidget {
  const ServerDetailFacts({super.key, required this.note, required this.stats});

  final String note;
  final List<MetricStat> stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 13,
      runSpacing: 1,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (final fact in [
          if (note.isNotEmpty) note,
          for (final s in stats) '${s.v} ${s.k}',
        ])
          Text(
            fact,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: UIs.text13Grey,
          ),
      ],
    );
  }
}

/// What [ServerDetailFacts] says, where there is room to set each number over
/// its name.
class ServerDetailStats extends StatelessWidget {
  const ServerDetailStats({super.key, required this.stats});

  final List<MetricStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return UIs.placeholder;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, s) in stats.indexed) ...[
          if (i > 0) const SizedBox(width: 17),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                s.v,
                style: const TextStyle(
                  fontSize: 15,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(s.k, style: UIs.text11Grey),
            ],
          ),
        ],
      ],
    );
  }
}

/// The control in the focus card's header that says how many devices a
/// metric has, and opens them.
class ServerDetailDeviceButton extends StatelessWidget {
  const ServerDetailDeviceButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list, size: 15, color: UIs.textGrey.color),
            UIs.width7,
            // The count is as long as the language makes it, and everything
            // in this header is competing for one line.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UIs.text12Grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A metric that is not being read, where the page is one column: what it is
/// at, and how to read it.
///
/// Where there are two columns the row is the card's own `MetricRow` instead.
class ServerDetailMetricTile extends StatelessWidget {
  const ServerDetailMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.selected,
    required this.onTap,
    this.error,
    this.stale = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Under the label: what the figure is of, when it was taken, or what its
  /// section said instead.
  final String note;

  /// Whether this is the reading drawn in full above the rows.
  final bool selected;

  final VoidCallback onTap;

  /// What this metric's section of the status said instead of a reading.
  final String? error;

  /// Whether the figure was taken a while ago and is no longer current.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : null;
    // A reading that is no longer current is drawn as one: the figure goes
    // muted and the note beside it says when it was taken, rather than what
    // the figure is of. Colour is not the only carrier — the timestamp is,
    // and for a section that failed the note is what it said.
    final value = Text(
      this.value,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: error != null
            ? scheme.error
            : stale
            ? UIs.textGrey.color
            : fg,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final Widget body;
    {
      body = Row(
        children: [
          // Narrow has no trailing glyph, so the icon and the value are the
          // whole of what says this row failed — the wide one says it three
          // times over.
          Icon(
            icon,
            size: 18,
            color: error != null
                ? scheme.error
                : selected
                ? fg
                : ChartPalette.accent,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UIs.text11Grey,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          value,
        ],
      );
    }

    // A card, like everything else on this page. Drawn as one rather than as a
    // list row: what is under it is the same surface the chart above sits on,
    // and a row with no card of its own disappeared into the page.
    return CardX(
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
          child: body,
        ),
      ),
    );
  }
}

/// Each core's load as a bar of its own, two to a row once there are enough
/// cores for one a line to be a long column.
class ServerDetailCpuBars extends StatelessWidget {
  const ServerDetailCpuBars({
    super.key,
    required this.cpus,
    required this.showIndex,
  });

  final Cpus cpus;

  /// Whether each bar is labelled with its core's number.
  final bool showIndex;

  @override
  Widget build(BuildContext context) {
    const kMaxColumn = 2;
    const kRowThreshold = 4;
    const kCoresCountThreshold = kMaxColumn * kRowThreshold;
    final children = <Widget>[];

    if (cpus.coresCount >= kCoresCountThreshold) {
      final numCoresToDisplay = cpus.coresCount;
      final numRows = (numCoresToDisplay + kMaxColumn - 1) ~/ kMaxColumn;

      for (var i = 0; i < numRows; i++) {
        final rowChildren = <Widget>[];
        for (var j = 0; j < kMaxColumn; j++) {
          final coreListIndex = i * kMaxColumn + j;
          if (coreListIndex >= numCoresToDisplay) break;

          final coreNumberOneBased = coreListIndex + 1;

          if (showIndex) {
            rowChildren.add(Text('$coreNumberOneBased', style: UIs.text13Grey));
          }
          rowChildren.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _progress(
                  cpus.usedPercent(coreIdx: coreNumberOneBased),
                ),
              ),
            ),
          );
        }
        if (rowChildren.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(children: rowChildren.joinWith(UIs.width7).toList()),
            ),
          );
        }
      }
    } else {
      for (var i = 1; i <= cpus.coresCount; i++) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 17),
            child: _progress(cpus.usedPercent(coreIdx: i)),
          ),
        );
      }
    }

    return Column(children: children);
  }
}

Widget _progress(double? percent) {
  // Indeterminate while there is no reading, instead of a full-width 0 bar
  final percentWithinOne = percent == null
      ? null
      : percent.clamp(0, 100) / 100;
  return LinearProgressIndicator(
    value: percentWithinOne,
    minHeight: 7,
    backgroundColor: UIs.halfAlpha,
    color: UIs.primaryColor,
  );
}

/// A disk and what it is at, with the disks under it a step further in.
class ServerDetailDiskItem extends StatelessWidget {
  const ServerDetailDiskItem({
    super.key,
    required this.disk,
    required this.status,
    this.depth = 0,
  });

  final Disk disk;

  /// What each disk's read and write rates are looked up in.
  final ServerStatus status;

  /// How many disks this one is under.
  final int depth;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    items.add(_row());

    // Flatten the subtree while preserving its depth for indentation.
    if (disk.children.isNotEmpty) {
      for (final childDisk in disk.children) {
        items.add(
          ServerDetailDiskItem(
            disk: childDisk,
            status: status,
            depth: depth + 1,
          ),
        );
      }
    }

    return Column(children: items);
  }

  Widget _row() {
    final (read, write) = status.diskIO.getSpeed(disk.path);
    final text = () {
      final use = '${l10n.used} ${disk.used.kb2Str} / ${disk.size.kb2Str}';
      if (read == null || write == null) return use;
      return '$use\n${l10n.read} $read | ${l10n.write} $write';
    }();

    return Padding(
      padding: EdgeInsets.only(
        left: 17.0 + (depth * 15.0), // Indent based on depth
        right: 17.0,
        top: 5.0,
        bottom: 5.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disk.mount.isEmpty
                      ? disk.path
                      : '${disk.path} (${disk.mount})',
                  style: UIs.text12,
                ),
                Text(text, style: UIs.text12Grey),
              ],
            ),
          ),
          if (disk.size > BigInt.zero)
            SizedBox(
              height: 41,
              width: 41,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: disk.usedPercent / 100,
                    strokeWidth: 5,
                    backgroundColor: UIs.halfAlpha,
                    color: UIs.primaryColor,
                  ),
                  Text('${disk.usedPercent}%', style: UIs.text12Grey),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
