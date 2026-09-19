import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/gpu.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';

/// Which reading a row, or the chart above the rows, is showing.
enum ServerMetricKind { cpu, mem, swap, disk, diskIo, net, gpu, temp, battery }

/// The share at which a reading stops being a number and becomes a reason to
/// look at this machine.
///
/// One line for the whole app: the card's footer, the overview's alert count
/// and the extra slot's ranking all mean the same thing by "over".
const kServerAlertPercent = 85.0;

/// One reading, as a card draws it.
///
/// The same object is the row and the chart: promoting a row is choosing which
/// of these the card draws in full, so the two can never disagree about the
/// number they are showing.
final class ServerMetric {
  const ServerMetric({
    required this.kind,
    required this.label,
    required this.icon,
    required this.value,
    required this.note,
    required this.bigNote,
    required this.samples,
    required this.times,
    required this.format,
    this.percent,
    this.binary = false,
  });

  final ServerMetricKind kind;
  final String label;
  final IconData icon;

  // No colour. What a reading is drawn in depends on whether it is the one
  // that card is watching, which is not something a reading knows about
  // itself — see `ChartPalette.promoted` and the card's own `_seriesColor`.

  /// The reading now, written the way the row and the headline both write it.
  final String value;

  /// What the value is a share of, or which device is carrying it.
  final String note;

  /// What goes beside the value once it is a headline rather than a figure at
  /// the end of a row.
  ///
  /// Shorter than [note] and about the number rather than about the machine:
  /// beside "35.3%" the useful half is what it is of, and the other half —
  /// which disk, which interface — is already the row's business.
  final String bigNote;

  /// 0-1 for a reading with a full, null for a rate: only the first kind gets
  /// a bar, because only it has something to be a share of.
  final double? percent;

  /// The window this app kept, oldest last — `StatusHistory` order.
  ///
  /// A poll that measured nothing holds null rather than zero, so the chart
  /// draws a gap where a machine was unreachable instead of a floor.
  final List<double?> samples;

  /// When each of [samples] was taken, index-aligned with it.
  ///
  /// What the chart plots against, so the card's line and the page's are the
  /// same line: the page draws its window against these instants, and a card
  /// plotting against the sample index would draw a different shape wherever
  /// a poll ran late.
  final List<int> times;

  /// How a value of this reading is written on an axis.
  ///
  /// The page's own formatter, because the axis labels are part of what the
  /// card grows into: a chart whose ticks change wording at the handover is a
  /// chart that was replaced.
  final String Function(double) format;

  /// Whether the values are byte-based, so the axis steps in multiples of 1024
  /// rather than of 10.
  final bool binary;

  /// Whether this reading is past [kServerAlertPercent].
  bool get over => percent != null && percent! * 100 >= kServerAlertPercent;
}

/// Which reading a machine is being watched by, remembered per machine.
///
/// The card and the detail page are one structure at two sizes, so promoting a
/// row on either is the same choice: a database watched for its disk stays
/// watched for its disk when it is opened, and picking a different one there
/// is what the card shows when it is closed again.
///
/// Stored by [ServerMetricKind.name], never by index: a case inserted into
/// that enum would silently repoint every stored choice.
abstract final class ServerPromoted {
  static ServerMetricKind? of(String serverId) {
    final name = Stores.setting.serverCardMetric.fetch()[serverId];
    if (name == null) return null;
    return ServerMetricKind.values.firstWhereOrNull((e) => e.name == name);
  }

  /// Answers whether anything changed, so a caller can skip a rebuild.
  static bool put(String serverId, ServerMetricKind kind) {
    final map = Map<String, String>.from(
      Stores.setting.serverCardMetric.fetch(),
    );
    if (map[serverId] == kind.name) return false;
    map[serverId] = kind.name;
    Stores.setting.serverCardMetric.put(map);
    return true;
  }
}

/// What one card shows: the readings it has room for, and how many it has not.
typedef ServerCardReadings = ({
  /// In the order every card draws them — see [serverCardReadings].
  List<ServerMetric> shown,

  /// Every reading this machine reports, for the detail and the row picker.
  List<ServerMetric> all,

  /// How many of [all] did not fit in [shown].
  int more,
});

/// Whether this server has said anything about itself yet.
bool serverNeverSampled(ServerState srv) =>
    srv.status.more.isEmpty && srv.status.history.isEmpty;

/// How long without a sample counts as the readings having stopped.
///
/// Three polls, and never under half a minute: one poll running long is a slow
/// script rather than a stopped app, and a card that says "stale" every time a
/// refresh takes its time teaches the reader to ignore it.
Duration get _staleAfter {
  final seconds = Stores.setting.serverStatusUpdateInterval.fetch();
  final polls = Duration(seconds: (seconds > 0 ? seconds : 10) * 3);
  return polls < const Duration(seconds: 30)
      ? const Duration(seconds: 30)
      : polls;
}

/// When the last sample landed, if that was long enough ago to say so.
///
/// A connection that is up but no longer sampling keeps its numbers — the last
/// reading is still the most recent thing known about the machine — and says
/// how old they are. Falling back to the connecting state instead would throw
/// away numbers that are still worth something.
DateTime? serverStaleSince(ServerState srv) {
  final times = srv.status.history.time;
  if (times.isEmpty) return null;
  final at = DateTime.fromMillisecondsSinceEpoch(times.last);
  return DateTime.now().difference(at) > _staleAfter ? at : null;
}

/// The readings every card draws when the machine reports them.
const _kAlwaysShown = {
  ServerMetricKind.cpu,
  ServerMetricKind.mem,
  ServerMetricKind.disk,
  ServerMetricKind.net,
};

/// The readings [srv] reports, and the five a card draws.
///
/// Which five: [_kAlwaysShown], plus one that varies by machine — see
/// [_extra]. A machine reporting more says how many by a count instead of
/// making its card taller than the others.
///
/// `shown` keeps the order of `all`, which is the order the detail page draws
/// its rows in. The card grows into that page, so a row in a different place
/// on the two moved on the first frame of the transition and back on the last.
/// It used to be cpu, mem, disk, extra, net: a swap was drawn after the disk
/// on the card and before it on the page, and a GPU before the network on the
/// card and after it on the page. The cost is that the disk or the network is
/// one row lower on a card whose varying reading comes before it.
///
/// The network counts as taken before [_extra] is asked. It did not, so a
/// machine reporting nothing else got it twice and a `more` of -1 — every
/// swapless machine on its first poll, before disk I/O has a second sample.
ServerCardReadings serverCardReadings(ServerState srv) {
  final all = _readings(srv);
  final kinds = {
    for (final m in all)
      if (_kAlwaysShown.contains(m.kind)) m.kind,
  };
  if (_extra(all, kinds) case final extra?) kinds.add(extra.kind);

  final shown = [
    for (final m in all)
      if (kinds.contains(m.kind)) m,
  ];
  return (shown: shown, all: all, more: all.length - shown.length);
}

/// Returns the status color used by server indicators.
///
/// [readings] can be supplied when the caller already has computed readings.
Color serverStateDot(ServerState srv, {ServerCardReadings? readings}) =>
    switch (srv.conn) {
      ServerConn.finished =>
        (readings ?? serverCardReadings(srv)).all.any((m) => m.over)
            ? StatePalette.warn
            : StatePalette.running,
      ServerConn.failed => StatePalette.failed,
      ServerConn.connecting ||
      ServerConn.connected ||
      ServerConn.loading => StatePalette.warn,
      ServerConn.disconnected => StatePalette.idle,
    };

/// One stretch of a tile's pressure bar: how much of the bar it takes, which
/// reading it is, and whether that reading is over its line.
typedef ServerPressureSegment = ({
  double share,
  ServerMetricKind kind,
  bool over,
});

/// How much of the bar memory and disk are allowed, against the CPU's whole.
///
/// Not a judgement about which matters — it is that the three do not vary
/// alike. A working machine sits at 60% memory and 70% disk all day while its
/// CPU moves between 2% and 90%, so at equal weight every tile on a screen
/// would be two thirds full before anything happened, and the one thing that
/// changes would be the hardest part of the bar to see.
const kPressureShare = 0.5;

/// Everything a machine is carrying, as stretches of one bar.
///
/// A tile is 44 points and has room for one bar, so the question is which
/// reading gets it — and the answer is that none of them does. What a wall of
/// a hundred tiles is read for is which machine is under load, and one reading
/// cannot say that: a box at 4% CPU with a full disk is not idle.
///
/// The shares add up to how busy the machine is and may pass 1, which is a
/// machine carrying everything at once; the bar clips there. That is the
/// reading it deserves — full is full, and a view whose question is "which one
/// is under load" does not owe a distinction between loaded and more loaded.
///
/// A reading the machine does not report, or reports as a rate rather than a
/// share, takes no room: only a reading with a full to be a share *of* can be
/// a length here.
List<ServerPressureSegment> serverPressure(ServerCardReadings? readings) {
  const weights = {
    ServerMetricKind.cpu: 1.0,
    ServerMetricKind.mem: kPressureShare,
    ServerMetricKind.disk: kPressureShare,
  };

  final out = <ServerPressureSegment>[];
  for (final MapEntry(key: kind, value: weight) in weights.entries) {
    final m = readings?.all.firstWhereOrNull((m) => m.kind == kind);
    final percent = m?.percent;
    if (percent == null || percent <= 0) continue;
    out.add((
      share: percent.clamp(0.0, 1.0) * weight,
      kind: kind,
      over: m!.over,
    ));
  }
  return out;
}

/// The one slot that is not the same on every card.
///
/// Ranked the way someone scanning a list would rank it: whatever is over the
/// line first, because that is the reason this machine is worth a look; then
/// what this machine has and most do not, because a row saying the same thing
/// as its neighbours' is a row that could have been anything; and otherwise
/// what every machine has left over.
ServerMetric? _extra(List<ServerMetric> all, Set<ServerMetricKind> taken) {
  final free = all.where((m) => !taken.contains(m.kind)).toList();
  if (free.isEmpty) return null;

  if (free.firstWhereOrNull((m) => m.over) case final over?) return over;

  const rare = [
    ServerMetricKind.gpu,
    ServerMetricKind.battery,
    ServerMetricKind.temp,
  ];
  for (final kind in rare) {
    if (free.firstWhereOrNull((m) => m.kind == kind) case final m?) return m;
  }

  const common = [ServerMetricKind.diskIo, ServerMetricKind.swap];
  for (final kind in common) {
    if (free.firstWhereOrNull((m) => m.kind == kind) case final m?) return m;
  }
  return free.first;
}

String _pct(double? v) => v == null ? '--' : '${(v * 10).round() / 10}%';
String _rate(double? bytesPerSec) =>
    bytesPerSec == null ? '--' : '${bytesPerSec.bytes2Str}/s';

/// The same three the detail page's axis is labelled with, because the card's
/// axis is the one it grows into.
String _rateOf(double v) => '${v.bytes2Str}/s';
String _formatTemp(double v) =>
    '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}°C';

List<ServerMetric> _readings(ServerState srv) {
  final ss = srv.status;
  final h = ss.history;
  final times = h.time.toList();
  final out = <ServerMetric>[];

  // Always present, even before the first sample: every machine has a CPU, so
  // an absent row would say this one does not rather than that nothing has
  // been measured yet — which is what the dash says.
  final cpu = ss.cpu.usedPercent(coreIdx: 0);
  out.add(
    ServerMetric(
      kind: ServerMetricKind.cpu,
      label: 'CPU',
      icon: ServerDetailCards.cpu.icon,
      value: _pct(cpu),
      note: ss.cpu.brand.keys.firstOrNull ?? '',
      bigNote: '${_pct(ss.cpu.idle)} idle',
      percent: cpu == null ? null : cpu / 100,
      samples: h.cpu.toList(),
      times: times,
      format: _pct,
    ),
  );

  if (ss.mem.total > 0) {
    final used = ss.mem.usedPercent * 100;
    out.add(
      ServerMetric(
        kind: ServerMetricKind.mem,
        label: libL10n.memory,
        icon: ServerDetailCards.mem.icon,
        value: _pct(used),
        note:
            '${((ss.mem.total - ss.mem.free) * 1024).bytes2Str} / '
            '${(ss.mem.total * 1024).bytes2Str}',
        bigNote: l10n.ofFmt((ss.mem.total * 1024).bytes2Str),
        percent: used / 100,
        samples: h.mem.toList(),
        times: times,
        format: _pct,
      ),
    );
  }

  if (ss.swap.total > 0) {
    final used = ss.swap.usedPercent * 100;
    out.add(
      ServerMetric(
        kind: ServerMetricKind.swap,
        label: 'Swap',
        icon: ServerDetailCards.swap.icon,
        value: _pct(used),
        note: l10n.ofFmt((ss.swap.total * 1024).bytes2Str),
        bigNote: l10n.ofFmt((ss.swap.total * 1024).bytes2Str),
        percent: used / 100,
        samples: h.swap.toList(),
        times: times,
        format: _pct,
      ),
    );
  }

  if (ss.disk.isNotEmpty) {
    final usage = ss.diskUsage ?? DiskUsage.parse(ss.disk);
    final used = usage.usedPercent;
    out.add(
      ServerMetric(
        kind: ServerMetricKind.disk,
        label: libL10n.disk,
        icon: ServerDetailCards.disk.icon,
        value: _pct(used),
        note: '${usage.used.kb2Str} / ${usage.size.kb2Str}',
        bigNote: l10n.ofFmt(usage.size.kb2Str),
        percent: used / 100,
        samples: h.disk.toList(),
        times: times,
        format: _pct,
      ),
    );
  }

  final (read, write) = ss.diskIO.allSpeedBytes;
  if (read != null || write != null) {
    out.add(
      ServerMetric(
        kind: ServerMetricKind.diskIo,
        label: l10n.diskIo,
        icon: MingCute.transfer_3_line,
        value: _rate(write),
        note: '${_rate(read)} ${l10n.read}',
        bigNote: '${l10n.write} · ${_rate(read)} ${l10n.read}',
        samples: h.diskWrite.toList(),
        times: times,
        format: _rateOf,
        binary: true,
      ),
    );
  }

  final ns = ss.netSpeed;
  if (ns.devices.isNotEmpty) {
    final rx = ns.speedInBytesOf();
    final tx = ns.speedOutBytesOf();
    out.add(
      ServerMetric(
        kind: ServerMetricKind.net,
        label: libL10n.net,
        icon: ServerDetailCards.net.icon,
        value: _rate(tx),
        note: '↓ ${_rate(rx)} · ↑ ${_rate(tx)}',
        bigNote: '↑ · ${_rate(rx)} ↓',
        samples: h.netTx.toList(),
        times: times,
        format: _rateOf,
        binary: true,
      ),
    );
  }

  if (_busiestGpu(ss) case final gpu?) {
    final used = gpu.utilization;
    out.add(
      ServerMetric(
        kind: ServerMetricKind.gpu,
        label: 'GPU',
        icon: ServerDetailCards.gpu.icon,
        value: _pct(used),
        note: gpu.name,
        bigNote: gpu.name,
        percent: used == null ? null : used / 100,
        samples: h.gpu.toList(),
        times: times,
        format: _pct,
      ),
    );
  }

  if (_hottest(ss) case (final sensor, final celsius)) {
    out.add(
      ServerMetric(
        kind: ServerMetricKind.temp,
        label: libL10n.temperature,
        icon: ServerDetailCards.temp.icon,
        value: '${celsius.toStringAsFixed(1)}°C',
        note: sensor,
        bigNote: sensor,
        samples: h.temp.toList(),
        times: times,
        format: _formatTemp,
      ),
    );
  }

  // The first battery, not every one: a laptop has one, and a host reporting
  // several is reporting its mouse and its keyboard.
  if (ss.batteries.firstOrNull case final battery?) {
    final percent = battery.percent?.toDouble();
    out.add(
      ServerMetric(
        kind: ServerMetricKind.battery,
        label: libL10n.battery,
        icon: ServerDetailCards.battery.icon,
        value: _pct(percent),
        note: [battery.status.name, ?battery.name].join(' · '),
        bigNote: battery.status.name,
        percent: percent == null ? null : percent / 100,
        samples: h.battery.toList(),
        times: times,
        format: _pct,
      ),
    );
  }

  return out;
}

GpuItem? _busiestGpu(ServerStatus ss) {
  GpuItem? top;
  for (final gpu in ss.gpus) {
    if (top == null || (gpu.utilization ?? -1) > (top.utilization ?? -1)) {
      top = gpu;
    }
  }
  return top;
}

/// The hottest sensor, which is the one that will be a problem.
(String, double)? _hottest(ServerStatus ss) {
  String? name;
  double? top;
  for (final device in ss.temps.devices) {
    final value = ss.temps.get(device);
    if (value == null) continue;
    if (top == null || value > top) {
      name = device;
      top = value;
    }
  }
  return name == null || top == null ? null : (name, top);
}
