part of 'view.dart';

// --- The devices a metric is the sum of ---

extension on _ServerDetailPageState {
  /// The devices drawn for [kind], in [MetricDevices.names] order so a device
  /// keeps its colour as the busiest one changes.
  List<String> _plottedDevices(ServerMetricKind kind, MetricDevices devices) {
    final picked = _devicePick[kind];
    if (picked == null) return devices.defaults;
    return [
      for (final name in devices.names)
        if (picked.contains(name)) name,
    ];
  }

  /// One line per device, or null where the aggregate is what there is: a
  /// single device, or a window that came from a store that has only totals.
  List<HistorySeries>? _deviceSeries(ServerState si, ServerMetricKind kind) {
    // These come from the rolling buffer, whose samples are the live window's.
    // Drawn against any other window they would be plotted at instants they
    // were not taken at.
    if (_custom != null || _range != HistoryRange.live) return null;
    final devices = MetricDevices.of(si, kind);
    if (devices == null) return null;
    final series = [
      for (final (i, name) in _plottedDevices(kind, devices).indexed)
        HistorySeries(
          name,
          ChartPalette.lines[i % kMaxDeviceLines],
          devices.byDevice[name] ?? const <double?>[],
        ),
    ];
    // Before the first sample of a device that only just appeared there is
    // nothing under its name, and a legend of empty lines is worse than the
    // totals.
    return series.any((s) => s.hasSpots) ? series : null;
  }
}

// --- The section itself ---

extension on _ServerDetailPageState {
  /// One metric drawn in full, the rest a line each.
  ///
  /// Built again when a different one is chosen, and nothing else on the page
  /// is — see [_ServerDetailPageState._focus].
  Widget _buildMetrics(ServerState si, {required bool wide}) {
    final window = _window(si);
    final views = serverDetailMetrics(
      si,
      window,
      deviceSeries: (kind) => _deviceSeries(si, kind),
    );
    if (views.isEmpty) return UIs.placeholder;
    final staleAt = serverStaleSince(si);
    // Each row as it is drawn chosen and as it is drawn not, kept between the
    // builder's runs and dropped whenever this method is called again.
    //
    // Choosing a reading changes two rows: the one that was chosen and the
    // one that is. Built afresh each time, all nine were new widgets and all
    // nine were built again; handed the widget it already has, Flutter skips
    // a row altogether.
    final rows = <(ServerMetricKind, bool), Widget>{};

    return ValueListenableBuilder(
      valueListenable: _focus,
      builder: (_, chosen, _) {
        final focus =
            views.firstWhereOrNull((e) => e.kind == chosen) ?? views.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFocusCard(si, focus, window, wide: wide),
            UIs.height7,
            // The cards bring their own margin, which is what spaces them.
            for (final view in views)
              rows.putIfAbsent(
                (view.kind, view.kind == focus.kind),
                () => _buildMetricRow(
                  view,
                  selected: view.kind == focus.kind,
                  wide: wide,
                  staleAt: staleAt,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFocusCard(
    ServerState si,
    DetailMetric m,
    MetricWindow w, {
    required bool wide,
  }) {
    final axis = _chartWindow(si, m, w);
    final chart = _buildFocusChart(si, m, w, axis, wide: wide);
    // What a window that could not be filled actually holds. Only when it is
    // short: on a window the agent covered, "stored 24 h · window 24 h" is two
    // ways of saying the axis.
    final stats = [
      ...m.stats,
      // How long a window the reader named is, where the header has room for
      // its two ends and so says those instead. Narrow, the header's chip is
      // this number, and a preset's chip is its name: either way it would be
      // on the card twice.
      if (_custom case final window? when wide)
        (k: l10n.window, v: window.to.difference(window.from).toAgoStr),
      if (axis.bands.firstOrNull case final gap?
          when (_custom != null || _range != HistoryRange.live) &&
              w.times.isNotEmpty)
        (
          k: l10n.stored,
          v: Duration(milliseconds: w.times.last - gap.to).toAgoStr,
        ),
      // Only for a window the reader named: how dense it came back is a
      // property of that window, while a preset's density is the same every
      // time and worth no line.
      if (_custom != null && w.times.isNotEmpty)
        (k: l10n.samples, v: '${w.times.length}'),
    ];
    final device = _buildDeviceControl(si, m);
    final note = _historyNote(si, wide: wide);
    // Two groups with the room between them, not five children sharing it:
    // everything in this line is as long as the language or the machine makes
    // it, and a `Flexible` narrower than its share leaves the difference as
    // slack at the end of the row — which holds the ranges off the edge.
    //
    // The shares are 2:3 because that is roughly what the two sides need: the
    // right holds the note and three chips, the left a name and a device
    // count. At 1:3 the left was a quarter of the card and the count came out
    // as "2 o…".
    final head = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(m.icon, size: 18, color: ChartPalette.accent),
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
              // Narrow, the header is a name and the ranges and nothing fits
              // between them: the control goes on the note's line below, which
              // is otherwise a line of grey text with the rest of the card's
              // width to itself.
              if (wide && device != null) ...[
                const SizedBox(width: 13),
                Flexible(child: device),
              ],
            ],
          ),
        ),
        Flexible(
          flex: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wide && note != null) ...[
                Flexible(
                  child: Text(
                    note,
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

    final value = Text(m.value, style: UIs.text27);

    // The key goes on a wrapper, not on the card: `CardX` hands its own key to
    // the `Card` it builds, and a `GlobalKey` on two widgets at once is an
    // error rather than a duplicate.
    return KeyedSubtree(
      key: _focusCardKey,
      child: CardX(
        child: Padding(
          padding: ServerCardSizes.focusPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stated rather than natural — see [ServerCardSizes.openHead].
              // It is also where the card this page grew out of put its own,
              // which is what lets the page take over without the chart
              // moving.
              SizedBox(height: ServerCardSizes.openHead, child: head),
              UIs.height7,
              // What is over the chart and what is under it are as tall as
              // the reading has things to say — a line of what it is of, a
              // second run of facts, a bar for every core — and choosing
              // another reading changed both between two frames: the chart
              // jumped by one and the rows under the card by the sum. Each
              // eases to its new height on its own, beside the other and not
              // inside it, so the chart slides by the one over it and the
              // card's height is the two together. One [AnimatedSize] round
              // the card would ease its edge and leave the chart to jump
              // inside it, and one inside another is cut short by the outer.
              ServerDetailEased(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                value,
                                const SizedBox(width: 9),
                                Flexible(
                                  child: ServerDetailFacts(
                                    note: m.bigNote,
                                    stats: const [],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (stats.isNotEmpty)
                            Flexible(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: ServerDetailStats(stats: stats),
                              ),
                            ),
                        ],
                      )
                    else ...[
                      // On the number's own line, and in the words that were
                      // already there. They had a line of their own under it, in a
                      // second style — a number over its name — so a phone gave
                      // two lines and two ways of writing to what is one sentence:
                      // how busy it is, and where the rest of it went.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          value,
                          const SizedBox(width: 9),
                          Expanded(
                            child: ServerDetailFacts(
                              note: m.bigNote,
                              stats: stats,
                            ),
                          ),
                        ],
                      ),
                      if (note != null || device != null) ...[
                        UIs.height7,
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                note ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: UIs.text11Grey,
                              ),
                            ),
                            ?device,
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              // As tall as a chart for every reading but one that failed,
              // which is as tall as what it has to say.
              ServerDetailEased(child: chart),
              ServerDetailEased(
                child:
                    _buildFocusDetail(si, m.kind) ??
                    const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The chart, or the one line that says why there isn't one.
  Widget _buildFocusChart(
    ServerState si,
    DetailMetric m,
    MetricWindow w,
    ({({int from, int to})? window, List<ChartBand> bands}) axis, {
    required bool wide,
  }) {
    final height = wide
        ? ServerCardSizes.openChart
        : ServerCardSizes.openChartNarrow;
    // A section that failed has no line to draw and a reason worth reading,
    // so that takes the chart's place — and only as much of it as it needs:
    // see [ServerDetailReadingFailed].
    if (m.error case final err?) {
      return ServerDetailReadingFailed(label: m.label, error: err, wide: wide);
    }
    // Only the chart waits. The range is a question about the chart, and the
    // headline and the rows below go on being what the machine is doing now.
    if (_customBusy || (_custom == null && _rangeBusy.contains(_range))) {
      return ServerDetailChartNotice(
        height: height,
        text: l10n.loadingRangeFmt(_rangeLabel(wide: true)),
        waiting: true,
      );
    }
    if (!m.hasChart) {
      // Waiting and having nothing are different answers. Before the first
      // sample the page is not empty, it is early — and the progress line is
      // what says which of the two this is.
      if (serverNeverSampled(si)) {
        return ServerDetailChartNotice(
          height: height,
          text: l10n.waitingFirstSample,
          waiting: true,
        );
      }
      return ServerDetailChartNotice(
        height: height,
        // "Nothing measured yet" is about the buffer this app fills as it
        // watches. A window asked of the agent that came back empty is a
        // different answer, whatever the preset behind it happens to be.
        text: _custom == null && _range == HistoryRange.live
            ? l10n.noHistoryYet
            : l10n.noStoredHistoryFor(m.label),
      );
    }
    // A layer of its own. fl_chart eases from one line to the next over 150ms,
    // which is nine frames of a chart that has changed and a page around it
    // that has not — and without this each of them painted the page: every
    // row under the chart, and where the facts are under those rather than
    // beside them, every card and table of those as well.
    return RepaintBoundary(
      child: MetricChart(
        MetricChartSpec(
          series: m.series,
          format: m.format,
          times: w.times,
          window: axis.window,
          bands: axis.bands,
          binaryScale: m.binary,
          height: height,
          fill: true,
        ),
      ),
    );
  }

  /// What the machine says about this metric beyond the one number — the
  /// mounts, the interfaces, the cores. It belongs to the metric being read,
  /// not to the page, which is why it is inside the card rather than under it.
  Widget? _buildFocusDetail(ServerState si, ServerMetricKind kind) {
    final ss = si.status;
    switch (kind) {
      case ServerMetricKind.cpu:
        if (!_cpuViewAsProgress) return null;
        return Padding(
          padding: const EdgeInsets.only(top: 13),
          child: ServerDetailCpuBars(
            cpus: ss.cpu,
            showIndex: _displayCpuIndex,
          ),
        );
      case ServerMetricKind.disk:
      case ServerMetricKind.diskIo:
      case ServerMetricKind.net:
      case ServerMetricKind.mem:
      case ServerMetricKind.swap:
      case ServerMetricKind.gpu:
      case ServerMetricKind.temp:
      case ServerMetricKind.battery:
        // The devices behind a metric are reached from the control in the
        // header, not listed under the chart. Once every device has a line of
        // its own the chart's legend is that list, and a second copy of it
        // below would be the same names twice.
        return null;
    }
  }

  /// Which of a metric's devices the chart draws, and the way to change it.
  ///
  /// A control rather than a list under the chart: once every device has a
  /// line of its own the legend *is* that list, and the question left is which
  /// of them are worth a line — a host reports as many interfaces as it has
  /// and most of them are idle tunnels.
  ///
  /// The disk row is the exception: what a filesystem is at has no line, so
  /// its devices are a list to read rather than a set to choose from.
  Widget? _buildDeviceControl(ServerState si, DetailMetric m) {
    final ss = si.status;
    if (m.kind == ServerMetricKind.disk) {
      if (ss.disk.length < 2) return null;
      final disks = [...ss.disk]
        ..sort((a, b) => b.usedPercent.compareTo(a.usedPercent));
      return ServerDetailDeviceButton(
        label: l10n.devicesFmt(disks.length),
        onTap: () => _showClosableDetailDialog(
          title: libL10n.device,
          child: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final disk in disks)
                    ServerDetailDiskItem(disk: disk, status: ss),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final devices = MetricDevices.of(si, m.kind);
    if (devices == null) return null;
    // What the legend is showing, out of what the machine reports. Only the
    // live window draws a line each, so anywhere else this is the count alone.
    // "6 of 8" is about the lines on the chart, and those are drawn from the
    // rolling buffer — so only the live window has any. Anywhere else the
    // honest answer is how many devices the machine has.
    final label = _custom == null && _range == HistoryRange.live
        ? l10n.devicesPlottedFmt(
            _plottedDevices(m.kind, devices).length,
            devices.names.length,
          )
        : l10n.devicesFmt(devices.names.length);
    return ServerDetailDeviceButton(
      label: label,
      onTap: () => _showDevicePicker(si, m.kind),
    );
  }

  /// The devices, ticked where they are drawn.
  ///
  /// Stays open as they are ticked, and the chart behind it follows each tap:
  /// which lines are worth drawing is a question answered by looking at them,
  /// not by predicting them and closing a sheet.
  Future<void> _showDevicePicker(ServerState si, ServerMetricKind kind) async {
    final scheme = Theme.of(context).colorScheme;
    await showRowsSheet<void>(
      context,
      rows: (_) => [
        StatefulBuilder(
          builder: (_, setSheetState) {
            // Re-read on every rebuild: a poll lands while the sheet is open,
            // and the readings under the names are what the choice is made on.
            final devices = MetricDevices.of(
              ref.read(serverProvider(widget.args.spi.id)),
              kind,
            );
            if (devices == null) return UIs.placeholder;
            final plotted = _plottedDevices(kind, devices).toSet();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final name in devices.names)
                  ListTile(
                    selected: plotted.contains(name),
                    title: Text(name),
                    subtitle: Text(
                      devices.subtitle(name),
                      style: UIs.text12Grey,
                    ),
                    trailing: plotted.contains(name)
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () {
                      _toggleDevice(kind, name, plotted);
                      setSheetState(() {});
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Adds or removes one device from what the chart draws.
  ///
  /// The last one on cannot be turned off: an empty chart is not a view of
  /// anything, and "nothing is selected" is not a state this page can explain
  /// in the space a legend has.
  void _toggleDevice(ServerMetricKind kind, String name, Set<String> plotted) {
    if (plotted.contains(name) && plotted.length == 1) {
      Toast.show(l10n.oneDeviceAtLeast);
      return;
    }
    _rebuild(() {
      final picked = _devicePick.putIfAbsent(kind, () => {...plotted});
      if (!picked.remove(name)) picked.add(name);
    });
  }

  /// Brings the chart back on screen, if tapping a row sent a metric to a card
  /// that is no longer there.
  ///
  /// Nine rows and the cards under them are taller than a phone, so the row
  /// that promotes a metric is regularly below the card it promotes it into —
  /// and from down there the tap does nothing visible at all. Only when it is
  /// off screen: a chart that jumps every time a row is tapped is a page that
  /// moves under the hand that is using it.
  void _revealFocus() {
    final ctx = _focusCardKey.currentContext;
    if (ctx == null || !_scrollCtrl.hasClients) return;
    final target = ctx.findRenderObject();
    if (target == null) return;
    final viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport == null) return;

    // The two offsets that put the card against each edge of the viewport.
    // Anywhere between them it is already whole on screen.
    final toTop = viewport.getOffsetToReveal(target, 0).offset;
    final toBottom = viewport.getOffsetToReveal(target, 1).offset;
    final position = _scrollCtrl.position;
    final current = position.pixels;
    if (current <= toTop && current >= toBottom) return;

    _scrollCtrl.animateTo(
      current > toTop
          ? toTop.clamp(position.minScrollExtent, position.maxScrollExtent)
          : toBottom.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: Durations.medium2,
      curve: Curves.easeOutCubic,
    );
  }

  /// A metric that is not being read: what it is at, and how to read it.
  ///
  /// Built again when what it says has changed and not on every poll: most of
  /// them say on this poll what they said on the last — a disk's share, a
  /// swap nobody is using, a battery — and a row is forty elements to be told
  /// so. See [BuiltFrom] for what has to be listed; the press is safe to keep,
  /// since what it reads of the row is which reading it is.
  Widget _buildMetricRow(
    DetailMetric m, {
    required bool selected,
    required bool wide,
    DateTime? staleAt,
  }) {
    // And a layer of its own, as every card on this page has: what is kept
    // is not built again, but it is painted again with everything else in its
    // layer whenever any of that changes — which on every poll something
    // does. With one each, a poll paints the cards that changed.
    return RepaintBoundary(
      child: BuiltFrom(
        [
          m.kind,
          m.icon,
          m.label,
          m.value,
          m.note,
          m.percent,
          m.error,
          selected,
          wide,
          // To the minute, which is what the row says of it.
          staleAt == null ? null : _clockOf(staleAt.millisecondsSinceEpoch),
        ],
        builder: (_) =>
            _metricRow(m, selected: selected, wide: wide, staleAt: staleAt),
      ),
    );
  }

  Widget _metricRow(
    DetailMetric m, {
    required bool selected,
    required bool wide,
    DateTime? staleAt,
  }) {
    // A failure outranks staleness here the way it does in the figure's colour
    // — see [ServerDetailMetricTile]. Both at once is the common case — a
    // section stops answering and the reading it left goes stale — and the
    // timestamp says when this was last true, while the note says why it is
    // not true now. Only one of them fits, and it is the second.
    final note = m.error != null || staleAt == null
        ? m.note
        : l10n.atTimeFmt(_clockOf(staleAt.millisecondsSinceEpoch));

    void promote() {
      _focus.value = m.kind;
      // Kept, so the card this page grew out of shows the same reading when it
      // shrinks back into the list.
      ServerPromoted.put(widget.args.spi.id, m.kind);
      _revealFocus();
    }

    // The same widget the card in the list draws, at the far end of the
    // movement that turns one into the other. Two rows built from the same
    // numbers would have to be crossed over when the page takes the card
    // over, and a crossing is what reads as the page having been rebuilt.
    if (wide) {
      return MetricRow(
        icon: m.icon,
        label: m.label,
        color: ChartPalette.accent,
        value: m.value,
        note: note,
        percent: m.percent,
        error: m.error,
        selected: selected,
        onTap: promote,
      );
    }

    return ServerDetailMetricTile(
      icon: m.icon,
      label: m.label,
      value: m.value,
      note: note,
      error: m.error,
      selected: selected,
      stale: staleAt != null,
      onTap: promote,
    );
  }
}
