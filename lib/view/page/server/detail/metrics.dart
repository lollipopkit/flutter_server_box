part of 'view.dart';

/// How far back the chart looks.
///
/// [live] is what this app has watched happen since it connected — the one
/// window every server has, because it is kept here. The rest are asked of a
/// monitor agent, which is the only thing that stores anything.
enum _HistoryRange {
  live(null, 'live'),
  m5(5, '5m'),
  h1(60, '1h'),
  h6(360, '6h'),
  h24(1440, '24h'),
  d7(10080, '7d');

  const _HistoryRange(this.minutes, this._short);

  /// Null for [live]. The agent clamps this to 5 minutes … 7 days, which is
  /// what this list stays inside.
  final int? minutes;

  final String _short;

  String get label => this == live ? l10n.rangeLive : _short;

  /// The ones offered on the card itself. The rest are behind the picker,
  /// because a row of six chips is a row nobody reads.
  static const inline = [live, h1, h24];
}

/// One metric: a value now, a line over time, and — when it is the one being
/// read — whatever else the machine says about it.
enum _MetricKind { cpu, mem, swap, disk, diskIo, net }

typedef _Stat = ({String k, String v});

/// Everything the rows and the focus card draw, worked out once per build off
/// the same samples, so a row and the chart above it can never disagree.
class _MetricView {
  const _MetricView({
    required this.kind,
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.note,
    required this.bigNote,
    required this.series,
    required this.format,
    this.percent,
    this.stats = const [],
    this.binary = false,
  });

  final _MetricKind kind;
  final String label;
  final IconData icon;
  final Color color;

  /// The reading now, as the row and the headline both show it.
  final String value;

  /// What the row says beside the value: what the percentage is of, or the
  /// peak of the window for a rate.
  final String note;

  /// Beside the headline in the focus card.
  final String bigNote;

  /// 0-1 for a percentage metric, null for a rate: only the first kind has a
  /// bar, because only it has a full.
  final double? percent;

  final List<_Stat> stats;
  final List<_HistorySeries> series;
  final String Function(double) format;

  /// Whether the axis should step in multiples of 1024.
  final bool binary;

  bool get hasChart => series.any((s) => s.spots.isNotEmpty);
}

/// The values of every series over one window, whichever source they came
/// from: this app's rolling buffer, or the agent's store.
class _Window {
  const _Window({
    this.cpu = const [],
    this.mem = const [],
    this.swap = const [],
    this.disk = const [],
    this.diskRead = const [],
    this.diskWrite = const [],
    this.netRx = const [],
    this.netTx = const [],
  });

  /// What this app has seen, which is every series it can measure.
  factory _Window.live(StatusHistory h) => _Window(
    cpu: h.cpu,
    mem: h.mem,
    swap: h.swap,
    disk: h.disk,
    diskRead: h.diskRead,
    diskWrite: h.diskWrite,
    netRx: h.netRx,
    netTx: h.netTx,
  );

  /// What the agent stored. An agent too old to report a series leaves it
  /// empty here however long the window is — see [_MetricView.hasChart],
  /// which is what the card asks before drawing.
  factory _Window.of(List<StatusHistorySample> samples) => _Window(
    cpu: [for (final s in samples) s.cpu],
    mem: [for (final s in samples) s.mem],
    swap: [for (final s in samples) s.swap],
    disk: [for (final s in samples) s.disk],
    diskRead: [for (final s in samples) s.diskRead],
    diskWrite: [for (final s in samples) s.diskWrite],
    netRx: [for (final s in samples) s.netRx],
    netTx: [for (final s in samples) s.netTx],
  );

  final List<double?> cpu;
  final List<double?> mem;
  final List<double?> swap;
  final List<double?> disk;
  final List<double?> diskRead;
  final List<double?> diskWrite;
  final List<double?> netRx;
  final List<double?> netTx;
}

const _kCpuColor = Color(0xFF3B82F6);
const _kMemColor = Color(0xFF22C55E);
const _kSwapColor = Color(0xFF14B8A6);
const _kDiskColor = Color(0xFFF97316);
const _kDiskReadColor = Color(0xFF0EA5E9);
const _kNetRxColor = Color(0xFF8B5CF6);
const _kNetTxColor = Color(0xFFEC4899);

/// The block the chart lives in, by width.
///
/// A height, not a minimum: every state of it — a chart, one with a legend
/// under it, a request in flight, a metric with nothing stored — is this tall,
/// so moving between metrics does not move the rows below.
const _kFocusChartHeight = 216.0;
const _kFocusChartHeightNarrow = 140.0;


// --- What the rows and the focus card are made of ---

extension on _ServerDetailPageState {
  /// Every metric this machine reports, in the order they are read in.
  ///
  /// A metric the machine does not have is absent rather than dimmed: a row
  /// still costs a line to scan past, and one that can never have a value
  /// reads as broken. What is missing is said once, under the list.
  List<_MetricView> _metrics(ServerState si, _Window w) {
    final ss = si.status;
    final views = <_MetricView>[];

    // Always a row, even before the first sample: every machine has a CPU, so
    // an absent row would say this one does not rather than that nothing has
    // been measured yet — which is what the dash says.
    final cpu = ss.cpu.usedPercent(coreIdx: 0);
    {
      views.add(
        _MetricView(
          kind: _MetricKind.cpu,
          label: 'CPU',
          icon: ServerDetailCards.cpu.icon,
          color: _kCpuColor,
          value: _pct(cpu),
          note: ss.cpu.brand.keys.firstOrNull ?? '',
          bigNote: '${_pct(ss.cpu.idle)} idle',
          percent: cpu == null ? null : cpu / 100,
          stats: [
            (k: 'user', v: _pct(ss.cpu.user)),
            if (ss.system == SystemType.linux) ...[
              (k: 'sys', v: _pct(ss.cpu.sys)),
              (k: 'io', v: _pct(ss.cpu.iowait)),
            ],
            (k: 'idle', v: _pct(ss.cpu.idle)),
          ],
          series: [_HistorySeries('CPU', _kCpuColor, w.cpu)],
          format: _pct,
        ),
      );
    }

    if (ss.mem.total > 0) {
      final used = ss.mem.usedPercent * 100;
      final total = (ss.mem.total * 1024).bytes2Str;
      views.add(
        _MetricView(
          kind: _MetricKind.mem,
          label: libL10n.memory,
          icon: ServerDetailCards.mem.icon,
          color: _kMemColor,
          value: _pct(used),
          note: '${((ss.mem.total - ss.mem.free) * 1024).bytes2Str} / $total',
          bigNote: l10n.ofFmt(total),
          percent: used / 100,
          stats: [
            (k: 'free', v: _pct(ss.mem.free / ss.mem.total * 100)),
            (k: 'avail', v: _pct(ss.mem.availPercent * 100)),
          ],
          series: [_HistorySeries(libL10n.memory, _kMemColor, w.mem)],
          format: _pct,
        ),
      );
    }

    if (ss.swap.total > 0) {
      final used = ss.swap.usedPercent * 100;
      final total = (ss.swap.total * 1024).bytes2Str;
      views.add(
        _MetricView(
          kind: _MetricKind.swap,
          label: 'Swap',
          icon: ServerDetailCards.swap.icon,
          color: _kSwapColor,
          value: _pct(used),
          note: l10n.ofFmt(total),
          bigNote: l10n.ofFmt(total),
          percent: used / 100,
          stats: [
            (k: 'cached', v: _pct(ss.swap.cached / ss.swap.total * 100)),
          ],
          series: [_HistorySeries('Swap', _kSwapColor, w.swap)],
          format: _pct,
        ),
      );
    }

    if (ss.disk.isNotEmpty) {
      final usage = DiskUsage.parse(ss.disk);
      final used = usage.usedPercent;
      views.add(
        _MetricView(
          kind: _MetricKind.disk,
          label: libL10n.disk,
          icon: ServerDetailCards.disk.icon,
          color: _kDiskColor,
          value: _pct(used),
          note: '${usage.used.kb2Str} / ${usage.size.kb2Str}',
          bigNote: l10n.ofFmt(usage.size.kb2Str),
          percent: used / 100,
          series: [_HistorySeries(libL10n.disk, _kDiskColor, w.disk)],
          format: _pct,
        ),
      );

      final (read, write) = ss.diskIO.allSpeedBytes;
      if (read != null || write != null) {
        views.add(
          _MetricView(
            kind: _MetricKind.diskIo,
            label: l10n.diskIo,
            icon: MingCute.transfer_3_line,
            color: _kDiskReadColor,
            value: _rate(write),
            // The one that is going to be a problem, not the average of them:
            // a machine with six disks is busy because one of them is.
            note: _busiestNote(
              ss.disk.length,
              _busiest(ss.disk.map((e) => e.path), (dev) {
                final (r, wr) = ss.diskIO.speedBytes(dev);
                return (r ?? 0) + (wr ?? 0);
              }),
            ),
            bigNote: '${l10n.write} · ${_rate(read)} ${l10n.read}',
            stats: _rateStats(w.diskWrite),
            series: [
              _HistorySeries(l10n.read, _kDiskReadColor, w.diskRead),
              _HistorySeries(l10n.write, _kDiskColor, w.diskWrite),
            ],
            format: _rateOf,
            binary: true,
          ),
        );
      }
    }

    final ns = ss.netSpeed;
    if (ns.devices.isNotEmpty) {
      final rx = ns.speedInBytesOf();
      final tx = ns.speedOutBytesOf();
      views.add(
        _MetricView(
          kind: _MetricKind.net,
          label: libL10n.net,
          icon: ServerDetailCards.net.icon,
          color: _kNetTxColor,
          value: _rate(tx),
          note: _busiestNote(
            ns.realIfaces.length,
            _busiest(
              ns.realIfaces,
              (dev) =>
                  (ns.speedInBytesOf(device: dev) ?? 0) +
                  (ns.speedOutBytesOf(device: dev) ?? 0),
            ),
          ),
          bigNote: '↑ · ${_rate(rx)} ↓',
          stats: _rateStats(w.netTx),
          series: [
            _HistorySeries('↓', _kNetRxColor, w.netRx),
            _HistorySeries('↑', _kNetTxColor, w.netTx),
          ],
          format: _rateOf,
          binary: true,
        ),
      );
    }

    return views;
  }

  static String _pct(double? v) =>
      v == null ? '--' : '${(v * 10).round() / 10}%';

  static String _rate(double? bytesPerSec) =>
      bytesPerSec == null ? '--' : '${bytesPerSec.bytes2Str}/s';

  static String _rateOf(double v) => '${v.bytes2Str}/s';

  /// The device carrying the most of this metric right now.
  static String? _busiest(Iterable<String> devices, double Function(String) of) {
    String? name;
    var top = 0.0;
    for (final device in devices) {
      final value = of(device);
      if (name == null || value > top) {
        name = device;
        top = value;
      }
    }
    return name;
  }

  /// How many devices a rate is the sum of, and which of them is carrying it.
  String _busiestNote(int count, String? busiest) {
    if (count == 0) return '';
    if (busiest == null || count == 1) return l10n.devicesFmt(count);
    return l10n.devicesBusiestFmt(count, busiest);
  }

  /// What a rate has in place of a full: how high it got in the window on
  /// screen, and how wide that window is.
  List<_Stat> _rateStats(List<double?> values) {
    double? peak;
    for (final v in values) {
      if (v == null) continue;
      if (peak == null || v > peak) peak = v;
    }
    return [
      if (peak != null) (k: l10n.peak, v: _rate(peak)),
      (k: l10n.window, v: _range.label),
    ];
  }
}

// --- The section itself ---

extension on _ServerDetailPageState {
  /// The window the chart is drawing, which is either what this app has seen
  /// or what the agent answered for the chosen range.
  _Window _window(ServerState si) {
    final minutes = _range.minutes;
    if (minutes == null) return _Window.live(si.status.history);
    final samples = _rangeWindows[_range];
    if (samples == null) return const _Window();
    return _Window.of(samples);
  }

  /// One metric drawn in full, the rest a line each.
  Widget _buildMetrics(ServerState si, {required bool wide}) {
    final views = _metrics(si, _window(si));
    if (views.isEmpty) return UIs.placeholder;
    final focus =
        views.firstWhereOrNull((e) => e.kind == _focusMetric) ?? views.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFocusCard(si, focus, wide: wide),
        UIs.height7,
        // The cards bring their own margin, which is what spaces them.
        for (final view in views)
          _buildMetricRow(view, selected: view.kind == focus.kind, wide: wide),
      ],
    );
  }

  Widget _buildFocusCard(
    ServerState si,
    _MetricView m, {
    required bool wide,
  }) {
    final chart = _buildFocusChart(si, m, wide: wide);
    // Two groups with the room between them, not five children sharing it:
    // everything in this line is as long as the language or the machine makes
    // it, and a `Flexible` narrower than its share leaves the difference as
    // slack at the end of the row — which holds the ranges off the edge.
    final head = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(m.icon, size: 18, color: m.color),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_buildDeviceControl(si, m) case final control?) ...[
                const SizedBox(width: 13),
                control,
              ],
            ],
          ),
        ),
        Flexible(
          flex: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wide) ...[
                Flexible(
                  child: Text(
                    _historyNote(si),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: UIs.text11Grey,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Flexible(child: _buildRangeChips(si, wide: wide)),
            ],
          ),
        ),
      ],
    );

    final headline = [
      Text(m.value, style: UIs.text27),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          m.bigNote,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UIs.text13Grey,
        ),
      ),
    ];

    return CardX(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            UIs.height7,
            if (wide)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: headline,
                    ),
                  ),
                  if (m.stats.isNotEmpty)
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: _buildStats(m.stats),
                      ),
                    ),
                ],
              )
            else ...[
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: headline),
              if (m.stats.isNotEmpty) ...[
                UIs.height7,
                _buildStats(m.stats),
              ],
              UIs.height7,
              Text(_historyNote(si), style: UIs.text11Grey),
            ],
            chart,
            ?_buildFocusDetail(si, m.kind),
          ],
        ),
      ),
    );
  }

  /// The chart, or the one line that says why there isn't one.
  Widget _buildFocusChart(
    ServerState si,
    _MetricView m, {
    required bool wide,
  }) {
    final height = wide ? _kFocusChartHeight : _kFocusChartHeightNarrow;
    if (_rangeBusy.contains(_range)) {
      return SizedBox(height: height, child: UIs.centerLoading);
    }
    if (!m.hasChart) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            _range == _HistoryRange.live
                ? l10n.noHistoryYet
                : l10n.noStoredHistoryFor(m.label),
            textAlign: TextAlign.center,
            style: UIs.text12Grey,
          ),
        ),
      );
    }
    return _buildChart(
      _ChartSpec(
        series: m.series,
        format: m.format,
        binaryScale: m.binary,
        height: height,
        fill: true,
      ),
    );
  }

  /// What the machine says about this metric beyond the one number — the
  /// mounts, the interfaces, the cores. It belongs to the metric being read,
  /// not to the page, which is why it is inside the card rather than under it.
  Widget? _buildFocusDetail(ServerState si, _MetricKind kind) {
    final ss = si.status;
    switch (kind) {
      case _MetricKind.cpu:
        if (!_cpuViewAsProgress) return null;
        return Padding(
          padding: const EdgeInsets.only(top: 13),
          child: Column(children: _buildCPUProgress(ss.cpu)),
        );
      case _MetricKind.disk:
      case _MetricKind.diskIo:
      case _MetricKind.net:
      case _MetricKind.mem:
      case _MetricKind.swap:
        // The devices behind a metric are reached from the control in the
        // header, not listed under the chart. Once every device has a line of
        // its own the chart's legend is that list, and a second copy of it
        // below would be the same names twice.
        return null;
    }
  }

  /// The devices a metric is the sum of, and how many there are.
  ///
  /// A control rather than a list: a host reports as many interfaces as it has
  /// and most of them are idle tunnels, so the card says how many and opens
  /// the rest on request.
  Widget? _buildDeviceControl(ServerState si, _MetricView m) {
    final ss = si.status;
    final List<Widget> Function() rows;
    final int count;
    switch (m.kind) {
      case _MetricKind.disk:
      case _MetricKind.diskIo:
        if (ss.disk.isEmpty) return null;
        final disks = [...ss.disk]
          ..sort((a, b) => b.usedPercent.compareTo(a.usedPercent));
        count = disks.length;
        rows = () => [
          for (final disk in disks) _buildDiskItemWithHierarchy(disk, ss, 0),
        ];
      case _MetricKind.net:
        final ns = ss.netSpeed;
        final devices = ns.devices;
        if (devices.isEmpty) return null;
        devices.sort(_netSortType.value.getSortFunc(ns));
        count = devices.length;
        rows = () => devices.map((e) => _buildNetSpeedItem(ns, e)).toList();
      case _MetricKind.cpu:
      case _MetricKind.mem:
      case _MetricKind.swap:
        return null;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => _showClosableDetailDialog(
        title: libL10n.device,
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: rows()),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list, size: 15, color: UIs.textGrey.color),
            UIs.width7,
            Text(l10n.devicesFmt(count), style: UIs.text12Grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(List<_Stat> stats) {
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

  /// A metric that is not being read: what it is at, and how to read it.
  Widget _buildMetricRow(
    _MetricView m, {
    required bool selected,
    required bool wide,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : null;
    final value = Text(
      m.value,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: fg,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final Widget body;
    if (wide) {
      body = Row(
        children: [
          Icon(m.icon, size: 18, color: selected ? fg : m.color),
          UIs.width13,
          SizedBox(
            width: 84,
            child: Text(
              m.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (m.percent case final p?) ...[
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: LinearProgressIndicator(
                        value: p.clamp(0, 1),
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(3),
                        // The metric's own colour, and a track that is visible
                        // on both surfaces a row is drawn on: the theme's
                        // default track is the selected row's own background.
                        color: selected ? fg : m.color,
                        backgroundColor: (fg ?? scheme.onSurface).withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                  ),
                  UIs.width13,
                ],
                Flexible(
                  child: Text(
                    m.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UIs.text12Grey,
                  ),
                ),
              ],
            ),
          ),
          UIs.width13,
          value,
          const SizedBox(width: 9),
          Icon(
            selected ? Icons.show_chart : Icons.chevron_right,
            size: 17,
            color: fg ?? UIs.textGrey.color,
          ),
        ],
      );
    } else {
      body = Row(
        children: [
          Icon(m.icon, size: 18, color: selected ? fg : m.color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (m.note.isNotEmpty)
                  Text(
                    m.note,
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
        onTap: () => _rebuild(() => _focusMetric = m.kind),
        child: Padding(
          padding: wide
              ? const EdgeInsets.fromLTRB(17, 11, 13, 11)
              : const EdgeInsets.fromLTRB(13, 9, 13, 9),
          child: body,
        ),
      ),
    );
  }
}

// --- The range, and where it comes from ---

extension on _ServerDetailPageState {
  /// How the app reaches this machine — the transport that leads, which is
  /// the one a poll uses unless it fails over.
  String _transportName(ServerState si) {
    return switch (si.spi.transport) {
      ServerTransport.monitorHttp => 'monitor',
      ServerTransport.ssh => 'SSH',
    };
  }

  /// Where the window on screen comes from. A server with no agent has only
  /// what this app has watched since it connected, which is worth saying
  /// before someone reads a flat line as a quiet machine.
  String _historyNote(ServerState si) {
    if (!si.capabilities.storedHistory) return l10n.historySinceConnect;
    return l10n.historyStored;
  }

  /// The ranges, and the way to the ones that are not here.
  ///
  /// Three of them where there is room. On a narrow card only the chosen one,
  /// because three chips plus the picker is most of the header at 320pt — and
  /// in a language whose word for "live" is longer, more than all of it.
  Widget _buildRangeChips(ServerState si, {required bool wide}) {
    final stored = si.capabilities.storedHistory;
    final scheme = Theme.of(context).colorScheme;
    final selected = _range;
    final inline = wide
        ? [
            ..._HistoryRange.inline,
            if (!_HistoryRange.inline.contains(selected)) selected,
          ]
        : [selected];

    Widget chip(_HistoryRange range) {
      final on = range == selected;
      final enabled = stored || range == _HistoryRange.live;
      return Material(
        color: on ? scheme.secondaryContainer : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled
              ? () => _selectRange(range)
              : () => Toast.show(l10n.historyNoStored),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Text(
              range.label,
              style: TextStyle(
                fontSize: 12,
                color: on
                    ? scheme.onSecondaryContainer
                    : enabled
                    ? UIs.textGrey.color
                    : scheme.outline,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final range in inline) ...[chip(range), const SizedBox(width: 3)],
          InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => _showRangePicker(si),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Icon(
                Icons.date_range,
                size: 16,
                color: UIs.textGrey.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRangePicker(ServerState si) async {
    final stored = si.capabilities.storedHistory;
    final picked = await showRowsSheet<_HistoryRange>(
      context,
      rows: (ctx) => [
        for (final range in _HistoryRange.values)
          SheetChoiceTile(
            title: range.label,
            selected: range == _range,
            onTap: stored || range == _HistoryRange.live
                ? () => Navigator.of(ctx).pop(range)
                : () => Toast.show(l10n.historyNoStored),
          ),
      ],
    );
    if (picked != null) await _selectRange(picked);
  }

  /// Asks the agent for the window, once. The answer is kept until the page
  /// is left: a window an hour wide does not change meaningfully between two
  /// taps, and refetching it on every poll would spend a request a second on
  /// a chart nobody is watching change.
  Future<void> _selectRange(_HistoryRange range) async {
    if (!mounted) return;
    _rebuild(() => _range = range);
    final minutes = range.minutes;
    if (minutes == null ||
        _rangeWindows.containsKey(range) ||
        _rangeBusy.contains(range)) {
      return;
    }

    _rebuild(() => _rangeBusy.add(range));
    try {
      final samples = await ref
          .read(serverProvider(widget.args.spi.id).notifier)
          .fetchHistoryRange(minutes: minutes, maxPoints: _kRangePoints);
      if (!mounted) return;
      _rebuild(() => _rangeWindows[range] = samples);
    } catch (e, s) {
      Loggers.app.warning('History ${range.label} for ${widget.args.spi.id}', e, s);
      if (mounted) Toast.error('$e');
    } finally {
      _rebuild(() => _rangeBusy.remove(range));
    }
  }
}

/// What the agent will answer with at most, and as many as a chart this wide
/// can draw.
const _kRangePoints = 300;

// --- The facts that do not move ---

extension on _ServerDetailPageState {
  /// What the machine is, beside what it is doing.
  ///
  /// Two cards rather than one: the About rows come from the machine and
  /// change (uptime, the delay), the Hardware ones are what it is built of and
  /// do not. Kept out of the metric rows entirely, where they would be the
  /// only lines that never move.
  List<Widget> _buildInfoCards(ServerState si) {
    final ss = si.status;
    final publicIp = SelfAddr.pick(ss.ips);
    // One row, not two: how the app reaches this machine and how long that
    // took are the same fact — a delay means nothing without knowing whether
    // it timed an HTTP request or a shell script on a loaded box.
    final connection = [
      _transportName(si),
      if (si.agentVersion case final version?) 'v$version',
    ].join(' ');
    final about = <({String k, String v, bool secret})>[
      (
        k: libL10n.conn,
        v: si.latencyMs == null
            ? connection
            : '$connection · ${si.latencyMs}ms',
        secret: false,
      ),
      for (final e in ss.more.entries) (k: e.key.i18n, v: e.value, secret: false),
      if (publicIp != null)
        (k: l10n.publicIp, v: publicIp.address, secret: true),
    ];

    final cores = ss.cpu.coresCount;
    final usage = ss.disk.isEmpty ? null : DiskUsage.parse(ss.disk);
    final hardware = <({String k, String v, bool secret})>[
      if (ss.cpu.brand.keys.firstOrNull case final brand?)
        (k: 'CPU', v: brand, secret: false),
      if (cores > 0) (k: l10n.cores, v: '×$cores', secret: false),
      if (ss.mem.total > 0)
        (k: libL10n.memory, v: (ss.mem.total * 1024).bytes2Str, secret: false),
      if (ss.swap.total > 0)
        (k: 'Swap', v: (ss.swap.total * 1024).bytes2Str, secret: false),
      if (usage != null)
        (k: libL10n.disk, v: usage.size.kb2Str, secret: false),
    ];

    return [
      // Still the About card the setting knows by name: an install that
      // switched it off keeps it off, and the switch is still in settings to
      // put it back.
      if (about.isNotEmpty && !_cardsOff.contains(ServerDetailCards.about.name))
        _buildInfoCard(MingCute.information_fill, libL10n.about, about),
      if (hardware.isNotEmpty)
        _buildInfoCard(Icons.developer_board, l10n.hardware, hardware),
    ];
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    List<({String k, String v, bool secret})> rows,
  ) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            UIs.height7,
            for (final row in rows)
              Padding(
                key: ValueKey('info-${row.k}'),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(row.k, style: UIs.text12Grey),
                    UIs.width13,
                    Expanded(
                      child: row.secret
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: _SecretText(row.v),
                            )
                          : Text(
                              row.v,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UIs.text13,
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
