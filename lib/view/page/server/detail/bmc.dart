part of 'view.dart';

// --- The BMC card, and the power actions it offers ---

extension on _ServerDetailPageState {
  /// What the BMC says, which is worth showing precisely when the host is not
  /// saying anything.
  ///
  /// Absent unless configured: a card that appeared on every server to say
  /// "not configured" would be a row of noise on the machines that have no BMC,
  /// which is most of them.
  Widget? _buildBmc(ServerState srv) {
    if (srv.spi.bmc == null) return null;
    final bmc = ref.watch(bmcProvider(srv.spi));

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
      final boot = system.boot;
      if (boot != null && boot.active) {
        rows.add(
          ServerDetailReadoutRow(
            k: l10n.bmcBoot,
            v: '${boot.target ?? libL10n.unknown} · ${_bmcBootEnabledText(boot.enabled!)}',
          ),
        );
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
      // The mark beside the name rather than `(Beta)` inside it, and the full
      // sentence still in the editor, which is the arrangement the Linux pages
      // already use: the place that reaches the feature carries the marker,
      // and the place where it is turned on carries the reason. Repeating
      // `betaTip` on a card that is expanded every time the page opens would
      // make it wallpaper.
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
      extra: [
        if (bmc.hasData) ...[
          _buildBmcPower(srv, busy: bmc.isPowering),
          _buildBmcManage(srv, bmc),
        ],
      ],
      footer: readoutFooter([
        readoutCountNote(
          rows.length,
          l10n.unitReadings,
          full: _cardsFull.contains('bmc'),
        ),
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
  ///
  /// [busy] while an action is being confirmed: one at a time.
  Widget _buildBmcPower(ServerState srv, {required bool busy}) {
    final notifier = ref.read(bmcProvider(srv.spi).notifier);
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
              onPressed: busy ? null : () => _onTapBmcPower(srv, intent),
              child: Text(_bmcIntentText(intent)),
            ),
        ],
      ),
    );
  }

  /// What else the BMC can do for this machine, each offered only where the
  /// service lists it.
  Widget _buildBmcManage(ServerState srv, BmcState bmc) {
    final system = bmc.topology?.system;
    if (system == null) return UIs.placeholder;
    final args = SpiRequiredArgs(srv.spi);
    final locator = system.locator;
    final boot = system.boot;
    final hasMedia =
        system.virtualMedia != null || bmc.topology?.manager?.virtualMedia != null;
    final hasLogs =
        system.logServices != null || bmc.topology?.manager?.logServices != null;
    final busy = bmc.isPowering;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          if (hasLogs)
            OutlinedButton.icon(
              onPressed: () => BmcLogsPage.route.go(context, args),
              icon: const Icon(Icons.receipt_long, size: 17),
              label: Text(libL10n.logs),
            ),
          if (system.storage != null || system.simpleStorage != null)
            OutlinedButton.icon(
              onPressed: () => BmcDrivesPage.route.go(context, args),
              icon: const Icon(Icons.storage, size: 17),
              label: Text(l10n.bmcDrives),
            ),
          if (boot != null && boot.settableTargets.isNotEmpty)
            OutlinedButton.icon(
              onPressed: busy ? null : () => _onTapBmcBoot(srv, boot),
              icon: const Icon(Icons.start, size: 17),
              label: Text(l10n.bmcBoot),
            ),
          if (hasMedia)
            OutlinedButton.icon(
              onPressed: busy ? null : () => _onTapBmcMedia(srv),
              icon: const Icon(Icons.album, size: 17),
              label: Text(l10n.bmcVirtualMedia),
            ),
          if (locator != null)
            FilterChip(
              avatar: Icon(
                locator.lit ? Icons.lightbulb : Icons.lightbulb_outline,
                size: 17,
              ),
              showCheckmark: false,
              label: Text(l10n.bmcLocator),
              selected: locator.lit,
              onSelected: busy
                  ? null
                  : (on) => context.bmcRun(
                      () => ref.read(bmcProvider(srv.spi).notifier).setLocator(on),
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _onTapBmcBoot(ServerState srv, BootOverride boot) async {
    final start = bmcBootDefault(boot: boot);
    if (start == null) return;
    final picked = ValueNotifier(start);
    final ok = await context.showSheet<bool>(
      title: l10n.bmcBoot,
      child: _BmcBootForm(boot: boot, picked: picked),
      actions: Btnx.cancelOk,
    );
    final request = picked.value;
    picked.dispose();
    if (ok != true || !mounted) return;
    final notifier = ref.read(bmcProvider(srv.spi).notifier);
    await context.bmcRun(() => notifier.setBoot(request));
  }

  Future<void> _onTapBmcMedia(ServerState srv) async {
    final notifier = ref.read(bmcProvider(srv.spi).notifier);
    final (slots, err) = await context.showLoadingSheet(
      fn: notifier.mediaSlots,
      showErr: false,
      timeout: const Duration(minutes: 2),
    );
    if (!mounted) return;
    if (err != null || slots == null) {
      Toast.error(libL10n.fail, body: err == null ? null : bmcErrorText(err));
      return;
    }
    if (slots.isEmpty) {
      Toast.info(libL10n.empty);
      return;
    }
    await context.showSheet<void>(
      title: l10n.bmcVirtualMedia,
      childBuilder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final slot in slots)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(slot.inserted ? Icons.album : Icons.radio_button_unchecked),
              title: Text(slot.name ?? slot.id ?? slot.path),
              subtitle: Text(
                slot.image ?? slot.mediaTypes.join(', '),
                style: UIs.text12Grey,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: slot.inserted
                  ? TextButton(
                      onPressed: () => _bmcEject(ctx, notifier, slot),
                      child: Text(l10n.bmcEjectMedia),
                    )
                  : TextButton(
                      onPressed: () => _bmcInsert(ctx, notifier, slot),
                      child: Text(l10n.bmcInsertMedia),
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _bmcInsert(
    BuildContext ctx,
    BmcNotifier notifier,
    MediaSlot slot,
  ) async {
    final image = (await ctx.showInputSheet(
      title: l10n.bmcInsertMedia,
      label: l10n.bmcImageUrl,
      hint: 'https://10.0.0.2/os.iso',
      type: TextInputType.url,
    ))?.trim();
    if (image == null || image.isEmpty || !ctx.mounted) return;
    if (!bmcIsImageUrl(image: image)) {
      Toast.error(l10n.bmcImageUrlInvalid);
      return;
    }
    if (await ctx.bmcRun(() => notifier.insertMedia(slot, image)) && ctx.mounted) {
      ctx.popSheet();
    }
  }

  Future<void> _bmcEject(
    BuildContext ctx,
    BmcNotifier notifier,
    MediaSlot slot,
  ) async {
    if (await ctx.bmcRun(() => notifier.ejectMedia(slot)) && ctx.mounted) {
      ctx.popSheet();
    }
  }

  Future<void> _onTapBmcPower(ServerState srv, PowerIntent intent) async {
    final notifier = ref.read(bmcProvider(srv.spi).notifier);
    final request = notifier.plan(intent);
    if (request == null) return;

    // The one thing in this app that can take a running server away from
    // whoever is on it. The dialog names the ResetType actually chosen, not the
    // intent, because they differ — a "restart" is ForceRestart on hardware
    // that has no graceful one, and that is worth seeing before agreeing.
    final ok = await context.showSheet<bool>(
      title: _bmcIntentText(intent),
      child: Text(l10n.bmcPowerConfirm(srv.spi.name, request.resetType)),
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
    PowerIntent.on_ => l10n.bmcPowerOnAction,
    PowerIntent.gracefulShutdown => l10n.bmcShutdown,
    PowerIntent.forceOff => l10n.bmcForceOff,
    PowerIntent.restart => l10n.restart,
    PowerIntent.powerCycle => l10n.bmcPowerCycle,
  };

  String _bmcPowerText(PowerState state) => switch (state) {
    PowerState.on_ => l10n.bmcPowerOn,
    PowerState.off => l10n.bmcPowerOff,
    PowerState.poweringOn || PowerState.poweringOff => libL10n.loadingEllipsis,
    PowerState.paused => 'Paused',
    PowerState.unknown => libL10n.unknown,
  };

}

String _bmcBootEnabledText(String enabled) => switch (enabled) {
  'Disabled' => l10n.bmcBootDisabled,
  'Once' => l10n.bmcBootOnce,
  'Continuous' => l10n.bmcBootContinuous,
  _ => enabled,
};

final class _BmcBootForm extends StatelessWidget {
  final BootOverride boot;
  final ValueNotifier<BootRequest> picked;

  const _BmcBootForm({required this.boot, required this.picked});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: picked,
      builder: (_, req, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 13,
        children: [
          _group(
            l10n.bmcBootTarget,
            boot.settableTargets,
            req.target,
            (v) => BootRequest(target: v, enabled: req.enabled, mode: req.mode),
          ),
          _group(
            libL10n.mode,
            boot.enabledValues,
            req.enabled,
            (v) => BootRequest(target: req.target, enabled: v, mode: req.mode),
            text: _bmcBootEnabledText,
          ),
          if (boot.modes.length > 1)
            _group(
              'BIOS',
              boot.modes,
              req.mode ?? boot.mode,
              // The one in effect is left as it is: `None` sends nothing.
              (v) => BootRequest(
                target: req.target,
                enabled: req.enabled,
                mode: v == boot.mode ? null : v,
              ),
            ),
        ],
      ),
    );
  }

  Widget _group(
    String title,
    List<String> values,
    String? current,
    BootRequest Function(String) pick, {
    String Function(String)? text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 7,
      children: [
        Text(title, style: UIs.text13Grey),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(text?.call(v) ?? v),
                selected: v == current,
                onSelected: (_) => picked.value = pick(v),
              ),
          ],
        ),
      ],
    );
  }
}
