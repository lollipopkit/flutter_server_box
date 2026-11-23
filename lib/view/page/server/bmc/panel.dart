import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/bmc/common.dart';
import 'package:server_box/view/page/server/bmc/drives.dart';
import 'package:server_box/view/page/server/bmc/logs.dart';

/// Power action buttons offered for a BMC target, filtered to the actions the
/// Redfish service actually advertises.
final class BmcPowerActions extends ConsumerWidget {
  final BmcTarget target;
  final bool busy;
  final EdgeInsetsGeometry padding;

  const BmcPowerActions({
    super.key,
    required this.target,
    required this.busy,
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
  });

  static List<PowerIntent> availableIntents(BmcNotifier notifier) => [
    for (final intent in PowerIntent.values)
      if (notifier.plan(intent) != null) intent,
  ];

  static IconData iconOf(PowerIntent intent) => switch (intent) {
    PowerIntent.on_ => Icons.power_settings_new,
    PowerIntent.gracefulShutdown => Icons.power_off_outlined,
    PowerIntent.forceOff => Icons.bolt,
    PowerIntent.restart => Icons.restart_alt,
    PowerIntent.powerCycle => Icons.sync,
  };

  static bool isDestructive(PowerIntent intent) =>
      intent == PowerIntent.forceOff || intent == PowerIntent.powerCycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(bmcProvider(target.id).notifier);
    final available = availableIntents(notifier);
    if (available.isEmpty) return UIs.placeholder;

    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final intent in available)
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => runPower(context, ref, target, intent),
              child: Text(bmcIntentText(intent)),
            ),
        ],
      ),
    );
  }

  /// Opens a bottom sheet listing all supported [PowerIntent]s for [target] and
  /// runs the picked intent behind the standard confirmation sheet.
  static Future<void> showAllSheet(
    BuildContext context,
    WidgetRef ref,
    BmcTarget target,
  ) async {
    final notifier = ref.read(bmcProvider(target.id).notifier);
    final available = availableIntents(notifier);
    if (available.isEmpty) return;

    final picked = await showRowsSheet<PowerIntent>(
      context,
      rows: (ctx) => [
        for (final intent in available)
          ListTile(
            leading: Icon(
              iconOf(intent),
              size: 20,
              color: isDestructive(intent) ? StatePalette.failed : null,
            ),
            title: Text(
              bmcIntentText(intent),
              style: isDestructive(intent)
                  ? const TextStyle(color: StatePalette.failed)
                  : null,
            ),
            onTap: () => Navigator.of(ctx).pop(intent),
          ),
      ],
    );
    if (picked == null || !context.mounted) return;
    await runPower(context, ref, target, picked);
  }

  static Future<void> runPower(
    BuildContext context,
    WidgetRef ref,
    BmcTarget target,
    PowerIntent intent,
  ) async {
    final notifier = ref.read(bmcProvider(target.id).notifier);
    final request = notifier.plan(intent);
    if (request == null) return;
    final expectedAddr = target.addr.trim();
    final expectedCert = target.certSha256;

    final ok = await context.showSheet<bool>(
      title: bmcIntentText(intent),
      child: Text(l10n.bmcPowerConfirm(target.name, request.resetType)),
      actions: isDestructive(intent) ? Btnx.cancelRedOk : Btnx.cancelOk,
    );
    if (ok != true || !context.mounted) return;

    final currentTarget = ref.read(bmcTargetsProvider).targets[target.id];
    if (currentTarget != null &&
        (currentTarget.addr.trim() != expectedAddr ||
            currentTarget.certSha256 != expectedCert)) {
      Toast.error(libL10n.fail, body: l10n.bmcStaleWrite);
      return;
    }

    final liveNotifier = ref.read(bmcProvider(target.id).notifier);
    final currentPlan = liveNotifier.plan(intent);
    if (currentPlan == null ||
        currentPlan.target != request.target ||
        currentPlan.resetType != request.resetType) {
      Toast.error(libL10n.fail, body: l10n.bmcStaleWrite);
      return;
    }

    final result = await liveNotifier.power(intent, expectedRequest: request);
    switch (result) {
      case BmcPowerResult.confirmed:
        Toast.success(l10n.bmcPowerDone);
      case BmcPowerResult.accepted:
        Toast.warn(l10n.bmcPowerAccepted);
      case BmcPowerResult.notSupported:
        Toast.error(libL10n.fail, body: l10n.bmcPowerUnsupported);
      case BmcPowerResult.failed:
        Toast.error(libL10n.fail);
    }
  }
}

/// Management action chips/buttons (logs, drives, boot override, virtual media,
/// locator LED) shared by `ServerDetailPage` and standalone `BmcDetailPage`.
final class BmcManageActions extends ConsumerWidget {
  final BmcTarget target;
  final BmcState bmc;
  final EdgeInsetsGeometry padding;

  const BmcManageActions({
    super.key,
    required this.target,
    required this.bmc,
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system = bmc.topology?.system;
    if (system == null) return UIs.placeholder;
    final args = BmcTargetRequiredArgs(target);
    final locator = system.locator;
    final boot = system.boot;
    final hasMedia =
        system.virtualMedia != null ||
        bmc.topology?.manager?.virtualMedia != null;
    final hasLogs =
        system.logServices != null ||
        bmc.topology?.manager?.logServices != null;
    final busy = bmc.isPowering;

    return Padding(
      padding: padding,
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
              onPressed: busy
                  ? null
                  : () => openBootSheet(context, ref, target, boot),
              icon: const Icon(Icons.start, size: 17),
              label: Text(l10n.bmcBoot),
            ),
          if (hasMedia)
            OutlinedButton.icon(
              onPressed: busy ? null : () => openMediaSheet(context, ref, target),
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
                  : (on) => context.bmcRunTask(
                      () => ref.read(bmcProvider(target.id).notifier).setLocator(on),
                    ),
            ),
        ],
      ),
    );
  }

  static Future<void> openBootSheet(
    BuildContext context,
    WidgetRef ref,
    BmcTarget target,
    BootOverride boot,
  ) async {
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
    if (ok != true || !context.mounted) return;
    final notifier = ref.read(bmcProvider(target.id).notifier);
    await context.bmcRunTask(() => notifier.setBoot(request));
  }

  static Future<void> openMediaSheet(
    BuildContext context,
    WidgetRef ref,
    BmcTarget target,
  ) async {
    final notifier = ref.read(bmcProvider(target.id).notifier);
    final (slots, err) = await context.showLoadingSheet(
      fn: notifier.mediaSlots,
      showErr: false,
      timeout: const Duration(minutes: 2),
    );
    if (!context.mounted) return;
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
              leading: Icon(
                slot.inserted ? Icons.album : Icons.radio_button_unchecked,
              ),
              title: Text(slot.name ?? slot.id ?? slot.path),
              subtitle: Text(
                slot.image ?? slot.mediaTypes.join(', '),
                style: UIs.text12Grey,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: slot.inserted
                  ? TextButton(
                      onPressed: () => _eject(ctx, notifier, slot),
                      child: Text(l10n.bmcEjectMedia),
                    )
                  : TextButton(
                      onPressed: () => _insert(ctx, notifier, slot),
                      child: Text(l10n.bmcInsertMedia),
                    ),
            ),
        ],
      ),
    );
  }

  static Future<void> _insert(
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
    if (await ctx.bmcRun(() => notifier.insertMedia(slot, image)) &&
        ctx.mounted) {
      ctx.popSheet();
    }
  }

  static Future<void> _eject(
    BuildContext ctx,
    BmcNotifier notifier,
    MediaSlot slot,
  ) async {
    if (await ctx.bmcRun(() => notifier.ejectMedia(slot)) && ctx.mounted) {
      ctx.popSheet();
    }
  }
}

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
            text: bmcBootEnabledText,
          ),
          if (boot.modes.length > 1)
            _group(
              'BIOS',
              boot.modes,
              req.mode ?? boot.mode,
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
