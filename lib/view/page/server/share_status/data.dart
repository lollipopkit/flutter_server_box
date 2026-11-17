import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/status/disk.dart';
import 'package:server_box/data/model/server/status/disk_smart.dart';
import 'package:server_box/data/model/server/status/net_speed.dart';
import 'package:server_box/data/provider/server/metric.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/detail/metric_model.dart';
import 'package:server_box/view/page/server/state_ui.dart';

/// What a poster can carry, in the order it carries them.
enum PosterSection {
  cpu(ServerDetailCards.cpu),
  mem(ServerDetailCards.mem),
  swap(ServerDetailCards.swap),
  gpu(ServerDetailCards.gpu),
  disk(ServerDetailCards.disk),
  smart(ServerDetailCards.smart),
  temp(ServerDetailCards.temp),
  net(ServerDetailCards.net),
  sensor(ServerDetailCards.sensor),
  battery(ServerDetailCards.battery);

  const PosterSection(this.card);

  /// The detail page's card for the same reading.
  final ServerDetailCards card;

  IconData get icon => card.icon;

  /// Drawn half the poster's width, two side by side; one with no half-width
  /// neighbour takes the whole row.
  bool get half => switch (this) {
    mem || swap || smart || temp || battery => true,
    _ => false,
  };

  String get label => switch (this) {
    cpu => 'CPU',
    mem => libL10n.memory,
    swap => 'Swap',
    gpu => 'GPU',
    disk => libL10n.disk,
    smart => l10n.diskHealth,
    temp => libL10n.temperature,
    net => libL10n.net,
    sensor => libL10n.sensors,
    battery => libL10n.battery,
  };

  /// Off until picked: the hottest sensor is [temp] already.
  static const offByDefault = {sensor};
}

/// One line of a list section: a name and what it reads.
typedef PosterRow = ({String name, String value, double? percent});

/// Everything a poster says, worked out once from a server's state and the
/// window it covers. A section the machine does not report is absent.
class StatusPoster {
  StatusPoster._({
    required this.name,
    required this.system,
    required this.line,
    required this.at,
    required this.sections,
  });

  final String name;

  /// What the machine says it runs, null when it has not said.
  final String? system;

  /// Temperature and uptime, as the server list shows them.
  final String? line;
  final DateTime at;
  final Map<PosterSection, PosterBlock> sections;

  /// [live] whether [w] is what this app watched now; a stored window's
  /// figures are the window's, and a series it does not carry leaves its
  /// section out rather than reading the machine's present.
  factory StatusPoster.of(
    ServerState srv,
    MetricWindow w, {
    DateTime? at,
    bool live = true,
  }) {
    final ss = srv.status;
    final sections = <PosterSection, PosterBlock>{};
    if (!serverNeverSampled(srv)) {
      sections[PosterSection.cpu] = _cpu(srv, w, live);
      if (_mem(srv, w, live) case final b?) sections[PosterSection.mem] = b;
      if (_swap(srv, w, live) case final b?) sections[PosterSection.swap] = b;
      if (_gpu(srv, w, live) case final b?) sections[PosterSection.gpu] = b;
      if (_disk(srv, w, live) case final b?) sections[PosterSection.disk] = b;
      if (_smart(ss.diskSmart) case final b?) sections[PosterSection.smart] = b;
      if (_temp(srv, w, live) case final b?) sections[PosterSection.temp] = b;
      if (_net(srv, w, live) case final b?) sections[PosterSection.net] = b;
      if (_sensors(srv, w, live) case final b?) {
        sections[PosterSection.sensor] = b;
      }
      if (_battery(srv, w, live) case final b?) sections[PosterSection.battery] = b;
    }
    return StatusPoster._(
      name: srv.spi.name,
      system: ss.more[StatusCmdType.sys],
      line: srv.listLine,
      at: at ?? DateTime.now(),
      sections: sections,
    );
  }

  /// The poster as text: a line a section, as a chat message carries it.
  String summary({
    required Iterable<PosterSection> shown,
    required String range,
    required bool hideName,
    required bool hideSystem,
  }) {
    final lines = [
      '${hideName ? libL10n.server : name} · $range',
      if (!hideSystem && system != null) system!,
      ?line,
      for (final s in PosterSection.values)
        if (shown.contains(s))
          if (sections[s] case final b?) '${s.label} ${b.summary}',
      '— ServerBox',
    ];
    return lines.join('\n');
  }
}

/// One section: a headline, what it is of, and whatever is drawn under it.
class PosterBlock {
  const PosterBlock({
    required this.value,
    required this.summary,
    this.title,
    this.aside,
    this.note,
    this.percent,
    this.bars = const [],
    this.rows = const [],
    this.chart,
    this.pair,
  });

  /// Beside the section's name, where the name alone says too little.
  final String? title;

  /// At the right of the heading: a peak, a rate.
  final String? aside;

  final String value;

  /// Under the value.
  final String? note;

  /// 0-1, for a bar under the value.
  final double? percent;

  /// 0-1 each: the CPU's cores.
  final List<double> bars;

  final List<PosterRow> rows;
  final MetricChartSpec? chart;

  /// Two figures side by side in place of [value]: the network's directions.
  final ({PosterRow a, PosterRow b})? pair;

  /// The section as one line of text.
  final String summary;
}

double? _avg(List<double?> values) {
  var sum = 0.0;
  var n = 0;
  for (final v in values) {
    if (v == null) continue;
    sum += v;
    n++;
  }
  return n == 0 ? null : sum / n;
}

double? _peak(List<double?> values) {
  double? top;
  for (final v in values) {
    if (v != null && (top == null || v > top)) top = v;
  }
  return top;
}

PosterBlock _cpu(ServerState srv, MetricWindow w, bool live) {
  final ss = srv.status;
  final avg = _avg(w.cpu) ?? (live ? ss.cpu.usedPercent() : null);
  final peak = _peak(w.cpu);
  final cores = ss.cpu.coresCount;
  final title = [
    ?ss.cpu.brandLabel,
    if (cores > 0) '$cores ${l10n.cores}',
  ].join(' · ');
  return PosterBlock(
    title: title.isEmpty ? null : title,
    aside: peak == null ? null : '${l10n.peak} ${ReadingFmt.pct(peak)}',
    value: ReadingFmt.pct(avg),
    note: avg == null ? null : l10n.average,
    // Each core now, which a stored window does not hold.
    bars: live ? _cores(ss, cores) : const [],
    chart: _chart(
      w,
      [HistorySeries('CPU', ChartPalette.accent, w.cpu)],
      ReadingFmt.pct,
    ),
    summary: [
      '${l10n.average} ${ReadingFmt.pct(avg)}',
      if (peak != null) '${l10n.peak} ${ReadingFmt.pct(peak)}',
    ].join(' · '),
  );
}

/// Each core's load now, or none when any core has no reading: a missing
/// one drawn empty would read as an idle core.
List<double> _cores(ServerStatus ss, int count) {
  final loads = <double>[];
  for (var i = 1; i <= count; i++) {
    final load = ss.cpu.usedPercent(coreIdx: i);
    if (load == null) return const [];
    loads.add(load / 100);
  }
  return loads;
}

PosterBlock? _mem(ServerState srv, MetricWindow w, bool live) {
  final mem = srv.status.mem;
  final now = mem.usedPercent;
  if (now == null) return null;
  if (!live) return _stored(_avg(w.mem));
  final total = (mem.total * 1024).bytes2Str;
  final used = (mem.used * 1024).bytes2Str;
  return PosterBlock(
    value: used,
    note: '${l10n.ofFmt(total)} · ${ReadingFmt.pct(now * 100)}',
    percent: now,
    summary: '$used / $total',
  );
}

PosterBlock? _swap(ServerState srv, MetricWindow w, bool live) {
  // A swap turned off since the window still happened: history, not the
  // presence of one now, is what a stored range is of.
  if (!live) return _stored(_avg(w.swap));
  final swap = srv.status.swap;
  if (swap.total <= 0) return null;
  final total = (swap.total * 1024).bytes2Str;
  final used = ((swap.total - swap.free) * 1024).bytes2Str;
  return PosterBlock(
    value: used,
    note: '${l10n.ofFmt(total)} · ${ReadingFmt.pct(swap.usedPercent * 100)}',
    percent: swap.usedPercent,
    summary: '$used / $total',
  );
}

/// A stored window's reading, as the window averaged it.
///
/// A percentage only: the window does not record the capacity it was of, and
/// bytes worked out from today's would name a figure it never held. Null when
/// the window carries no series for it at all.
PosterBlock? _stored(
  double? avg, {
  double? peak,
  String Function(double)? format,
  bool percent = true,
}) {
  if (avg == null) return null;
  final fmt = format ?? ReadingFmt.pct;
  return PosterBlock(
    value: fmt(avg),
    note: l10n.average,
    aside: peak == null ? null : '${l10n.peak} ${fmt(peak)}',
    percent: percent ? avg / 100 : null,
    summary: [
      '${l10n.average} ${fmt(avg)}',
      if (peak != null) '${l10n.peak} ${fmt(peak)}',
    ].join(' · '),
  );
}

PosterBlock? _gpu(ServerState srv, MetricWindow w, bool live) {
  if (!live) {
    if (w.gpus.isNotEmpty) {
      var best = w.gpus.first;
      for (final g in w.gpus.skip(1)) {
        if ((g.usagePercent ?? -1) > (best.usagePercent ?? -1)) best = g;
      }
      final avg = best.usagePercent ?? _avg(w.gpu);
      final peak = _peak(w.gpu);
      final memText = best.memoryUsed != null && best.memoryTotal != null
          ? '${best.memoryUsed} / ${best.memoryTotal} MiB'
          : null;
      final noteParts = [
        if (avg != null) l10n.average,
        if (memText != null) '${libL10n.memory} $memText',
      ];
      return PosterBlock(
        title: best.name,
        aside: peak == null ? null : '${l10n.peak} ${ReadingFmt.pct(peak)}',
        value: ReadingFmt.pct(avg),
        percent: avg == null ? null : avg / 100,
        note: noteParts.isEmpty ? null : noteParts.join(' · '),
        summary: [
          best.name,
          if (avg != null) '${l10n.average} ${ReadingFmt.pct(avg)}',
          if (peak != null) '${l10n.peak} ${ReadingFmt.pct(peak)}',
          if (memText != null) '${libL10n.memory} $memText',
        ].join(' · '),
      );
    }
    final avg = _avg(w.gpu);
    if (avg == null) return null;
    return _stored(avg, peak: _peak(w.gpu));
  }
  final gpu = busiestGpu(srv.status);
  if (gpu == null) return null;
  final mem = gpu.memory;
  final aside = [
    if (gpu.temperature case final t?) ReadingFmt.temp(t.toDouble()),
    ?gpu.power,
  ].join(' · ');
  final memText = mem == null ? null : '${mem.used} / ${mem.total} ${mem.unit}';
  return PosterBlock(
    title: gpu.name,
    aside: aside.isEmpty ? null : aside,
    value: ReadingFmt.pct(gpu.utilization),
    percent: gpu.utilization == null ? null : gpu.utilization! / 100,
    note: memText == null ? null : '${libL10n.memory} $memText',
    summary: [
      '${gpu.name} ${ReadingFmt.pct(gpu.utilization)}',
      if (memText != null) '${libL10n.memory} $memText',
    ].join(' · '),
  );
}

/// The mounted filesystems, largest first: a list of every bind mount and
/// snap loop device is not what a reader of a poster is after.
PosterBlock? _disk(ServerState srv, MetricWindow w, bool live) {
  if (!live) {
    final valid = [
      for (final m in w.mounts)
        if (m.mount.isNotEmpty &&
            m.total > 0 &&
            Disk(
              path: m.mount,
              mount: m.mount,
              usedPercent: 0,
              used: BigInt.zero,
              size: BigInt.from(m.total ~/ 1024),
              avail: BigInt.zero,
            ).isStorage)
          m,
    ]..sort((a, b) => b.total.compareTo(a.total));
    if (valid.isNotEmpty) {
      final readAvg = _avg(w.diskRead);
      final writeAvg = _avg(w.diskWrite);
      final top = valid.take(4).toList();
      final rows = [
        for (final d in top)
          (
            name: d.mount,
            value:
                '${d.used.bytes2Str} / ${d.total.bytes2Str} · ${(d.used * 100 / d.total).round()}%',
            percent: (d.used / d.total).clamp(0.0, 1.0),
          ),
      ];
      return PosterBlock(
        aside: readAvg == null && writeAvg == null
            ? null
            : '${l10n.read} ${ReadingFmt.rate(readAvg)} · ${l10n.write} ${ReadingFmt.rate(writeAvg)}',
        value: '',
        rows: rows,
        summary: [
          for (final d in top) '${d.mount} ${(d.used * 100 / d.total).round()}%',
        ].join(', '),
      );
    }
    return _stored(_avg(w.disk), peak: _peak(w.disk));
  }
  final ss = srv.status;
  final mounted = <String, Disk>{};
  void walk(Iterable<Disk> disks) {
    for (final d in disks) {
      if (d.mount.isNotEmpty && d.size > BigInt.zero) {
        mounted.putIfAbsent(d.mount, () => d);
      }
      walk(d.children);
    }
  }

  walk(ss.disk);
  if (mounted.isEmpty) return null;
  final disks = mounted.values.toList()..sort((a, b) => b.size.compareTo(a.size));
  final (read, write) = ss.diskIO.allSpeedBytes;
  final rows = [
    for (final d in disks.take(4))
      (
        name: d.mount,
        value: '${d.used.kb2Str} / ${d.size.kb2Str} · ${d.usedPercent}%',
        percent: d.usedPercent / 100,
      ),
  ];
  return PosterBlock(
    aside: read == null && write == null
        ? null
        : '${l10n.read} ${ReadingFmt.rate(read)} · ${l10n.write} ${ReadingFmt.rate(write)}',
    value: '',
    rows: rows,
    summary: [
      for (final d in disks.take(4)) '${d.mount} ${d.usedPercent}%',
    ].join(', '),
  );
}

PosterBlock? _smart(List<DiskSmart> smarts) {
  // A disk that cannot answer SMART has said nothing, not passed.
  final applicable = smarts.where((e) => !e.notApplicable).toList();
  if (applicable.isEmpty) return null;
  final failing = applicable.where((e) => e.healthy == false).length;
  final warning = applicable
      .where((e) => e.healthy == null || e.faults.isNotEmpty)
      .length;
  final verdict = failing > 0
      ? l10n.diskFailingFmt(failing)
      : warning > 0
      ? l10n.diskWarningFmt(warning)
      : l10n.diskAllPassed;
  final first = applicable.first;
  final note = [
    if (applicable.length > 1)
      l10n.devicesFmt(applicable.length)
    else
      first.device,
    if (applicable.length == 1)
      if (first.powerOnHours case final h?) '${l10n.powerOnHours} $h h',
  ].join(' · ');
  return PosterBlock(value: verdict, note: note, summary: verdict);
}

PosterBlock? _temp(ServerState srv, MetricWindow w, bool live) {
  if (!live) {
    if (w.tempsByDevice.isNotEmpty) {
      String? hottestName;
      double? hottestAvg;
      for (final MapEntry(:key, :value) in w.tempsByDevice.entries) {
        final avg = _avg(value);
        if (avg != null && (hottestAvg == null || avg > hottestAvg)) {
          hottestName = key;
          hottestAvg = avg;
        }
      }
      if (hottestName != null && hottestAvg != null) {
        final peak =
            _peak(w.tempsByDevice[hottestName]!) ?? _peak(w.temp) ?? hottestAvg;
        return PosterBlock(
          value: ReadingFmt.temp(hottestAvg),
          note: [
            hottestName,
            l10n.average,
            '${l10n.peak} ${ReadingFmt.temp(peak)}',
          ].join(' · '),
          summary: '$hottestName ${l10n.average} ${ReadingFmt.temp(hottestAvg)}',
        );
      }
    }
    return _stored(
      _avg(w.temp),
      peak: _peak(w.temp),
      format: ReadingFmt.temp,
      percent: false,
    );
  }
  final hottest = hottestSensor(srv.status);
  if (hottest == null) return null;
  final (sensor, celsius) = hottest;
  final peak = _peak(w.temp);
  return PosterBlock(
    value: ReadingFmt.temp(celsius),
    note: [
      sensor,
      if (peak != null) '${l10n.peak} ${ReadingFmt.temp(peak)}',
    ].join(' · '),
    summary: '$sensor ${ReadingFmt.temp(celsius)}',
  );
}

PosterBlock? _net(ServerState srv, MetricWindow w, bool live) {
  final ns = srv.status.netSpeed;
  if (live && ns.devices.isEmpty) return null;
  if (!live &&
      w.netRx.every((v) => v == null) &&
      w.netTx.every((v) => v == null)) {
    return null;
  }
  final rx = cumulativeBytes(w.times, w.netRx).lastWhereOrNull((v) => v != null);
  final tx = cumulativeBytes(w.times, w.netTx).lastWhereOrNull((v) => v != null);
  final rxPeak = _peak(w.netRx);
  final txPeak = _peak(w.netTx);
  final ifaces = live
      ? ns.realIfaces
      : _storedRealIfaces(w);
  return PosterBlock(
    title: ifaces.length == 1 ? ifaces.first : null,
    value: '',
    pair: (
      a: (
        name: '↓ ${l10n.peak} ${ReadingFmt.rate(rxPeak)}',
        value: ReadingFmt.size(rx),
        percent: null,
      ),
      b: (
        name: '↑ ${l10n.peak} ${ReadingFmt.rate(txPeak)}',
        value: ReadingFmt.size(tx),
        percent: null,
      ),
    ),
    chart: _chart(w, [
      HistorySeries('↓', ChartPalette.lines[1], w.netRx),
      HistorySeries('↑', ChartPalette.lines[0], w.netTx),
    ], ReadingFmt.rateAxis, binary: true),
    summary: '↓ ${ReadingFmt.size(rx)} ↑ ${ReadingFmt.size(tx)}',
  );
}

List<String> _storedRealIfaces(MetricWindow w) {
  final all = {
    ...w.netRxByDevice.keys,
    ...w.netTxByDevice.keys,
  }.where((d) => !NetSpeed.isLoopback(d)).toList();
  final real = all
      .where((d) => NetSpeed.realIfacePrefixs.any((p) => d.startsWith(p)))
      .toList();
  return real.isNotEmpty ? real : all;
}

PosterBlock? _sensors(ServerState srv, MetricWindow w, bool live) {
  if (!live) {
    if (w.tempsByDevice.isEmpty) return null;
    final entries = <({String name, double avg})>[];
    for (final MapEntry(:key, :value) in w.tempsByDevice.entries) {
      if (_avg(value) case final avg?) {
        entries.add((name: key, avg: avg));
      }
    }
    if (entries.isEmpty) return null;
    entries.sort((a, b) => b.avg.compareTo(a.avg));
    final shown = [
      for (final e in entries.take(6))
        (name: e.name, value: ReadingFmt.temp(e.avg), percent: null),
    ];
    return PosterBlock(
      value: '',
      rows: shown,
      summary: shown.map((r) => '${r.name} ${r.value}').join(', '),
    );
  }
  final rows = [
    for (final s in srv.status.sensors)
      if (s.summary case final v? when v.isNotEmpty)
        (name: s.device, value: v, percent: null),
  ];
  if (rows.isEmpty) return null;
  final shown = rows.take(6).toList();
  return PosterBlock(
    value: '',
    rows: shown,
    summary: shown.map((r) => '${r.name} ${r.value}').join(', '),
  );
}

PosterBlock? _battery(ServerState srv, MetricWindow w, bool live) {
  if (!live) {
    final avg = _avg(w.battery);
    if (avg == null) return null;
    return _stored(avg, peak: _peak(w.battery));
  }
  final battery = srv.status.batteries.firstOrNull;
  if (battery == null) return null;
  final percent = battery.percent?.toDouble();
  return PosterBlock(
    value: ReadingFmt.pct(percent),
    note: battery.status.name,
    percent: percent == null ? null : percent / 100,
    summary: '${ReadingFmt.pct(percent)} ${battery.status.name}',
  );
}

MetricChartSpec? _chart(
  MetricWindow w,
  List<HistorySeries> series,
  String Function(double) format, {
  bool binary = false,
}) {
  final spec = MetricChartSpec(
    series: series,
    format: format,
    times: w.times,
    binaryScale: binary,
    // Two or three ticks: at less the axis labels touch.
    height: 90,
  );
  return spec.hasData ? spec : null;
}
