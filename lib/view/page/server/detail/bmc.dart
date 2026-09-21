part of 'view.dart';

// --- The BMC card, and the power actions it offers ---

extension on _ServerDetailPageState {
  /// What the BMC says, which is worth showing precisely when the host is not
  /// saying anything.
  ///
  /// Absent unless configured: a card that appeared on every server to say
  /// "not configured" would be a row of noise on the machines that have no BMC,
  /// which is most of them.
  Widget? _buildBmc(ServerState si) {
    if (si.spi.bmc == null) return null;
    final bmc = ref.watch(bmcProvider(si.spi));

    final rows = <Widget>[];
    final system = bmc.topology?.system;
    if (system != null) {
      // The service's own property names, shown as it named them: they are
      // protocol identifiers, and translating them would invite drift between
      // what the card says and what the BMC's own interface says
      for (final (label, value) in [
        ('Model', system.model),
        ('BIOS', system.biosVersion),
        ('Serial', system.serial),
        ('Health', system.health),
      ]) {
        if (value == null || value.isEmpty) continue;
        rows.add(ServerDetailReadoutRow(k: label, v: value));
      }
    }

    final sensors = bmc.sensors;
    for (final reading in [...sensors.temperatures, ...sensors.fans]) {
      rows.add(
        ServerDetailReadoutRow(
          k: reading.name,
          v:
              '${reading.value.toStringAsFixed(reading.unit == 'Cel' ? 1 : 0)}'
              '${reading.unit == 'Cel' ? '°C' : ' ${reading.unit ?? ''}'}',
        ),
      );
    }

    return _buildReadoutCard(
      cardKey: 'bmc',
      icon: Icons.developer_board,
      // A suffix here and the full sentence in the editor, which is the
      // arrangement the Linux pages already use: the list that reaches the
      // feature carries the marker, and the place where it is turned on
      // carries the reason. Repeating `betaTip` on a card that is expanded
      // every time the page opens would make it wallpaper.
      title: 'BMC (Beta)',
      verdict: switch (bmc) {
        BmcState(failure: final failure?) => (
          text: _bmcFailureText(failure, bmc.failureDetail),
          tone: ReadoutVerdict.bad,
        ),
        BmcState(hasData: false, isBusy: true) => null,
        BmcState(powerState: PowerState.on) => (
          text: l10n.bmcPowerOn,
          tone: ReadoutVerdict.ok,
        ),
        _ => (text: _bmcPowerText(bmc.powerState), tone: ReadoutVerdict.warn),
      },
      // Draw, not state: what a BMC is asked first is how much the machine is
      // pulling, which is the one reading the host itself cannot give.
      headline: sensors.watts == null
          ? null
          : (
              value: '${sensors.watts!.toStringAsFixed(0)} W',
              note: [
                for (final fan in sensors.fans.take(1))
                  '${fan.name} ${fan.value.toStringAsFixed(0)} ${fan.unit ?? ''}',
              ].join(),
            ),
      rows: rows,
      // Below the readings and never cut off by [kReadoutCardRows]: these are
      // the actions, and a truncated list must not be able to hide them.
      extra: [if (bmc.hasData) _buildBmcPower(si)],
      footer: readoutFooter([
        readoutCountNote(rows.length, l10n.unitReadings),
        // Said rather than left to look like the whole truth
        if (bmc.sensorsTruncated) l10n.bmcSensorsTruncated,
        // The same reason, for the same kind of cut: discovery takes the first
        // of each collection, so a blade enclosure showed node 1's power state
        // with nothing to say the other nodes existed — and a power action
        // there targets that node alone.
        if (bmc.topology?.hasMultipleSystems == true) l10n.bmcMultipleSystems,
      ]),
      initiallyExpanded: _getInitExpand(rows.length),
    );
  }

  /// The power actions this particular service allows, and no others.
  ///
  /// Asked of `plan`, which resolves an intent against
  /// `ResetType@Redfish.AllowableValues`. An intent the service allows nothing
  /// for is not shown: offering a button that fails when pressed is worse than
  /// never having offered it, and `Nmi` and `PowerCycle` are advertised
  /// unimplemented often enough that this is not hypothetical.
  Widget _buildBmcPower(ServerState si) {
    final notifier = ref.read(bmcProvider(si.spi).notifier);
    final available = [
      for (final intent in PowerIntent.values)
        if (notifier.plan(intent) != null) intent,
    ];
    if (available.isEmpty) return UIs.placeholder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final intent in available)
            OutlinedButton(
              onPressed: () => _onTapBmcPower(si, intent),
              child: Text(_bmcIntentText(intent)),
            ),
        ],
      ),
    );
  }

  Future<void> _onTapBmcPower(ServerState si, PowerIntent intent) async {
    final notifier = ref.read(bmcProvider(si.spi).notifier);
    final request = notifier.plan(intent);
    if (request == null) return;

    // The one thing in this app that can take a running server away from
    // whoever is on it. The dialog names the ResetType actually chosen, not the
    // intent, because they differ — a "restart" is ForceRestart on hardware
    // that has no graceful one, and that is worth seeing before agreeing.
    final ok = await context.showRoundDialog<bool>(
      title: _bmcIntentText(intent),
      child: Text(l10n.bmcPowerConfirm(si.spi.name, request.resetType)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;

    final result = await notifier.power(intent);
    switch (result) {
      case BmcPowerResult.confirmed:
        Toast.success(l10n.bmcPowerDone);
      // Accepted is not done, and saying so would be reporting the request
      // back as though it were the result
      case BmcPowerResult.accepted:
        Toast.warn(l10n.bmcPowerAccepted);
      case BmcPowerResult.notSupported:
        Toast.error(libL10n.fail, body: l10n.bmcPowerUnsupported);
      case BmcPowerResult.failed:
        Toast.error(libL10n.fail);
    }
  }

  String _bmcIntentText(PowerIntent intent) => switch (intent) {
    PowerIntent.on => l10n.bmcPowerOnAction,
    PowerIntent.gracefulShutdown => l10n.bmcShutdown,
    PowerIntent.forceOff => l10n.bmcForceOff,
    PowerIntent.restart => l10n.restart,
    PowerIntent.powerCycle => l10n.bmcPowerCycle,
  };

  String _bmcPowerText(PowerState state) => switch (state) {
    PowerState.on => l10n.bmcPowerOn,
    PowerState.off => l10n.bmcPowerOff,
    PowerState.poweringOn || PowerState.poweringOff => libL10n.loadingEllipsis,
    PowerState.paused => 'Paused',
    PowerState.unknown => libL10n.unknown,
  };

  String _bmcFailureText(RedfishFailure failure, String? detail) =>
      switch (failure) {
        RedfishFailure.certificateRejected => l10n.bmcCertRejected,
        RedfishFailure.unauthorized => l10n.bmcUnauthorized,
        RedfishFailure.noCredential => l10n.bmcAccountMissing,
        RedfishFailure.notAService => l10n.bmcNotAService,
        RedfishFailure.noSystem => l10n.bmcNoSystem,
        // Names the resource, because it is an answer about one resource
        RedfishFailure.forbidden => '${libL10n.fail}: ${detail ?? ''}',
        // Retrying after a fresh read is the fix, so it is worth saying that
        // rather than showing a generic failure — this is what a change made
        // through the BMC's own web interface in the meantime looks like.
        RedfishFailure.preconditionRequired => l10n.bmcStaleWrite,
        RedfishFailure.unreachable => detail ?? libL10n.fail,
      };
}
