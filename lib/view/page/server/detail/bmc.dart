part of 'view.dart';

// --- The BMC card, and the power actions it offers ---

extension on _ServerDetailPageState {
  /// What the BMC says, which is worth showing precisely when the host is not
  /// saying anything.
  ///
  /// Absent unless a [BmcTarget] is linked to this server.
  Widget? _buildBmc(ServerState srv) {
    final target = ref.watch(
      bmcTargetsProvider.select((s) => s.forServer(srv.spi.id)),
    );
    if (target == null) return null;
    final bmc = ref.watch(bmcProvider(target.id));

    final rows = <Widget>[];
    final system = bmc.topology?.system;
    if (system != null) {
      for (final (label, value) in [
        (l10n.virtHwModel, system.model),
        ('BIOS', system.biosVersion),
        ('Serial', system.serial),
        ('Health', system.health),
      ]) {
        if (value == null || value.isEmpty) continue;
        rows.add(ServerDetailReadoutRow(k: label, v: value));
      }
      final boot = system.boot;
      if (boot != null && boot.active) {
        rows.add(
          ServerDetailReadoutRow(
            k: l10n.bmcBoot,
            v: '${boot.target ?? libL10n.unknown} · ${bmcBootEnabledText(boot.enabled!)}',
          ),
        );
      }
    }

    final sensors = bmc.sensors;
    for (final reading in [...sensors.temperatures, ...sensors.fans]) {
      rows.add(
        ServerDetailReadoutRow(
          k: reading.name,
          v: formatBmcReading(reading),
        ),
      );
    }

    final needsCert =
        bmc.failure == RedfishFailure.certificateRejected ||
        bmc.failure == RedfishFailure.certNotReviewed;

    return _buildReadoutCard(
      cardKey: 'bmc',
      icon: Icons.developer_board,
      title: 'BMC',
      mark: Feature.bmc.mark(),
      verdict: switch (bmc) {
        BmcState(failure: final failure?) => (
          text: bmcFailureText(failure, bmc.failureDetail),
          tone: ReadoutVerdict.bad,
        ),
        BmcState(hasData: false, isBusy: true) => null,
        BmcState(powerState: PowerState.on_) => (
          text: l10n.bmcPowerOn,
          tone: ReadoutVerdict.ok,
        ),
        _ => (text: bmcPowerText(bmc.powerState), tone: ReadoutVerdict.warn),
      },
      headline: sensors.watts == null
          ? null
          : (
              value: '${sensors.watts!.toStringAsFixed(0)} W',
              note: [
                for (final fan in sensors.fans.take(1))
                  '${fan.name} ${formatBmcReading(fan)}',
              ].join(),
            ),
      rows: rows,
      extra: [
        if (needsCert)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: OutlinedButton.icon(
              onPressed: () => unawaited(trustBmcTargetCert(context, ref, target)),
              icon: const Icon(Icons.verified_user_outlined, size: 17),
              label: Text(l10n.bmcCert),
            ),
          ),
        if (bmc.hasData) ...[
          BmcPowerActions(target: target, busy: bmc.isPowering),
          BmcManageActions(target: target, bmc: bmc),
        ],
      ],
      footer: readoutFooter([
        readoutCountNote(
          rows.length,
          l10n.unitReadings,
          full: _cardsFull.contains('bmc'),
        ),
        if (bmc.sensorsTruncated) l10n.bmcSensorsTruncated,
        if (bmc.topology?.hasMultipleSystems == true) l10n.bmcMultipleSystems,
      ]),
      initiallyExpanded: _getInitExpand(rows.length),
    );
  }
}
