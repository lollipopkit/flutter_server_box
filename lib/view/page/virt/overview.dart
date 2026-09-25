// ignore_for_file: invalid_use_of_protected_member

part of 'guest.dart';

/// The four readings a guest has a chart for.
enum _VirtMetric { cpu, mem, disk, net }

extension on _VirtMetric {
  String get label => switch (this) {
    _VirtMetric.cpu => 'CPU',
    _VirtMetric.mem => libL10n.memory,
    _VirtMetric.disk => l10n.diskIo,
    _VirtMetric.net => libL10n.network,
  };

  IconData get icon => switch (this) {
    _VirtMetric.cpu => Icons.speed,
    _VirtMetric.mem => Icons.memory,
    _VirtMetric.disk => Icons.swap_vert,
    _VirtMetric.net => Icons.language,
  };

  bool get isRate => this == _VirtMetric.disk || this == _VirtMetric.net;

  /// The lines of this metric's chart over [samples], index-aligned with
  /// them.
  List<HistorySeries> series(List<VirtStats> samples) => switch (this) {
    _VirtMetric.cpu => [
      HistorySeries('CPU', ChartPalette.cpu, [for (final s in samples) s.cpu]),
    ],
    _VirtMetric.mem => [
      HistorySeries(libL10n.memory, ChartPalette.mem, [
        for (final s in samples) _memPct(s),
      ]),
    ],
    _VirtMetric.disk => [
      HistorySeries(libL10n.read, ChartPalette.diskRead, [
        for (final s in samples) s.diskRead,
      ]),
      HistorySeries(libL10n.write, ChartPalette.diskWrite, [
        for (final s in samples) s.diskWrite,
      ]),
    ],
    _VirtMetric.net => [
      HistorySeries('↓', ChartPalette.netRx, [for (final s in samples) s.netIn]),
      HistorySeries('↑', ChartPalette.netTx, [
        for (final s in samples) s.netOut,
      ]),
    ],
  };

  /// The reading now, and what it is of.
  ({String value, String note, double? frac}) now(VirtStats? s) {
    switch (this) {
      case _VirtMetric.cpu:
        final cpu = s?.cpu;
        return (
          value: ReadingFmt.pct(cpu),
          note: '',
          frac: cpu == null ? null : cpu / 100,
        );
      case _VirtMetric.mem:
        final pct = s == null ? null : _memPct(s);
        final used = s?.memUsed;
        final total = s?.memTotal;
        return (
          value: ReadingFmt.pct(pct),
          note: used != null && total != null
              ? '${used.bytes2Str} / ${total.bytes2Str}'
              : '',
          frac: pct == null ? null : pct / 100,
        );
      case _VirtMetric.disk:
        return (
          value: _sumRate(s?.diskRead, s?.diskWrite),
          note:
              'R ${ReadingFmt.rate(s?.diskRead)} · '
              'W ${ReadingFmt.rate(s?.diskWrite)}',
          frac: null,
        );
      case _VirtMetric.net:
        return (
          value: _sumRate(s?.netIn, s?.netOut),
          note:
              '↓ ${ReadingFmt.rate(s?.netIn)} · '
              '↑ ${ReadingFmt.rate(s?.netOut)}',
          frac: null,
        );
    }
  }
}

double? _memPct(VirtStats s) {
  final used = s.memUsed;
  final total = s.memTotal;
  if (used == null || total == null || total <= 0) return null;
  return used / total * 100;
}

String _sumRate(double? a, double? b) =>
    ReadingFmt.rate(a == null && b == null ? null : (a ?? 0) + (b ?? 0));

extension on VirtHistoryWindow {
  String get label => switch (this) {
    VirtHistoryWindow.hour => '1h',
    VirtHistoryWindow.day => '24h',
    VirtHistoryWindow.week => '7d',
  };
}

// --- Widgets ---

extension _Overview on _VirtGuestViewState {
  /// The readings and what the guest is, beside each other where there is
  /// room.
  Widget _buildOverview(
    VirtHostState st,
    VirtGuest guest,
    VirtGuestState state,
  ) {
    final spi = ref.watch(serversProvider).servers[widget.serverId];
    final main = <Widget>[
      if (state.isActive)
        _buildReadings(st, guest)
      else
        _buildOff(st, guest, state),
      _buildDetailCards(),
    ];
    final side = <Widget>[
      _buildFacts(guest, state),
      if (st.data?.host case final host?) _buildHost(host, guest, spi?.name),
    ];
    return LayoutBuilder(
      builder: (_, cons) {
        const pad = EdgeInsets.fromLTRB(13, 0, 13, 17);
        if (cons.maxWidth < 760) {
          return ListView(padding: pad, children: [...main, ...side]);
        }
        return SingleChildScrollView(
          padding: pad,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: main)),
              UIs.width13,
              SizedBox(width: 300, child: Column(children: side)),
            ],
          ),
        );
      },
    );
  }

  /// The focused metric's chart, and a row per metric to change focus.
  Widget _buildReadings(VirtHostState st, VirtGuest guest) {
    final stored = st.data?.capabilities.storedHistory ?? false;
    final now = st.statsOf(guest.id);
    final focus = _metric.now(now);

    return Column(
      children: [
        CardX(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 11, 17, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_metric.icon, size: 18, color: ChartPalette.accent),
                    UIs.width7,
                    Text(_metric.label, style: UIs.text13Bold),
                    const Spacer(),
                    // Windows the host kept, where it keeps any. Without them
                    // the chart is this session's, which needs no choice.
                    if (stored)
                      // Shares the title's line and is changed once in a
                      // while: the chosen window at rest, all of them while
                      // choosing.
                      SegmentedTabs<VirtHistoryWindow?>(
                        collapse: true,
                        selected: _window,
                        onSelected: _selectWindow,
                        segments: [
                          SegmentedTab(value: null, label: l10n.rangeLive),
                          for (final w in VirtHistoryWindow.values)
                            SegmentedTab(value: w, label: w.label),
                        ],
                      ),
                  ],
                ),
                UIs.height7,
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 13,
                  children: [
                    Text(
                      focus.value,
                      style: const TextStyle(
                        fontSize: 27,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (focus.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(focus.note, style: UIs.text13Grey),
                      ),
                  ],
                ),
                _buildChart(st, guest),
              ],
            ),
          ),
        ),
        for (final m in _VirtMetric.values) _buildMetricRow(m, now),
        UIs.height7,
      ],
    );
  }

  Widget _buildChart(VirtHostState st, VirtGuest guest) {
    final window = _window;
    if (window == null) {
      return _chartOf(st.samples[guest.id] ?? const []);
    }
    return FutureBuilder<List<VirtStats>>(
      future: _stored,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: _chartHeight,
            child: Center(child: SizedLoading.small),
          );
        }
        if (snap.error case final e?) {
          return _chartNotice(e is VirtErr ? e.title : '$e');
        }
        return _chartOf(snap.data ?? const []);
      },
    );
  }

  static const _chartHeight = 170.0;

  Widget _chartOf(List<VirtStats> samples) {
    final series = _metric.series(samples);
    final times = [for (final s in samples) s.at.millisecondsSinceEpoch];
    final spec = MetricChartSpec(
      series: series,
      format: _metric.isRate ? ReadingFmt.rateAxis : ReadingFmt.pct,
      times: times,
      window: watchedWindow(times, series),
      binaryScale: _metric.isRate,
      height: _chartHeight,
    );
    if (!spec.hasData) {
      return _chartNotice(
        _window == null ? l10n.waitingFirstSample : l10n.noHistoryYet,
      );
    }
    return RepaintBoundary(child: MetricChart(spec));
  }

  Widget _chartNotice(String text) => SizedBox(
    height: _chartHeight,
    child: Center(child: Text(text, style: UIs.textGrey)),
  );

  Widget _buildMetricRow(_VirtMetric m, VirtStats? now) {
    final scheme = Theme.of(context).colorScheme;
    final on = m == _metric;
    final reading = m.now(now);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Material(
        color: on ? scheme.secondaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          key: ValueKey(m),
          borderRadius: BorderRadius.circular(13),
          onTap: () => setState(() => _metric = m),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
            child: Row(
              children: [
                Icon(m.icon, size: 18, color: ChartPalette.accent),
                UIs.width13,
                SizedBox(
                  width: 80,
                  child: Text(m.label, style: UIs.text13Bold),
                ),
                Expanded(
                  child: reading.frac != null
                      ? Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: ProgressLine(value: reading.frac),
                          ),
                        )
                      : Text(
                          reading.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UIs.text12Grey,
                        ),
                ),
                UIs.width13,
                Text(
                  reading.value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A guest that is not running has nothing to chart. Says so, and offers
  /// the way to change that.
  Widget _buildOff(VirtHostState st, VirtGuest guest, VirtGuestState state) {
    final start = _startIfOffered(st, guest);
    return CardX(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 27),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.power_settings_new,
                size: 48,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              UIs.height13,
              Text(state.label, style: UIs.text15Bold),
              UIs.height7,
              Text(
                l10n.virtOffTip,
                textAlign: TextAlign.center,
                style: UIs.textGrey,
              ),
              if (start != null) ...[
                UIs.height13,
                Btn.elevated(
                  mainAxisSize: MainAxisSize.min,
                  text: libL10n.start,
                  icon: const Icon(Icons.play_arrow),
                  onTap: start,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// What the guest is: its state, its size, where it runs.
  Widget _buildFacts(VirtGuest guest, VirtGuestState state) {
    final reason = guest.stateReason;
    final chips = [
      guest.kind.label,
      if (guest.template) l10n.virtTemplate,
      if (guest.autostart ?? false) l10n.virtAutostart,
      ...guest.tags,
    ];
    return VirtCard(
      icon: guest.kind.icon,
      title: guest.name,
      children: [
        VirtFact(
          l10n.status,
          reason == null ? state.label : '${state.label} ($reason)',
        ),
        if (guest.vmid case final vmid?) VirtFact('VMID', '$vmid'),
        if (guest.node case final node?) VirtFact(libL10n.node, node),
        if (guest.vcpu case final n?) VirtFact('vCPU', '$n'),
        if (guest.memBytes case final m?) VirtFact(libL10n.memory, m.bytes2Str),
        if (state.isActive)
          if (guest.uptime case final up?)
            VirtFact(libL10n.uptime, up.toAgoStr),
        UIs.height7,
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [for (final c in chips) VirtChip(c)],
        ),
      ],
    );
  }

  Widget _buildHost(VirtHost host, VirtGuest guest, String? serverName) {
    final version = [?host.version, ?host.hypervisor].join(' · ');
    return VirtCard(
      icon: Icons.dns_outlined,
      title: libL10n.host,
      children: [
        if (serverName != null) VirtFact(libL10n.server, serverName),
        VirtFact(host.kind.label, version.isEmpty ? '--' : version),
        if (host.isCluster)
          if (guest.node case final node?) VirtFact(libL10n.node, node),
      ],
    );
  }

  /// Disks and interfaces, as the host's configuration has them.
  Widget _buildDetailCards() {
    return FutureBuilder<VirtGuestDetail>(
      future: _detail,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(13),
            child: Center(child: SizedLoading.small),
          );
        }
        if (snap.error case final e?) {
          return VirtCard(
            icon: Icons.error_outline,
            title: e is VirtErr ? e.title : libL10n.error,
            children: [
              if (e is VirtErr)
                if (e.detail case final d?) Text(d, style: UIs.text12Grey),
            ],
          );
        }
        final detail = snap.data;
        if (detail == null) return UIs.placeholder;
        return Column(
          children: [
            if (detail.disks.isNotEmpty)
              VirtCard(
                icon: Icons.storage_outlined,
                title: libL10n.disk,
                children: [
                  for (final d in detail.disks)
                    VirtFact(
                      [?d.target, if (d.device != 'disk') d.device].join(' · '),
                      [
                        d.source ?? '--',
                        ?d.size?.bytes2Str,
                        ?d.format,
                      ].join(' · '),
                    ),
                ],
              ),
            if (detail.nics.isNotEmpty)
              VirtCard(
                icon: Icons.lan_outlined,
                title: libL10n.network,
                children: [
                  for (final n in detail.nics)
                    VirtFact(
                      [
                        if (n.target case final t?) t else n.kind,
                        ?n.model,
                      ].join(' · '),
                      [?n.source, ?n.mac].join(' · '),
                    ),
                ],
              ),
            if (detail.description case final desc? when desc.isNotEmpty)
              VirtCard(
                icon: Icons.notes,
                title: libL10n.note,
                children: [SelectableText(desc, style: UIs.text13)],
              ),
          ],
        );
      },
    );
  }
}
