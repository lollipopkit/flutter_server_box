part of 'view.dart';

// --- The range, and where it comes from ---

extension on _ServerDetailPageState {
  /// The window the chart is drawing, which is either what this app has seen
  /// or what the agent answered for the chosen range.
  MetricWindow _window(ServerState si) {
    if (_custom != null) {
      final answer = _customAnswer;
      return answer == null
          ? const MetricWindow()
          : MetricWindow.of(answer.samples);
    }
    final minutes = _range.minutes;
    if (minutes == null) return MetricWindow.live(si.status.history);
    final answer = _rangeWindows[_range];
    if (answer == null) return const MetricWindow();
    return MetricWindow.of(answer.samples);
  }

  /// The axis the chart draws, and the stretches of it no sample falls in.
  ///
  /// The axis is the window that was *asked for*. Taking it from the samples
  /// instead makes every window look full: three stored hours drawn on a
  /// 24-hour request would fill the card, and a page left in the background
  /// for four minutes would draw a line straight across the gap.
  ({({int from, int to})? window, List<ChartBand> bands}) _chartWindow(
    ServerState si,
    DetailMetric m,
    MetricWindow w,
  ) {
    final times = w.times;
    if (times.isEmpty) return (window: null, bands: const []);
    final first = times.first;
    final last = times.last;

    if (_custom case final window?) {
      final from = window.from.millisecondsSinceEpoch;
      final to = window.to.millisecondsSinceEpoch;
      return (
        window: (from: from, to: to),
        bands: _bandsIn(from: from, to: to, first: first, last: last),
      );
    }

    final minutes = _range.minutes;
    if (minutes == null) {
      // What this app has watched. Up to now only once the readings have
      // stopped, which is when the distance to the last of them is worth
      // seeing — see [watchedWindow] for what it was before that.
      final now = DateTime.now().millisecondsSinceEpoch;
      final stopped = now - last > serverStaleAfter.inMilliseconds;
      return (
        window: watchedWindow(times, m.series, until: stopped ? now : null),
        bands: stopped
            ? [(from: last, to: now, label: l10n.noData)]
            : const [],
      );
    }

    final answer = _rangeWindows[_range];
    final to = answer?.at.millisecondsSinceEpoch ?? last;
    final from = to - minutes * 60 * 1000;
    return (
      window: (from: from, to: to),
      bands: _bandsIn(from: from, to: to, first: first, last: last),
    );
  }

  /// What a stored window did not come back with, said in the band.
  ///
  /// Two buckets of tolerance at each end: the agent averages the window into
  /// at most [kHistoryRangePoints] of them, so the outermost points sit a
  /// bucket inside the window however much it kept — and a band drawn for that
  /// is a band on every chart.
  List<ChartBand> _bandsIn({
    required int from,
    required int to,
    required int first,
    required int last,
  }) {
    final tolerance = ((to - from) ~/ kHistoryRangePoints) * 2;
    return [
      for (final gap in windowGaps(
        from: from,
        to: to,
        first: first,
        last: last,
        leadTolerance: tolerance,
        trailTolerance: tolerance,
      ))
        (
          from: gap.from,
          to: gap.to,
          // Where it stops being true is the fact: a gap at the start of the
          // window says when the readings begin, and one at the end has
          // nothing to name — it runs to now.
          label: gap.leading
              ? l10n.noDataBeforeFmt(_clockOf(first))
              : l10n.noData,
        ),
    ];
  }

  /// A sample's instant as a clock reading — the day where the window spans
  /// one, because "no data before 11:20" is a different fact on Tuesday.
  String _clockOf(int timeMs) {
    final at = DateTime.fromMillisecondsSinceEpoch(timeMs);
    final sameDay = DateTime.now().difference(at) < const Duration(hours: 12);
    return DateFormat(
      sameDay ? 'HH:mm' : 'MMM d HH:mm',
      l10n.localeName,
    ).format(at);
  }

  /// The one line under the header, when there is something for it to say.
  ///
  /// Null on an ordinary card. It used to name where the window came from —
  /// "stored history", "since connect · not stored" — on every card of every
  /// server, which is a line that never changes and was read once. Where the
  /// samples come from is already answered by which ranges the header offers.
  String? _historyNote(ServerState si, {bool wide = true}) {
    // A page whose newest sample is minutes old is the one fact the reader
    // needs, and the only one worth a line of its own.
    if (serverStaleSince(si) case final at?) return l10n.lastSampleFmt(at.toAgoStr());
    // Narrow, the header's chip holds only the window's length, so this line
    // is where its two ends fit.
    if (!wide && _custom != null) return _rangeLabel(wide: true);
    return null;
  }

  /// What the chart's window is called.
  ///
  /// A named window says its own start and end where there is room for them —
  /// which is what a reader who typed them in is looking for — and its length
  /// where there is not: 27 characters of timestamps decide the width of a
  /// header that has to stay one line.
  String _rangeLabel({required bool wide}) {
    final window = _custom;
    if (window == null) return _range.label;
    final span = window.to.difference(window.from).toAgoStr;
    if (!wide) return span;
    return '${_clockOf(window.from.millisecondsSinceEpoch)} – '
        '${_clockOf(window.to.millisecondsSinceEpoch)}';
  }

  /// The ranges, and the way to the ones that are not here.
  ///
  /// Three of them where there is room. On a narrow card only the chosen one,
  /// because three chips plus the picker is most of the header at 320pt — and
  /// in a language whose word for "live" is longer, more than all of it.
  Widget _buildRangeChips(ServerState si, {required bool wide}) {
    final stored = si.capabilities.storedHistory;
    final scheme = Theme.of(context).colorScheme;
    final custom = _custom;
    final selected = _range;
    final inline = custom != null
        ? const <HistoryRange>[]
        : wide
        ? [
            ...HistoryRange.inline,
            if (!HistoryRange.inline.contains(selected)) selected,
          ]
        : [selected];

    Widget chip(HistoryRange range) {
      final on = range == selected;
      final enabled = stored || range == HistoryRange.live;
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
          // The window the reader named, in the place the presets would be:
          // it is what the chart is showing, and leaving a preset highlighted
          // beside it would say the chart is showing that instead.
          if (custom != null)
            Material(
              color: scheme.secondaryContainer,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => _showRangePicker(si),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  child: Text(
                    _rangeLabel(wide: wide),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          if (custom != null) const SizedBox(width: 3),
          InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => _showRangePicker(si),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Icon(
                Icons.date_range,
                size: 16,
                color: custom != null
                    ? scheme.onSecondaryContainer
                    : UIs.textGrey.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Every window this agent can answer for, and the two fields for one it
  /// has not been asked for yet.
  ///
  /// The presets are the common windows, not the limit: which of them are
  /// offered is decided by what the agent said it keeps, and the line at the
  /// bottom is that answer in full. Writing "24 h" into the app and hoping
  /// would draw an empty chart on an agent keeping three hours and call it a
  /// quiet machine.
  Future<void> _showRangePicker(ServerState si) async {
    final stored = si.capabilities.storedHistory;
    final caps = si.agentCapabilities;
    final earliest = caps?.historyFrom;
    final scheme = Theme.of(context).colorScheme;

    // What the fields start at: the window on screen, or the last day.
    final now = DateTime.now();
    var from = _custom?.from ?? now.subtract(const Duration(hours: 24));
    var to = _custom?.to ?? now;

    final picked = await showRowsSheet<({HistoryRange? preset, bool custom})>(
      context,
      rows: (ctx) => [
        StatefulBuilder(
          builder: (_, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final range in HistoryRange.values)
                () {
                  // Beyond what the agent kept, rather than beyond what this
                  // app offers: the row stays, greyed, with the reason — a
                  // window that is simply missing reads as a window this app
                  // decided you could not have.
                  final minutes = range.minutes;
                  final beyond =
                      minutes != null &&
                      earliest != null &&
                      now.subtract(Duration(minutes: minutes)).isBefore(earliest);
                  // A window past a week reaches the agent as `from`/`to`, and
                  // an agent that did not report its retention is one that
                  // predates both — it would clamp to a week and answer for a
                  // window nobody asked for.
                  final unaskable =
                      minutes != null && minutes > 7 * 24 * 60 && caps?.retention == null;
                  final offerable =
                      (stored || range == HistoryRange.live) &&
                      !beyond &&
                      !unaskable;
                  return ListTile(
                    enabled: offerable,
                    selected: _custom == null && range == _range,
                    title: Text(range.label),
                    subtitle: beyond
                        ? Text(l10n.beyondRetention, style: UIs.text12Grey)
                        : null,
                    trailing: _custom == null && range == _range
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: offerable
                        ? () => Navigator.of(
                            ctx,
                          ).pop((preset: range, custom: false))
                        : () => Toast.show(
                            beyond ? l10n.beyondRetention : l10n.historyNoStored,
                          ),
                  );
                }(),
              // Only for an agent that reported its retention, which is also
              // the only one that understands `from`/`to`: an older one clamps
              // to a week and answers for a window nobody asked for, which the
              // chart would then draw as a week of readings inside the window
              // that was typed in.
              if (stored && caps?.retention != null) ...[
                const Divider(height: 17, indent: 17, endIndent: 17),
                for (final bound in [true, false])
                  ListTile(
                    leading: const Icon(Icons.event, size: 20),
                    title: Text(bound ? l10n.from : l10n.to),
                    trailing: Text(
                      _clockOf(
                        (bound ? from : to).millisecondsSinceEpoch,
                      ),
                      style: UIs.text13,
                    ),
                    onTap: () async {
                      final at = await _pickInstant(bound ? from : to);
                      if (at == null) return;
                      setSheetState(() {
                        if (bound) {
                          from = at;
                        } else {
                          to = at;
                        }
                      });
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 7, 17, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Btn.elevated(
                        text: libL10n.ok,
                        onTap: () => Navigator.of(
                          ctx,
                        ).pop((preset: null, custom: true)),
                      ),
                    ],
                  ),
                ),
                // The fact the choice above is made against, said once and in
                // the agent's own terms: what it keeps, and the oldest reading
                // it actually has.
                if (caps != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(17, 13, 17, 5),
                    child: Text(
                      [
                        if (caps.retention case final kept?)
                          l10n.agentRetentionFmt(kept.toAgoStr),
                        if (caps.oldestSample case final oldest?)
                          l10n.oldestSampleFmt(
                            _clockOf(oldest.millisecondsSinceEpoch),
                          ),
                      ].join(' · '),
                      style: UIs.text11Grey,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );

    if (picked == null) return;
    if (picked.preset case final range?) {
      _rebuild(() {
        _custom = null;
        _customAnswer = null;
      });
      await _selectRange(range);
      return;
    }
    if (!to.isAfter(from)) {
      Toast.show(l10n.rangeEndsBeforeItStarts);
      return;
    }
    await _selectCustom(from, to);
  }

  /// A day and a time, in that order — the two questions a platform has a
  /// picker for, rather than a text field that has to be parsed and explained.
  Future<DateTime?> _pickInstant(DateTime initial) async {
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      // A window into readings that do not exist yet is not one to offer, and
      // the far end is whatever an agent could conceivably have kept.
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    // The day picker stops at today; the time picker does not know what time
    // it is, so "today, 23:50" is reachable at 22:00. A window reaching into
    // the future would draw the time that has not happened as a gap in the
    // readings. Clamped rather than refused, because the row shows what it
    // landed on — a tap that silently does nothing is the worse answer.
    final now = DateTime.now();
    return at.isAfter(now) ? now : at;
  }

  /// Asks the agent for a window nobody has asked for before.
  ///
  /// Kept apart from the presets' cache: a named window is asked for once and
  /// replaced by the next one, while the presets are a fixed set worth keeping
  /// as the reader moves between them.
  Future<void> _selectCustom(DateTime from, DateTime to) async {
    if (!mounted) return;
    // Which request this is. A window picked while another is still in flight
    // is the answer that counts, and without this the slower of the two
    // overwrites it on arrival and clears the busy flag the newer one set.
    final generation = ++_historyGeneration;
    _rebuild(() {
      // Every preset request in flight now belongs to a generation that has
      // passed, so its `finally` will not run: left as it is, the range it was
      // fetching stays marked busy, and picking that preset again shows a
      // chart waiting for a request nobody is making.
      _rangeBusy.clear();
      _custom = (from: from, to: to);
      _customAnswer = null;
      _customBusy = true;
    });
    try {
      final samples = await ref
          .read(serverProvider(widget.args.spi.id).notifier)
          .fetchHistoryRange(
            // Sent as well as `from`/`to` so an agent too old for them answers
            // with a window of the same length rather than with its default.
            minutes: to.difference(from).inMinutes.clamp(5, 7 * 24 * 60),
            maxPoints: kHistoryRangePoints,
            from: from,
            to: to,
          );
      if (!mounted || generation != _historyGeneration) return;
      _rebuild(
        () => _customAnswer = (samples: samples, at: DateTime.now()),
      );
    } catch (e, s) {
      Loggers.app.warning('History range for ${widget.args.spi.id}', e, s);
      if (mounted && generation == _historyGeneration) Toast.error('$e');
    } finally {
      if (generation == _historyGeneration) _rebuild(() => _customBusy = false);
    }
  }

  /// Asks the agent for the window, once. The answer is kept until the page
  /// is left: a window an hour wide does not change meaningfully between two
  /// taps, and refetching it on every poll would spend a request a second on
  /// a chart nobody is watching change.
  Future<void> _selectRange(HistoryRange range) async {
    if (!mounted) return;
    _rebuild(() {
      _range = range;
      _custom = null;
      _customAnswer = null;
    });
    final minutes = range.minutes;
    if (minutes == null ||
        _rangeWindows.containsKey(range) ||
        _rangeBusy.contains(range)) {
      return;
    }

    final generation = _historyGeneration;
    _rebuild(() => _rangeBusy.add(range));
    try {
      final to = DateTime.now();
      final samples = await ref
          .read(serverProvider(widget.args.spi.id).notifier)
          .fetchHistoryRange(
            minutes: minutes,
            maxPoints: kHistoryRangePoints,
            // The same window twice: `minutes` is what an agent predating
            // `from`/`to` understands, and it clamps at a week — which is why
            // the windows past that are offered only to an agent that answered
            // with its retention, since only that one has the newer form.
            from: to.subtract(Duration(minutes: minutes)),
            to: to,
          );
      // The page may have been handed another server while this was in
      // flight, and these samples are the previous one's.
      if (!mounted || generation != _historyGeneration) return;
      _rebuild(
        () => _rangeWindows[range] = (samples: samples, at: DateTime.now()),
      );
    } catch (e, s) {
      Loggers.app.warning('History ${range.label} for ${widget.args.spi.id}', e, s);
      if (mounted && generation == _historyGeneration) Toast.error('$e');
    } finally {
      if (generation == _historyGeneration) {
        _rebuild(() => _rangeBusy.remove(range));
      }
    }
  }
}
