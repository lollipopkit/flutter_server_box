import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_result.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/view/page/benchmark/log_view.dart';
import 'package:server_box/view/page/benchmark/status_mark.dart';

/// One benchmark's numbers.
///
/// Stateful because a run can still be going when this is opened: the history
/// lists a run from the moment it starts, so tapping one leads here while it is
/// three minutes into fio. The record handed in is a snapshot, and a snapshot
/// of a running benchmark has an empty log, no result, and an elapsed time that
/// stopped the instant the page was built.
class BenchmarkResultPage extends StatefulWidget {
  const BenchmarkResultPage({super.key, required this.args});

  final BenchmarkRun args;

  static const route = AppRouteArg<void, BenchmarkRun>(
    page: BenchmarkResultPage.new,
    path: '/benchmark/result',
  );

  @override
  State<BenchmarkResultPage> createState() => _BenchmarkResultPageState();
}

class _BenchmarkResultPageState extends State<BenchmarkResultPage> {
  late BenchmarkRun _run = widget.args;
  Timer? _tick;

  YabsResult? get _result => _run.result;

  @override
  void initState() {
    super.initState();
    if (_run.status == BenchmarkStatus.running) _startTicking();
  }

  /// Re-reads the record every second while the run is going.
  ///
  /// Re-reads rather than merely redrawing: the poll that drives the run writes
  /// through the store, so the log and the eventual result arrive there. A
  /// timer that only called `setState` would tick an elapsed clock over a log
  /// that never filled in.
  void _startTicking() {
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final fresh = Stores.benchmark.get(_run.id);
      if (!mounted) return;
      setState(() => _run = fresh ?? _run);
      if (_run.status.isTerminal) {
        _tick?.cancel();
        _tick = null;
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(_run.startedAt.ymdhms()),
        actions: [
          Btn.icon(
            icon: const Icon(Icons.copy, size: 18),
            text: libL10n.copy,
            onTap: () => _copy(context, _run.resultJson ?? _run.log),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final result = _result;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      children: [
        _summaryCard(),
        if (_run.error.isNotEmpty) _errorCard(context, _run.error),
        if (result == null)
          // Either nothing was produced, or yabs assembled a document no parser
          // accepts. The log is still the whole of what happened, so the page
          // shows that rather than an empty screen.
          _card(
            title: l10n.benchmarkRawLog,
            children: [
              if (_run.hasResult)
                Text(l10n.benchmarkResultUnreadable, style: UIs.text12Grey),
              UIs.height7,
              // The JSON is data and stays plain; a log is terminal output and
              // is unreadable as anything else — see `BenchmarkLogView`.
              if (_run.hasResult)
                _mono(context, _run.resultJson!)
              else
                BenchmarkLogView(log: _run.log, height: 320),
            ],
          )
        else ...[
          _systemCard(result),
          if (result.fio.isNotEmpty) _diskCard(context, result),
          if (result.iperf.isNotEmpty) _networkCard(result),
          if (result.geekbench.isNotEmpty) _cpuCard(context, result),
          if (result.ipInfo case final info?) _ipCard(info),
          if (_run.log.isNotEmpty)
            _card(
              title: l10n.benchmarkRawLog,
              children: [BenchmarkLogView(log: _run.log, height: 320)],
            ),
        ],
        UIs.height13,
      ],
    );
  }
}

/// Digits of one width, so a column of figures lines up and a value that is
/// still being polled does not shift its neighbours.
const _tabular = [FontFeature.tabularFigures()];
const _tabular12 = TextStyle(fontSize: 12, fontFeatures: _tabular);

// --- Sections ---

extension _Sections on _BenchmarkResultPageState {
  /// What this run is, how long it has taken, and whether it is still going.
  ///
  /// The elapsed time was on the configuration page's running card and nowhere
  /// else, so a run reached through the history — the only way to reach one
  /// that has already finished — said nothing about how long it took.
  Widget _summaryCard() {
    final (icon, color, label) = _run.status.mark(
      Theme.of(context).colorScheme,
    );
    // yabs times itself, and its figure is the one to show when there is one:
    // it measures the benchmark rather than the round trip that started it.
    final reported = _result?.runtime?.elapsed;
    final elapsed = reported == null
        ? _run.elapsed
        : Duration(seconds: reported);

    return _card(
      title: label,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 17),
            UIs.width13,
            Expanded(
              child: Text(
                fmtDuration(elapsed),
                style: UIs.text15.copyWith(fontFeatures: _tabular),
              ),
            ),
            if (_run.status == BenchmarkStatus.running)
              const SizedLoading(
                15,
                padding: 0,
                builder: SizedLoading.circularBuilder,
              ),
          ],
        ),
        UIs.height7,
        _kv(libL10n.start, _run.startedAt.ymdhms()),
        if (_run.finishedAt case final at?) _kv(libL10n.done, at.ymdhms()),
        if (_run.exitCode case final code?) _kv('Exit', '$code'),
      ],
    );
  }

  Widget _systemCard(YabsResult r) {
    final mem = r.mem;
    return _card(
      title: libL10n.system,
      children: [
        _kv('CPU', r.cpu.model),
        _kv(
          libL10n.total,
          [
            if (r.cpu.cores case final c?) '$c core',
            if (r.cpu.freq.isNotEmpty) '${r.cpu.freq} MHz',
          ].join(' @ '),
        ),
        _kv(
          'AES-NI / ${l10n.benchmarkVirt}',
          '${_yn(r.cpu.aes)} / ${_yn(r.cpu.virt)}',
        ),
        _kv(libL10n.memory, _size(mem.ramBytes)),
        if ((mem.swap ?? 0) > 0) _kv('Swap', _size(mem.swapBytes)),
        _kv(libL10n.disk, _size(mem.diskBytes)),
        _kv('OS', r.os.distro),
        _kv('Kernel', r.os.kernel),
        _kv('Arch', r.os.arch),
        if (r.os.vm.isNotEmpty) _kv(l10n.benchmarkVirt, r.os.vm),
        if (r.os.uptime case final u?)
          _kv(libL10n.uptime, '${(u / 86400).toStringAsFixed(1)} d'),
        _kv('IPv4 / IPv6', '${_yn(r.net.ipv4)} / ${_yn(r.net.ipv6)}'),
      ],
    );
  }

  /// fio, as a grouped bar per block size.
  ///
  /// A chart rather than the table yabs prints, because the shape is the
  /// finding: a disk that is fast at 1M and slow at 4k is a different disk from
  /// one that is even across the range, and that is invisible in four rows of
  /// numbers.
  Widget _diskCard(BuildContext context, YabsResult r) {
    final rows = r.fio;
    final maxRate = rows
        .map((e) => e.totalBytesPerSec ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxRate <= 0 ? 1.0 : maxRate * 1.2;

    return _card(
      title: '${libL10n.disk} (fio)',
      subtitle: r.partition,
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, _) {
                    final font = Theme.of(context).textTheme.bodyMedium;
                    return BarTooltipItem(
                      '${rows[group.x].bs}\n${_rate(rod.toY)}',
                      // Only the families come from the theme. A tooltip is
                      // 12pt, and the rest of `bodyMedium` is a 14pt body's:
                      // its line height (1.43) and tracking (0.25) spread the
                      // two rows of the label apart.
                      UIs.text12.copyWith(
                        fontFamily: font?.fontFamily,
                        fontFamilyFallback: font?.fontFamilyFallback,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    // Wide enough for the longest label this axis can produce,
                    // and an interval that keeps them apart. At 46 with no
                    // interval, `647.3 MB/s` wrapped to two lines and each
                    // label ran into the one above and below it.
                    reservedSize: 58,
                    interval: (maxY <= 0 ? 1 : maxY) / 4,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        _axisRate(value),
                        style: UIs.text11Grey,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= rows.length) return UIs.placeholder;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(rows[idx].bs, style: UIs.text11Grey),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < rows.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: rows[i].readBytesPerSec ?? 0,
                        color: ChartPalette.diskRead,
                        width: 7,
                      ),
                      BarChartRodData(
                        toY: rows[i].writeBytesPerSec ?? 0,
                        color: ChartPalette.diskWrite,
                        width: 7,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        UIs.height13,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(ChartPalette.diskRead, libL10n.read),
            UIs.width13,
            _legend(ChartPalette.diskWrite, libL10n.write),
          ],
        ),
        UIs.height13,
        // The IOPS figures matter as much as the rates at small block sizes and
        // cannot share the axis with them, so they stay a table.
        for (final row in rows)
          _kv(
            '${row.bs} ${l10n.benchmarkIops}',
            '${_n(row.iopsRead)} / ${_n(row.iopsWrite)}',
          ),
      ],
    );
  }

  Widget _networkCard(YabsResult r) {
    // Grouped by address family: a host can be fast on one and unusable on the
    // other, and averaging them together would hide exactly that.
    final byMode = <String, List<YabsIperf>>{};
    for (final row in r.iperf) {
      byMode.putIfAbsent(row.mode, () => []).add(row);
    }

    return _card(
      title: '${libL10n.network} (iperf3)',
      children: [
        for (final entry in byMode.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 7, bottom: 3),
            child: Text(entry.key, style: UIs.text13Bold),
          ),
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                child: Text(
                  l10n.benchmarkSend,
                  style: UIs.text11Grey,
                  textAlign: TextAlign.end,
                ),
              ),
              Expanded(
                child: Text(
                  l10n.benchmarkRecv,
                  style: UIs.text11Grey,
                  textAlign: TextAlign.end,
                ),
              ),
              Expanded(
                child: Text(
                  l10n.benchmarkLatency,
                  style: UIs.text11Grey,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          for (final row in entry.value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.loc,
                      style: UIs.text12,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.send,
                      style: _tabular12,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.recv,
                      style: _tabular12,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.latency,
                      style: _tabular12.copyWith(color: Colors.grey),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _cpuCard(BuildContext context, YabsResult r) {
    return _card(
      title: 'CPU (Geekbench)',
      children: [
        for (final gb in r.geekbench) ...[
          Row(
            children: [
              Expanded(
                child: _score(l10n.benchmarkSingleCore, gb.single),
              ),
              Expanded(
                child: _score(l10n.benchmarkMultiCore, gb.multi),
              ),
            ],
          ),
          if (gb.url.isNotEmpty) ...[
            UIs.height7,
            // The result is on a public page whether or not this app links to
            // it. Linking, and saying so, is the only version of that the user
            // can act on.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.benchmarkViewOnGeekbench),
                onPressed: () => gb.url.launchUrl(),
              ),
            ),
            Text(l10n.benchmarkGeekbenchPublic, style: UIs.text12Grey),
          ],
        ],
      ],
    );
  }

  Widget _score(String label, int? value) {
    return Column(
      children: [
        // The one big figure this card leads with.
        Text(
          value?.toString() ?? libL10n.notAvailable,
          style: UIs.text27.copyWith(fontFeatures: _tabular),
        ),
        Text(label, style: UIs.text12Grey),
      ],
    );
  }

  Widget _ipCard(YabsIpInfo info) {
    return _card(
      title: libL10n.location,
      children: [
        _kv('ISP', info.isp),
        _kv('ASN', info.asn),
        _kv('Org', info.org),
        _kv(
          libL10n.location,
          [info.city, info.region, info.country]
              .where((e) => e.isNotEmpty)
              .join(', '),
        ),
      ],
    );
  }
}

// --- Building blocks ---

extension _Parts on _BenchmarkResultPageState {
  Widget _card({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return CardX(
      child: Padding(
        // A titled block: 17 either side, 13 above and below.
        padding: UIs.roundRectCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: UIs.text15Bold),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(subtitle, style: UIs.text12Grey),
            UIs.height7,
            ...children,
          ],
        ),
      ),
    );
  }

  /// The ground of a persistent error block: the error container, so the
  /// message is read on a tone made for it rather than as red text on a card.
  Widget _errorCard(BuildContext context, String error) {
    final scheme = Theme.of(context).colorScheme;
    return CardX(
      color: scheme.errorContainer,
      child: Padding(
        padding: UIs.roundRectCardPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            UIs.width13,
            Expanded(
              child: SelectableText(
                error,
                style: UIs.text13.copyWith(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    if (value.trim().isEmpty) return UIs.placeholder;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(key, style: UIs.text12Grey)),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              style: _tabular12,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UIs.dot(color: color, size: 9),
        UIs.width7,
        Text(label, style: UIs.text12Grey),
      ],
    );
  }

  Widget _mono(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }

  String _yn(bool v) => v ? '✓' : '✗';

  String _size(int? bytes) => bytes == null ? libL10n.unknown : bytes.bytes2Str;

  String _n(double? v) => v == null ? '-' : v.round().toString();

  /// Bytes per second, in full — what a tooltip shows, where there is room.
  String _rate(double bytesPerSec) => '${bytesPerSec.bytes2Str}/s';

  /// The same, shortened for an axis tick.
  ///
  /// `647.3 MB/s` is eleven characters and does not fit beside a chart this
  /// size. The fraction goes only above ten, where a gridline does not need a
  /// tenth of a megabyte and the tooltip has it anyway — below ten it has to
  /// stay, or `1.2 GB/s` and `1.8 GB/s` become two ticks both reading
  /// `1 GB/s`.
  String _axisRate(double bytesPerSec) {
    final full = bytesPerSec.bytes2Str;
    final parts = RegExp(r'^([\d.]+) (\w+)$').firstMatch(full);
    if (parts == null) return '$full/s';
    final value = double.tryParse(parts.group(1)!) ?? 0;
    final shown = value >= 10 ? value.round().toString() : parts.group(1)!;
    return '$shown ${parts.group(2)}/s';
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    Toast.show(libL10n.copy);
  }
}
