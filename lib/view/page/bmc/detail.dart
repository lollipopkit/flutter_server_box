import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/bmc/common.dart';
import 'package:server_box/view/page/bmc/detail_sections.dart';
import 'package:server_box/view/page/bmc/edit.dart';
import 'package:server_box/view/page/server/card/shared_hero.dart';
import 'package:server_box/view/page/server/detail/focus_parts.dart';
import 'package:server_box/view/page/server/detail/status_detail_shell.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';

/// Full detail view for a standalone [BmcTarget].
///
/// Supports both pushed single-pane navigation (`bare: false`) and embedded
/// two-pane hosting in the Status tab (`bare: true`).
final class BmcDetailPage extends ConsumerWidget {
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

  static const _maxWidth = 560.0;

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
    final (orbIcon, orbFg, orbBg) = switch ((
      failure,
      hasData,
      isBusy,
      powerState,
    )) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(
      bmcTargetsProvider.select((s) => s.targets[args.target.id]),
    );
    final target = stored ?? args.target;

    return StatusDetailShell(
      entityKey: args.target.id,
      bare: bare,
      existsInStore: stored != null,
      builder: (ctx, activeRef) {
        final bmc = activeRef.watch(bmcProvider(target.id));
        return (
          title: target.name,
          subtitle: target.displayAddr,
          onRefresh: bmc.isBusy
              ? null
              : () => unawaited(
                  activeRef.read(bmcProvider(target.id).notifier).refresh(),
                ),
          onEdit: () => unawaited(
            BmcTargetEditPage.route.go(
              ctx,
              args: BmcTargetEditArgs(target: target),
            ),
          ),
          body: _buildBody(ctx, activeRef, target, bmc),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    BmcTarget target,
    BmcState bmc,
  ) {
    final showManage = BmcManageCard.hasContent(bmc);
    final showSensors = BmcSensorsSection.hasContent(bmc);

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
                  _buildStatusCard(context, ref, target, bmc),
                  ServerDetailSwap(
                    child: !showManage
                        ? const SizedBox.shrink(key: ValueKey('no_manage'))
                        : Padding(
                            key: const ValueKey('manage'),
                            padding: const EdgeInsets.only(top: 13),
                            child: BmcManageCard(target: target, bmc: bmc),
                          ),
                  ),
                  ServerDetailSwap(
                    child: !showSensors
                        ? const SizedBox.shrink(key: ValueKey('no_sensors'))
                        : Padding(
                            key: const ValueKey('sensors'),
                            padding: const EdgeInsets.only(top: 13),
                            child: BmcSensorsSection(bmc: bmc),
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
    WidgetRef ref,
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

    final plannedPowerIntents = BmcPowerBar.planIntents(
      ref,
      target,
      bmc,
      needsCert: needsCert,
    );
    final hasPowerBar =
        needsCert ||
        (plannedPowerIntents != null && plannedPowerIntents.isNotEmpty);
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
                IgnorePointer(
                  ignoring: hideMark,
                  child: Opacity(
                    opacity: hideMark ? 0 : 1,
                    child: FlightAnchor(
                      binding: markAnchor,
                      child: SharedElementHero(
                        tag: 'bmc_mark_${target.id}',
                        enabled: !bare,
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
          if (hasPowerBar) ...[
            Divider(
              height: Hairline.thickness,
              thickness: Hairline.thickness,
              color: Hairline.color(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 11),
              child: BmcPowerBar(
                target: target,
                bmc: bmc,
                needsCert: needsCert,
                availableIntents: plannedPowerIntents,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
