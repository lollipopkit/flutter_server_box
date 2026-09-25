part of 'view.dart';

// --- The cards under the rows ---

extension on _ServerDetailPageState {
  /// A [ServerDetailReadoutCard] whose being open is the page's to keep —
  /// see [_ServerDetailPageState._cardsOpen]. Opened on first use if
  /// [initiallyExpanded], and as [_getInitExpand] says when that is not given.
  Widget _buildReadoutCard({
    required String cardKey,
    required IconData icon,
    required String title,
    Widget? mark,
    ({String text, ReadoutVerdict tone})? verdict,
    ({String value, String note})? headline,
    List<Widget> rows = const [],
    List<Widget> extra = const [],
    String footer = '',
    VoidCallback? onTap,
    bool? initiallyExpanded,
  }) {
    return ServerDetailReadoutCard(
      icon: icon,
      title: title,
      mark: mark,
      verdict: verdict,
      headline: headline,
      rows: rows,
      extra: extra,
      footer: footer,
      onTap: onTap,
      expanded:
          ServerDetailReadoutCard.expandable(
            onTap: onTap,
            rows: rows,
            extra: extra,
          ) &&
          _cardExpanded(
            cardKey,
            initiallyExpanded ?? _getInitExpand(rows.length),
          ),
      onToggle: () => _rebuild(() => _toggleCard(cardKey)),
    );
  }

  /// The card a section gets when its command could not be read.
  ///
  /// A card that hides when it is empty answers "this machine has none of
  /// these", which is the wrong answer for a machine whose `smartctl` is not
  /// installed or whose `sensors` is not permitted — and it is the answer this
  /// page gave for as long as the failure was invisible. So the card is drawn,
  /// with what the command said in place of the table.
  ///
  /// Not an alarm. A metric row that failed goes red because a reading
  /// disappeared from where one had been; here nothing disappeared, and what
  /// the card owes the reader is the reason, not a warning. The raw text is
  /// behind the same expander the rows would have been, because it is a shell's
  /// wording rather than this app's and it is what a bug report needs.
  Widget _buildFailedCard({
    required String cardKey,
    required IconData icon,
    required String title,
    required String err,
  }) {
    return _buildReadoutCard(
      cardKey: cardKey,
      icon: icon,
      title: title,
      headline: (value: l10n.unavailable, note: err.split('\n').first),
      extra: [
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 0, 17, 7),
          child: SelectableText(
            err,
            style: UIs.text12Grey.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ],
      footer: l10n.metricUnavailableTip,
      initiallyExpanded: false,
    );
  }

  bool _getInitExpand(int len, [int? max]) {
    if (!_collapse) return true;
    if (_size.width > UIs.columnWidth) return true;
    return len > 0 && len <= (max ?? 3);
  }

  void _showClosableDetailDialog({
    required String title,
    required Widget child,
  }) {
    context.showRoundDialog(
      title: title,
      child: child,
      actions: [
        TextButton(onPressed: () => context.popDialog(), child: Text(libL10n.close)),
      ],
    );
  }

  /// The cards, not the load: what a GPU is doing is the row above, and what
  /// is left is a table — the memory each card has left, its clock and fans,
  /// and the processes holding that memory.
  Widget? _buildGpuView(ServerState si) {
    final gpus = si.status.gpus;
    if (gpus.isEmpty) return null;
    final mem = busiestGpu(si.status)?.memory;
    final processes = [for (final gpu in gpus) ...?gpu.memory?.processes];

    return _buildReadoutCard(
      cardKey: 'gpu',
      icon: ServerDetailCards.gpu.icon,
      title: 'GPU',
      headline: mem == null
          ? null
          : (
              value: '${mem.used} ${mem.unit}',
              note: [
                l10n.ofFmt('${mem.total} ${mem.unit}'),
                if (processes.isNotEmpty) l10n.processesFmt(processes.length),
              ].join(' · '),
            ),
      rows: gpus.map(_buildGpuItem).toList(),
      footer: readoutCountNote(gpus.length, l10n.unitGpus),
      initiallyExpanded: _getInitExpand(gpus.length, 3),
    );
  }

  Widget _buildGpuItem(GpuItem item) {
    final mem = item.memory;
    final details = [
      ?item.power,
      if (item.fanSpeed != null)
        '${l10n.fan} ${item.fanSpeed}${item.vendor == 'nvidia' ? '%' : ' RPM'}',
      if (item.clockSpeed != null) '${item.clockSpeed} MHz',
      if (mem != null) '${mem.used} / ${mem.total} ${mem.unit}',
    ];
    return ServerDetailReadoutRow(
      k: '${item.name} · ${item.id}',
      sub: details.isEmpty ? null : details.join(' · '),
      v: [
        if (item.utilization case final util?) ReadingFmt.pct(util),
        if (item.temperature case final t?) ReadingFmt.temp(t.toDouble()),
      ].join(' · '),
      // Every card, not only the ones holding a process: the row is one line
      // of a card that has a dozen readings, and which of them fit there is
      // not a reason to make some cards openable and others dead.
      onTap: () => _onTapGpuItem(item),
    );
  }

  /// One card in full: every reading it reports, and what is holding its
  /// memory.
  ///
  /// The row above carries the two figures that fit on a line — load and
  /// temperature — and this is the rest, in the order it is read in: what the
  /// card is, what it is doing, then who is doing it. A process list on its
  /// own was what this used to be, which left a card reporting no processes
  /// with nothing to open at all.
  void _onTapGpuItem(GpuItem item) {
    final mem = item.memory;
    final scheme = Theme.of(context).colorScheme;
    final rows = <({String k, String v})>[
      if (item.utilization case final util?) (k: l10n.used, v: ReadingFmt.pct(util)),
      if (item.temperature case final t?)
        (k: libL10n.temperature, v: ReadingFmt.temp(t.toDouble())),
      if (item.power case final power?) (k: l10n.power, v: power),
      if (item.fanSpeed case final fan?)
        (k: l10n.fan, v: '$fan${item.vendor == 'nvidia' ? '%' : ' RPM'}'),
      if (item.clockSpeed case final clock?)
        (k: l10n.clockSpeed, v: '$clock MHz'),
      if (mem != null)
        (k: libL10n.memory, v: '${mem.used} / ${mem.total} ${mem.unit}'),
      (k: l10n.vendor, v: item.vendor),
    ];
    final processes = mem?.processes ?? const <GpuSmiMemProcess>[];

    showRowsSheet<void>(
      context,
      rows: (_) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 5, 17, 9),
          child: Text(
            '${item.name} · ${item.id}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ),
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 17, endIndent: 17),
          ServerDetailReadoutRow(k: row.k, v: row.v),
        ],
        if (processes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 5),
            child: Text(
              l10n.processesFmt(processes.length),
              style: UIs.text11Grey.copyWith(color: scheme.primary),
            ),
          ),
          for (final process in processes)
            ServerDetailReadoutRow(
              k: process.name,
              sub: 'PID ${process.pid}',
              v: '${process.memory} MiB',
            ),
        ],
      ],
    );
  }

  /// Every drive's health in one card, worst first.
  ///
  /// Six drives are not six cards: what is read off this is one conclusion —
  /// whether anything is failing — and the rows are what to look at once the
  /// answer is no longer "all of them passed". The attributes behind a drive
  /// are two dozen numbers and stay one tap away.
  Widget? _buildDiskSmart(ServerState si) {
    final smarts = si.status.diskSmart;
    if (smarts.isEmpty) {
      // `smartctl` is missing, or is there and refused: both are why this card
      // was empty, and neither was ever said. A host with no drives it can read
      // still gets nothing.
      if (si.status.sectionErrs['smart'] case final err?) {
        return _buildFailedCard(
          cardKey: 'smart',
          icon: ServerDetailCards.smart.icon,
          title: l10n.diskHealth,
          err: err,
        );
      }
      return null;
    }

    // Worst first, which is the order the rows are read in and what the
    // headline is about. A drive smartctl could not read sorts between a
    // failing one and a passing one: it is not a drive that is fine.
    final sorted = [...smarts]
      ..sort((a, b) => _smartRank(a).compareTo(_smartRank(b)));
    final worst = sorted.first;
    final wrong = smarts.where((e) => _smartRank(e) < _smartRank(_smartOk));

    DiskSmart? hottest;
    int? oldest;
    for (final smart in smarts) {
      final t = smart.temperature;
      if (t != null && (hottest == null || t > hottest.temperature!)) {
        hottest = smart;
      }
      final hours = smart.powerOnHours;
      if (hours != null && (oldest == null || hours > oldest)) oldest = hours;
    }

    final truncated = smarts.length > kReadoutCardRows;
    return _buildReadoutCard(
      cardKey: 'smart',
      icon: ServerDetailCards.smart.icon,
      title: l10n.diskHealth,
      verdict: _smartVerdict(smarts),
      // The worst conclusion, not a count of drives: what this card answers is
      // whether anything needs replacing, and on the machine where something
      // does, which one and what it said.
      headline: wrong.isEmpty
          ? (
              value: l10n.devicesFmt(smarts.length),
              note: [
                if (hottest?.temperature case final t?)
                  '${l10n.hottest} ${ReadingFmt.temp(t)}',
                if (oldest != null) '${l10n.oldest} $oldest ${libL10n.hour}',
              ].join(' · '),
            )
          : (
              // `(total, wrong)`: with no `@` metadata gen-l10n orders the
              // placeholders alphabetically, not as the sentence reads them.
              value: l10n.diskWrongOfFmt(smarts.length, wrong.length),
              note: '${worst.device} · ${_smartSummary(worst)}',
            ),
      rows: sorted.map(_buildDiskSmartItem).toList(),
      footer: readoutFooter([
        truncated
            ? l10n.shownOfFmt(kReadoutCardRows, smarts.length, l10n.unitDevices)
            : l10n.countOfFmt(smarts.length, l10n.unitDevices),
        truncated ? l10n.diskSmartOpenTip : l10n.diskSmartSortedTip,
      ]),
      initiallyExpanded: _getInitExpand(smarts.length),
    );
  }

  /// A passing drive, to rank the others against.
  static const _smartOk = DiskSmart(
    device: '',
    healthy: true,
    rawData: {},
    smartAttributes: {},
  );

  /// Worst first: failing, then whatever reports a non-zero critical count,
  /// then a drive that answered nothing, then the ones that passed. A device
  /// SMART does not apply to is last — it is not a drive with a problem.
  static int _smartRank(DiskSmart smart) {
    if (smart.notApplicable) return 4;
    if (smart.healthy == false) return 0;
    if (smart.faults.isNotEmpty) return 1;
    if (smart.healthy == null) return 2;
    return 3;
  }

  ({String text, ReadoutVerdict tone})? _smartVerdict(List<DiskSmart> smarts) {
    final failing = smarts.where((e) => e.healthy == false).length;
    if (failing > 0) {
      return (text: l10n.diskFailingFmt(failing), tone: ReadoutVerdict.bad);
    }
    final warning = smarts
        .where((e) => !e.notApplicable && (e.healthy == null || e.faults.isNotEmpty))
        .length;
    if (warning > 0) {
      return (text: l10n.diskWarningFmt(warning), tone: ReadoutVerdict.warn);
    }
    return (text: l10n.diskAllPassed, tone: ReadoutVerdict.ok);
  }

  /// What a drive says about itself in one phrase: the first count that should
  /// have been zero, or SMART's own verdict when they all are.
  String _smartSummary(DiskSmart smart) {
    if (smart.notApplicable) return l10n.notApplicable;
    final fault = smart.faults.entries.firstOrNull;
    if (fault != null) return '${fault.value} ${fault.key}';
    return switch (smart.healthy) {
      null => libL10n.unknown,
      true => 'PASSED',
      false => 'FAILING',
    };
  }

  Widget _buildDiskSmartItem(DiskSmart smart) {
    final applicable = !smart.notApplicable;
    return ServerDetailReadoutRow(
      k: smart.device,
      sub: smart.model,
      v: [
        _smartSummary(smart),
        if (smart.temperature case final t?) ReadingFmt.temp(t),
      ].join(' · '),
      dot: _smartTone(smart).color(Theme.of(context).colorScheme),
      // Nothing to open for a device with no attributes, and a chevron that
      // opens an empty sheet is worse than no chevron.
      onTap: applicable ? () => _onTapDiskSmartItem(smart) : null,
    );
  }

  ReadoutVerdict _smartTone(DiskSmart smart) {
    if (smart.notApplicable) return ReadoutVerdict.idle;
    if (smart.healthy == false) return ReadoutVerdict.bad;
    if (smart.healthy == null || smart.faults.isNotEmpty) {
      return ReadoutVerdict.warn;
    }
    return ReadoutVerdict.ok;
  }

  /// One drive's attributes: the readings the card has no room for.
  ///
  /// Two dozen numbers do not belong on the page — the card carries the
  /// verdict and this carries the evidence, in the order it is read in: the
  /// health line first, then the counts that should be zero, then how much
  /// the drive has been used. Each count that is not zero keeps its dot, so
  /// the row that made the card say "1 warning" is the one that stands out
  /// here too.
  void _onTapDiskSmartItem(DiskSmart smart) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <({String k, String v, ReadoutVerdict? dot})>[
      (
        k: l10n.diskHealth,
        v: switch (smart.healthy) {
          null => libL10n.unknown,
          true => 'PASSED',
          false => 'FAILING',
        },
        dot: _smartTone(smart),
      ),
      for (final entry in DiskSmart.criticalAttributes.entries)
        if (smart.getAttribute(entry.key)?.rawValue case final raw?)
          (
            k: entry.value.label,
            v: '$raw',
            // Read as the count the card read it as, so a row without a dot
            // here is never one the card counted as a fault.
            dot: (DiskSmart.countOf(raw) ?? 0) > 0 ? ReadoutVerdict.warn : null,
          ),
      if (smart.powerOnHours case final hours?)
        (k: l10n.powerOnHours, v: '$hours', dot: null),
      if (smart.powerCycleCount case final cycles?)
        (k: l10n.powerCycles, v: '$cycles', dot: null),
      if (smart.ssdLifeLeft case final left?)
        (k: l10n.lifeLeft, v: '$left%', dot: null),
      if (smart.temperature case final t?)
        (k: libL10n.temperature, v: ReadingFmt.temp(t), dot: null),
      if (smart.lifetimeWritesGiB case final written?)
        (k: l10n.lifetimeWrite, v: '$written GiB', dot: null),
      if (smart.lifetimeReadsGiB case final read?)
        (k: l10n.lifetimeRead, v: '$read GiB', dot: null),
      if (smart.averageEraseCount case final erases?)
        (k: l10n.averageErase, v: '$erases', dot: null),
      if (smart.unsafeShutdownCount case final unsafe?)
        (k: l10n.unsafeShutdowns, v: '$unsafe', dot: null),
      if (smart.model case final model?) (k: 'Model', v: model, dot: null),
      if (smart.serial case final serial?) (k: 'Serial', v: serial, dot: null),
    ];

    showRowsSheet<void>(
      context,
      rows: (_) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 5, 17, 9),
          child: Text(
            '${smart.device} · ${l10n.attributes}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ),
        for (final (i, row) in rows.indexed) ...[
          // A line between the readings, not around them: this is a table of
          // numbers and the rule is what keeps a name with its own value.
          if (i > 0) const Divider(height: 1, indent: 17, endIndent: 17),
          ServerDetailReadoutRow(
            k: row.k,
            v: row.v,
            dot: row.dot?.color(scheme),
          ),
        ],
        // Where the numbers came from and when: SMART is read on the extended
        // cadence, so these are minutes old while everything else on the page
        // is seconds old. The command is the other half of the answer — it is
        // what to run to see the same thing.
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 13, 17, 5),
          child: Text(
            [
              'smartctl -A /dev/${smart.device}',
              if (ref.read(serverProvider(widget.args.spi.id))
                      .status
                      .diskSmartAt
                  case final at?)
                l10n.readAgoFmt(at.toAgoStr()),
            ].join(' · '),
            style: UIs.text11Grey.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  /// Every battery but the first, which is the row's.
  ///
  /// A host reporting several is reporting its peripherals — a mouse, a
  /// keyboard, a headset — and those are a table: a name, a state and a charge
  /// each, with no line worth drawing behind any of them. A machine with one
  /// battery has no card at all, because the row already says everything this
  /// would.
  Widget? _buildBatteries(ServerState si) {
    final ss = si.status;
    if (ss.batteries.length < 2) return null;

    return _buildReadoutCard(
      cardKey: 'battery',
      icon: ServerDetailCards.battery.icon,
      title: libL10n.battery,
      rows: ss.batteries.map(_buildBatteryItem).toList(),
      footer: readoutCountNote(ss.batteries.length, l10n.unitBatteries),
      initiallyExpanded: _getInitExpand(ss.batteries.length, 2),
    );
  }

  Widget _buildBatteryItem(Battery battery) {
    return ServerDetailReadoutRow(
      k: battery.name ?? libL10n.unknown,
      sub: [
        battery.status.name,
        if (battery.cycle case final cycle?) '${l10n.cycle} $cycle',
      ].join(' · '),
      v: ReadingFmt.pct(battery.percent?.toDouble()),
    );
  }

  /// What `sensors` reports, which is a table and stays one: a summary line
  /// per chip, and the readings behind it on tap.
  Widget? _buildSensors(ServerState si) {
    final ss = si.status;
    if (ss.sensors.isEmpty) {
      if (ss.sectionErrs['sensors'] case final err?) {
        return _buildFailedCard(
          cardKey: 'sensor',
          icon: Icons.thermostat,
          title: libL10n.sensors,
          err: err,
        );
      }
      return null;
    }

    return _buildReadoutCard(
      cardKey: 'sensor',
      icon: Icons.thermostat,
      title: libL10n.sensors,
      rows: ss.sensors.map(_buildSensorItem).toList(),
      footer: readoutCountNote(ss.sensors.length, l10n.unitSensors),
      initiallyExpanded: _getInitExpand(ss.sensors.length, 2),
    );
  }

  Widget _buildSensorItem(SensorItem si) {
    return ServerDetailReadoutRow(
      k: si.device,
      sub: si.summary,
      v: si.adapter.raw,
      onTap: si.summary == null ? null : () => _onTapSensorItem(si),
    );
  }

  void _onTapSensorItem(SensorItem si) {
    context.showRoundDialog(
      title: si.device,
      child: SingleChildScrollView(
        child: SimpleMarkdown(
          data: si.toMarkdown,
          styleSheet: MarkdownStyleSheet(
            tableBorder: TableBorder.all(color: Colors.grey),
            tableHead: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget? _buildPve(ServerState si) {
    // One primary-key lookup; the row is not part of `Spi`.
    if (Stores.pve.fetch(si.spi.id) == null) return null;
    // Nothing is read here: the guests are the Virtualization tab's, and this
    // card is the way to them rather than a summary of what they will say.
    // The host is asked for before the tab, so a tab built by the switch finds
    // the request already waiting.
    return _buildReadoutCard(
      cardKey: 'pve',
      icon: FontAwesome.server_solid,
      title: 'PVE',
      onTap: () {
        ref.read(virtHostRequestProvider.notifier).go(si.spi.id);
        ref.read(homeTabRequestProvider.notifier).go(AppTab.virt);
      },
    );
  }

  Widget? _buildCustomCmd(ServerState si) {
    final ss = si.status;
    if (ss.customCmds.isEmpty) return null;
    return _buildReadoutCard(
      cardKey: 'custom',
      icon: MingCute.command_line,
      title: l10n.customCmd,
      rows: ss.customCmds.entries.map(_buildCustomCmdItem).toList(),
      footer: readoutCountNote(ss.customCmds.length, l10n.unitCommands),
      initiallyExpanded: _getInitExpand(ss.customCmds.length),
    );
  }

  Widget _buildCustomCmdItem(MapEntry<String, String> cmd) {
    // A command that printed several lines has only its first on the row; the
    // rest is what tapping opens, because a row is one line by construction.
    final lines = cmd.value.split('\n');
    return ServerDetailReadoutRow(
      k: cmd.key,
      v: lines.first,
      onTap: lines.length > 1 ? () => _onTapCustomItem(cmd) : null,
    );
  }

  void _onTapCustomItem(MapEntry<String, String> cmd) {
    _showClosableDetailDialog(
      title: cmd.key,
      child: SingleChildScrollView(
        child: Text(cmd.value, style: UIs.text13Grey),
      ),
    );
  }
}
