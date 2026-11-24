import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/bmc/common.dart';
import 'package:server_box/view/page/bmc/drives.dart';
import 'package:server_box/view/page/bmc/logs.dart';
import 'package:server_box/view/page/bmc/panel.dart';

/// Management navigation card (logs, drives, boot override, virtual media,
/// locator LED) for [BmcDetailPage].
final class BmcManageCard extends ConsumerWidget {
  final BmcTarget target;
  final BmcState bmc;

  const BmcManageCard({super.key, required this.target, required this.bmc});

  static bool hasContent(BmcState bmc) {
    final system = bmc.topology?.system;
    if (!bmc.hasData || system == null) return false;
    final boot = system.boot;
    return system.logServices != null ||
        bmc.topology?.manager?.logServices != null ||
        system.storage != null ||
        system.simpleStorage != null ||
        (boot != null && boot.settableTargets.isNotEmpty) ||
        system.virtualMedia != null ||
        bmc.topology?.manager?.virtualMedia != null ||
        system.locator != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system = bmc.topology?.system;
    if (!bmc.hasData || system == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final args = BmcTargetRequiredArgs(target);
    final locator = system.locator;
    final boot = system.boot;
    final hasLogs =
        system.logServices != null ||
        bmc.topology?.manager?.logServices != null;
    final hasDrives = system.storage != null || system.simpleStorage != null;
    final hasBoot = boot != null && boot.settableTargets.isNotEmpty;
    final hasMedia =
        system.virtualMedia != null ||
        bmc.topology?.manager?.virtualMedia != null;
    final busy = bmc.isPowering;

    final rows = <Widget>[
      if (hasLogs)
        _manageNavRow(
          context,
          icon: Icons.receipt_long,
          title: libL10n.logs,
          onTap: () => unawaited(BmcLogsPage.route.go(context, args)),
        ),
      if (hasDrives)
        _manageNavRow(
          context,
          icon: Icons.storage,
          title: l10n.bmcDrives,
          onTap: () => unawaited(BmcDrivesPage.route.go(context, args)),
        ),
      if (hasBoot)
        _manageNavRow(
          context,
          icon: Icons.start,
          title: l10n.bmcBoot,
          trailingText: boot.active
              ? '${boot.target ?? libL10n.unknown} · ${bmcBootEnabledText(boot.enabled!)}'
              : l10n.bmcBootDisabled,
          onTap: busy
              ? null
              : () => unawaited(
                  BmcManageActions.openBootSheet(context, ref, target, boot),
                ),
        ),
      if (hasMedia)
        _manageNavRow(
          context,
          icon: Icons.album,
          title: l10n.bmcVirtualMedia,
          onTap: busy
              ? null
              : () => unawaited(
                  BmcManageActions.openMediaSheet(context, ref, target),
                ),
        ),
      if (locator != null) _buildLocatorRow(context, ref, scheme, lit: locator.lit, busy: busy),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return CardX(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: Hairline.thickness,
                thickness: Hairline.thickness,
                indent: 51,
                endIndent: 17,
                color: Hairline.color(context),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _buildLocatorRow(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme, {
    required bool lit,
    required bool busy,
  }) {
    void toggleLocator(bool on) =>
        unawaited(BmcManageActions.toggleLocator(context, ref, target.id, on));
    final disabledColor = scheme.onSurface.withValues(alpha: 0.38);
    return MergeSemantics(
      child: InkWell(
        onTap: busy ? null : () => toggleLocator(!lit),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 4, 13, 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Icon(
                  lit ? Icons.lightbulb : Icons.lightbulb_outline,
                  size: 20,
                  color: busy
                      ? disabledColor
                      : (lit ? scheme.primary : scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.bmcLocator,
                    style: TextStyle(
                      fontSize: 14,
                      color: busy ? disabledColor : null,
                    ),
                  ),
                ),
                Switch(value: lit, onChanged: busy ? null : toggleLocator),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _manageNavRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final disabledColor = scheme.onSurface.withValues(alpha: 0.38);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 7, 13, 7),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled ? scheme.onSurfaceVariant : disabledColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled ? null : disabledColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    trailingText,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? scheme.outline : disabledColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 17,
                color: enabled ? scheme.outline : disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Temperature and fan sensor grid card for [BmcDetailPage].
final class BmcSensorsSection extends StatelessWidget {
  final BmcState bmc;

  const BmcSensorsSection({super.key, required this.bmc});

  static bool hasContent(BmcState bmc) =>
      bmc.sensors.temperatures.isNotEmpty || bmc.sensors.fans.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final readings = [...bmc.sensors.temperatures, ...bmc.sensors.fans];
    if (readings.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 7),
          child: Text(
            libL10n.sensors,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.outline,
            ),
          ),
        ),
        CardX(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 11, 17, 13),
            child: LayoutBuilder(
              builder: (_, cons) {
                final cols = cons.maxWidth >= 420 ? 2 : 1;
                final rows = (readings.length / cols).ceil();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var r = 0; r < rows; r++)
                      Padding(
                        padding: EdgeInsets.only(top: r == 0 ? 0 : 8),
                        child: Row(
                          children: [
                            for (var c = 0; c < cols; c++) ...[
                              if (c > 0) const SizedBox(width: 18),
                              Expanded(
                                child: r * cols + c < readings.length
                                    ? Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              readings[r * cols + c].name,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            formatBmcReading(
                                              readings[r * cols + c],
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              fontFeatures: kTabularFigures,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (bmc.sensorsTruncated) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n.bmcSensorsTruncated,
                        style: TextStyle(fontSize: 11.5, color: scheme.outline),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Power action button bar shown at the bottom of [BmcDetailPage]'s status
/// card.
final class BmcPowerBar extends ConsumerWidget {
  final BmcTarget target;
  final BmcState bmc;
  final bool needsCert;

  const BmcPowerBar({
    super.key,
    required this.target,
    required this.bmc,
    required this.needsCert,
  });

  static bool hasContent(WidgetRef ref, BmcTarget target, BmcState bmc, {required bool needsCert}) {
    if (needsCert) return true;
    if (!bmc.hasData) return false;
    final notifier = ref.read(bmcProvider(target.id).notifier);
    return BmcPowerActions.availableIntents(notifier).isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (needsCert) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.tonalIcon(
            onPressed: () =>
                unawaited(trustBmcTargetCert(context, ref, target)),
            icon: const Icon(Icons.verified_user_outlined, size: 17),
            label: Text(l10n.bmcCert),
          ),
        ],
      );
    }

    if (!bmc.hasData) return const SizedBox.shrink();
    final notifier = ref.read(bmcProvider(target.id).notifier);
    final available = BmcPowerActions.availableIntents(notifier);
    if (available.isEmpty) return const SizedBox.shrink();

    final busy = bmc.isPowering;
    final hasOn = available.contains(PowerIntent.on_);
    final hasShutdown = available.contains(PowerIntent.gracefulShutdown);
    final hasRestart = available.contains(PowerIntent.restart);
    const spinner = SizedBox.square(
      dimension: 15,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    Widget moreButton() => IconButton(
      tooltip: libL10n.more,
      onPressed: busy
          ? null
          : () => unawaited(BmcPowerActions.showAllSheet(context, ref, target)),
      icon: const Icon(Icons.more_horiz, size: 19),
    );

    final buttons = <Widget>[];
    if (bmc.powerState == PowerState.off && hasOn) {
      if (available.length > 1) buttons.add(moreButton());
      buttons.add(
        FilledButton.tonalIcon(
          onPressed: busy
              ? null
              : () => unawaited(
                  BmcPowerActions.runPower(
                    context,
                    ref,
                    target,
                    PowerIntent.on_,
                  ),
                ),
          icon: busy ? spinner : const Icon(Icons.power_settings_new, size: 17),
          label: Text(l10n.bmcPowerOnAction),
        ),
      );
    } else if (bmc.powerState == PowerState.on_) {
      if (busy) {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: spinner,
          ),
        );
      }
      if (hasRestart) {
        buttons.add(
          TextButton.icon(
            onPressed: busy
                ? null
                : () => unawaited(
                    BmcPowerActions.runPower(
                      context,
                      ref,
                      target,
                      PowerIntent.restart,
                    ),
                  ),
            icon: const Icon(Icons.restart_alt, size: 17),
            label: Text(bmcIntentText(PowerIntent.restart)),
          ),
        );
      }
      if (hasShutdown) {
        buttons.add(
          TextButton.icon(
            onPressed: busy
                ? null
                : () => unawaited(
                    BmcPowerActions.runPower(
                      context,
                      ref,
                      target,
                      PowerIntent.gracefulShutdown,
                    ),
                  ),
            icon: const Icon(Icons.power_off_outlined, size: 17),
            label: Text(bmcIntentText(PowerIntent.gracefulShutdown)),
          ),
        );
      }
      if (available.any(BmcPowerActions.isDestructive) || buttons.isEmpty) {
        buttons.add(moreButton());
      }
    } else {
      buttons.add(
        FilledButton.tonalIcon(
          onPressed: busy
              ? null
              : () => unawaited(
                  BmcPowerActions.showAllSheet(context, ref, target),
                ),
          icon: busy ? spinner : const Icon(Icons.power_settings_new, size: 17),
          label: Text(l10n.power),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: buttons,
    );
  }
}
