import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/bmc/common.dart';
import 'package:server_box/view/page/server/bmc/drives.dart';
import 'package:server_box/view/page/server/bmc/edit.dart';
import 'package:server_box/view/page/server/bmc/logs.dart';
import 'package:server_box/view/page/server/bmc/panel.dart';
import 'package:server_box/view/page/server/card/shared_hero.dart';
import 'package:server_box/view/page/server/detail/focus_parts.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';

/// Full detail view for a standalone [BmcTarget].
///
/// Supports both pushed single-pane navigation (`bare: false`) and embedded
/// two-pane hosting in the Status tab (`bare: true`).
final class BmcDetailPage extends ConsumerStatefulWidget {
  final BmcTargetRequiredArgs args;
  final bool bare;
  final FlightAnchorBinding? markAnchor;
  final bool hideMark;

  const BmcDetailPage({
    super.key,
    required this.args,
    this.bare = false,
    this.markAnchor,
    this.hideMark = false,
  });

  /// Renders the 38×38 status orb shown at the top-left of [BmcDetailPage],
  /// shared with the in-place overlay flight proxy so opening and closing
  /// transitions match the live BMC state (cert review, failure, loading, or
  /// power state) identically.
  static Widget buildStatusOrb(
    BuildContext context, {
    required RedfishFailure? failure,
    required bool hasData,
    required bool isBusy,
    required PowerState powerState,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final needsCert =
        failure == RedfishFailure.certificateRejected ||
        failure == RedfishFailure.certNotReviewed;
    final (orbIcon, orbFg, orbBg) = switch ((failure, hasData, isBusy, powerState)) {
      (final RedfishFailure _, _, _, _) when needsCert => (
        Icons.verified_user_outlined,
        StatePalette.warn,
        StatePalette.warn.withValues(alpha: 0.16),
      ),
      (final RedfishFailure _, _, _, _) => (
        Icons.link_off,
        StatePalette.failed,
        StatePalette.failed.withValues(alpha: 0.16),
      ),
      (null, false, true, _) => (
        Icons.developer_board,
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
      (null, _, _, PowerState.on_) => (
        Icons.power_settings_new,
        StatePalette.running,
        StatePalette.running.withValues(alpha: 0.16),
      ),
      (null, _, _, PowerState.poweringOn || PowerState.poweringOff) => (
        Icons.power_settings_new,
        StatePalette.warn,
        StatePalette.warn.withValues(alpha: 0.16),
      ),
      _ => (
        Icons.power_settings_new,
        StatePalette.idle,
        scheme.surfaceContainerHighest,
      ),
    };

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: orbBg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: failure == null && isBusy && !hasData
          ? const Center(
              child: SizedBox.square(
                dimension: 18,
                child: SizedLoading(18, padding: 2),
              ),
            )
          : Icon(orbIcon, size: 20, color: orbFg),
    );
  }

  static const route = AppRouteArg<void, BmcTargetRequiredArgs>(
    page: BmcDetailPage.new,
    path: '/bmc/detail',
  );

  @override
  ConsumerState<BmcDetailPage> createState() => _BmcDetailPageState();
}

final class _BmcDetailPageState extends ConsumerState<BmcDetailPage> {
  static const _maxWidth = 560.0;

  var _everInStore = false;
  var _popScheduled = false;

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(
      bmcTargetsProvider.select((s) => s.targets[widget.args.target.id]),
    );
    if (stored != null) {
      _everInStore = true;
    } else if (_everInStore) {
      if (!widget.bare && !_popScheduled) {
        _popScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final route = ModalRoute.of(context);
          if (route == null || !route.isActive) return;
          if (route.isCurrent) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).removeRoute(route);
          }
        });
      }
      return widget.bare ? UIs.placeholder : const Scaffold();
    }

    final target = stored ?? widget.args.target;
    final bmc = ref.watch(bmcProvider(target.id));
    final body = _buildBody(context, target, bmc);

    if (widget.bare) return body;

    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: target.name, down: target.displayAddr),
        actions: [
          Btn.icon(
            text: libL10n.refresh,
            icon: const Icon(Icons.refresh),
            onTap: bmc.isBusy
                ? null
                : () => unawaited(
                    ref.read(bmcProvider(target.id).notifier).refresh(),
                  ),
          ),
          Btn.icon(
            text: libL10n.edit,
            icon: const Icon(Icons.edit_outlined),
            onTap: () => unawaited(
              BmcTargetEditPage.route.go(
                context,
                args: BmcTargetEditArgs(target: target),
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(
    BuildContext context,
    BmcTarget target,
    BmcState bmc,
  ) {
    final manageCard = _buildManageCard(context, target, bmc);
    final sensorsSection = _buildSensorsSection(context, bmc);

    return RefreshIndicator(
      onRefresh: () => ref.read(bmcProvider(target.id).notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          17,
          17,
          17,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(context, target, bmc),
                  ServerDetailSwap(
                    child: manageCard == null
                        ? const SizedBox.shrink(key: ValueKey('no_manage'))
                        : Padding(
                            key: const ValueKey('manage'),
                            padding: const EdgeInsets.only(top: 13),
                            child: manageCard,
                          ),
                  ),
                  ServerDetailSwap(
                    child: sensorsSection == null
                        ? const SizedBox.shrink(key: ValueKey('no_sensors'))
                        : Padding(
                            key: const ValueKey('sensors'),
                            padding: const EdgeInsets.only(top: 13),
                            child: sensorsSection,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    BmcTarget target,
    BmcState bmc,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final system = bmc.topology?.system;
    final needsCert =
        bmc.failure == RedfishFailure.certificateRejected ||
        bmc.failure == RedfishFailure.certNotReviewed;
    final primaryTitle = switch (bmc) {
      BmcState(failure: final failure?) => bmcFailureText(
        failure,
        bmc.failureDetail,
      ),
      BmcState(hasData: false, isBusy: true) => libL10n.loadingEllipsis,
      BmcState(powerState: PowerState.on_) => l10n.bmcPowerOn,
      _ => bmcPowerText(bmc.powerState),
    };

    final facts = <(String, String)>[
      if (system != null)
        for (final (k, v) in [
          (l10n.virtHwModel, system.model),
          ('BIOS', system.biosVersion),
          ('Serial', system.serial),
        ])
          if (v != null && v.isNotEmpty) (k, v),
    ];

    final powerBar = _buildPowerBar(context, target, bmc, needsCert: needsCert);
    final health = system?.health;
    final healthColor = health == null || health == 'OK'
        ? scheme.outline
        : (bmcHealthColor(health) ?? StatePalette.warn);
    final watts = bmc.sensors.watts;

    return CardX(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 13),
            child: Row(
              children: [
                Opacity(
                  opacity: widget.hideMark ? 0 : 1,
                  child: FlightAnchor(
                    binding: widget.markAnchor,
                    child: SharedElementHero(
                      tag: 'bmc_mark_${target.id}',
                      enabled: !widget.bare,
                      fit: BoxFit.contain,
                      child: BmcDetailPage.buildStatusOrb(
                        context,
                        failure: bmc.failure,
                        hasData: bmc.hasData,
                        isBusy: bmc.isBusy,
                        powerState: bmc.powerState,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              primaryTitle,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (Feature.bmc.mark() case final mark?) ...[
                            const SizedBox(width: 7),
                            mark,
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            target.addr,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: scheme.outline,
                            ),
                          ),
                          if (health != null && health.isNotEmpty) ...[
                            Text(
                              '·',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.outline,
                              ),
                            ),
                            Text(
                              'Health $health',
                              style: TextStyle(
                                fontSize: 12,
                                color: healthColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (watts != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${watts.toStringAsFixed(0)} W',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (facts.isNotEmpty) ...[
            Divider(
              height: Hairline.thickness,
              thickness: Hairline.thickness,
              color: Hairline.color(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 6, 17, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (k, v) in facts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            k,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              v,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontFeatures: kTabularFigures,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (bmc.topology?.hasMultipleSystems == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 0, 17, 10),
              child: Text(
                l10n.bmcMultipleSystems,
                style: TextStyle(fontSize: 11.5, color: scheme.outline),
              ),
            ),
          if (powerBar != null) ...[
            Divider(
              height: Hairline.thickness,
              thickness: Hairline.thickness,
              color: Hairline.color(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 11),
              child: powerBar,
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildPowerBar(
    BuildContext context,
    BmcTarget target,
    BmcState bmc, {
    required bool needsCert,
  }) {
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

    if (!bmc.hasData) return null;
    final notifier = ref.read(bmcProvider(target.id).notifier);
    final available = BmcPowerActions.availableIntents(notifier);
    if (available.isEmpty) return null;

    final busy = bmc.isPowering;
    final hasOn = available.contains(PowerIntent.on_);
    final hasShutdown = available.contains(PowerIntent.gracefulShutdown);
    final hasRestart = available.contains(PowerIntent.restart);
    const spinner = SizedBox.square(
      dimension: 15,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    final buttons = <Widget>[];
    if (bmc.powerState == PowerState.off && hasOn) {
      if (available.length > 1) {
        buttons.add(
          IconButton(
            tooltip: libL10n.more,
            onPressed: busy
                ? null
                : () =>
                    unawaited(BmcPowerActions.showAllSheet(context, ref, target)),
            icon: const Icon(Icons.more_horiz, size: 19),
          ),
        );
      }
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
        buttons.add(
          IconButton(
            tooltip: libL10n.more,
            onPressed: busy
                ? null
                : () =>
                    unawaited(BmcPowerActions.showAllSheet(context, ref, target)),
            icon: const Icon(Icons.more_horiz, size: 19),
          ),
        );
      }
    } else {
      buttons.add(
        FilledButton.tonalIcon(
          onPressed: busy
              ? null
              : () =>
                  unawaited(BmcPowerActions.showAllSheet(context, ref, target)),
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

  Widget? _buildManageCard(
    BuildContext context,
    BmcTarget target,
    BmcState bmc,
  ) {
    final system = bmc.topology?.system;
    if (!bmc.hasData || system == null) return null;

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

    final rows = <Widget>[];
    if (hasLogs) {
      rows.add(
        _manageNavRow(
          context,
          icon: Icons.receipt_long,
          title: libL10n.logs,
          onTap: () => unawaited(BmcLogsPage.route.go(context, args)),
        ),
      );
    }
    if (hasDrives) {
      rows.add(
        _manageNavRow(
          context,
          icon: Icons.storage,
          title: l10n.bmcDrives,
          onTap: () => unawaited(BmcDrivesPage.route.go(context, args)),
        ),
      );
    }
    if (hasBoot) {
      final bootSummary = boot.active
          ? '${boot.target ?? libL10n.unknown} · ${bmcBootEnabledText(boot.enabled!)}'
          : l10n.bmcBootDisabled;
      rows.add(
        _manageNavRow(
          context,
          icon: Icons.start,
          title: l10n.bmcBoot,
          trailingText: bootSummary,
          onTap: busy
              ? null
              : () => unawaited(
                  BmcManageActions.openBootSheet(context, ref, target, boot),
                ),
        ),
      );
    }
    if (hasMedia) {
      rows.add(
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
      );
    }
    if (locator != null) {
      void toggleLocator(bool on) =>
          unawaited(BmcManageActions.toggleLocator(context, ref, target.id, on));
      final disabledColor = scheme.onSurface.withValues(alpha: 0.38);
      rows.add(
        MergeSemantics(
          child: InkWell(
            onTap: busy ? null : () => toggleLocator(!locator.lit),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 4, 13, 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Icon(
                      locator.lit ? Icons.lightbulb : Icons.lightbulb_outline,
                      size: 20,
                      color: busy
                          ? disabledColor
                          : (locator.lit
                                ? scheme.primary
                                : scheme.onSurfaceVariant),
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
                    Switch(
                      value: locator.lit,
                      onChanged: busy ? null : toggleLocator,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (rows.isEmpty) return null;

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

  Widget? _buildSensorsSection(BuildContext context, BmcState bmc) {
    final readings = [
      ...bmc.sensors.temperatures,
      ...bmc.sensors.fans,
    ];
    if (readings.isEmpty) return null;
    final scheme = Theme.of(context).colorScheme;

    String formatReading(BmcReading r) => formatBmcReading(r);

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
                                            formatReading(
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
