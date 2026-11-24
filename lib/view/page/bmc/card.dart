import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/summary.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/bmc/card_body.dart';
import 'package:server_box/view/page/bmc/common.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/shared_hero.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/card/status_shell.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';

/// Status-tab card for a standalone [BmcTarget], matching [ServerCard]'s three
/// density modes (`cards`, `rows`, `grid`) and design tokens.
final class BmcCard extends ConsumerWidget {
  final BmcTarget target;
  final ServerListDensity density;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool? selected;
  final bool highlighted;
  final FlightAnchorBinding? markAnchor;
  final bool hideMark;
  final bool opensInPlace;

  const BmcCard({
    super.key,
    required this.target,
    required this.density,
    required this.onTap,
    this.onLongPress,
    this.selected,
    this.highlighted = false,
    this.markAnchor,
    this.hideMark = false,
    this.opensInPlace = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(bmcSummaryProvider(target.id));
    final body = switch (density) {
      ServerListDensity.rows => _buildRow(context, ref, summary),
      ServerListDensity.grid => _buildGridTile(context, summary),
      ServerListDensity.cards ||
      ServerListDensity.auto => _buildCard(context, ref, summary),
    };
    return StatusDensityCard(
      density: density,
      highlighted: highlighted,
      onTap: onTap,
      onLongPress: onLongPress,
      child: body,
    );
  }

  static Color statusDotColor(BmcSummaryState s) => _dotColor(
    needsCertReview: s.needsCertReview,
    hasFailure: s.failure != null,
    isBusy: s.isBusy,
    hasData: s.hasData,
    health: s.topology?.system?.health,
    powerState: s.powerState,
  );

  static Color statusDotColorFromBmc(BmcState s) => _dotColor(
    needsCertReview:
        s.failure == RedfishFailure.certificateRejected ||
        s.failure == RedfishFailure.certNotReviewed,
    hasFailure: s.failure != null,
    isBusy: s.isBusy,
    hasData: s.hasData,
    health: s.topology?.system?.health,
    powerState: s.powerState,
  );

  static Color _dotColor({
    required bool needsCertReview,
    required bool hasFailure,
    required bool isBusy,
    required bool hasData,
    required String? health,
    required PowerState powerState,
  }) {
    if (needsCertReview) return StatePalette.warn;
    if (hasFailure) return StatePalette.failed;
    if (isBusy && !hasData) return StatePalette.warn;
    if (health == 'Critical') return StatePalette.failed;
    if (health == 'Warning') return StatePalette.warn;
    return switch (powerState) {
      PowerState.on_ => StatePalette.running,
      PowerState.off => StatePalette.idle,
      PowerState.poweringOn || PowerState.poweringOff => StatePalette.warn,
      _ => StatePalette.idle,
    };
  }

  bool _canQuickPowerOn(BmcSummaryState s) {
    if (s.failure != null || !s.hasData || s.powerState != PowerState.off) {
      return false;
    }
    final system = s.topology?.system;
    return system != null &&
        bmcPlan(system: system, intent: PowerIntent.on_) != null;
  }

  String? _headerRightText(BmcSummaryState s) {
    if (s.failure != null) return null;
    if (!s.hasData && s.isBusy) return libL10n.loadingEllipsis;
    if (!s.hasData) return null;
    if (s.powerState == PowerState.on_ && s.watts != null) {
      final model = s.topology?.system?.model;
      if (model != null && model.isNotEmpty) return model;
    }
    return bmcPowerText(s.powerState);
  }

  Widget _buildAction(BuildContext context, WidgetRef ref, BmcSummaryState s) {
    final (Widget child, VoidCallback? onPressed, String? label) = switch (s) {
      BmcSummaryState(isBusy: true) || BmcSummaryState(isPowering: true) => (
        const SizedBox.square(dimension: 19, child: SizedLoading(19, padding: 2)),
        null,
        null,
      ),
      _ when s.needsCertReview => (
        const Icon(
          Icons.verified_user_outlined,
          size: 19,
          color: StatePalette.warn,
        ),
        () => unawaited(trustBmcTargetCert(context, ref, target)),
        l10n.bmcCert,
      ),
      _ when _canQuickPowerOn(s) => (
        const Icon(
          Icons.power_settings_new,
          size: 19,
          color: StatePalette.running,
        ),
        () => unawaited(_onQuickPowerOn(context, ref)),
        l10n.bmcPowerOnAction,
      ),
      _ => (
        const Icon(Icons.refresh, size: 19, color: Colors.grey),
        () => unawaited(
          ref.read(bmcSummaryProvider(target.id).notifier).refresh(force: true),
        ),
        libL10n.refresh,
      ),
    };
    return StatusCardActionSlot(
      onPressed: onPressed,
      semanticLabel: label,
      selected: selected,
      child: child,
    );
  }

  /// Renders the board mark icon with its status dot cutout, reused by both
  /// [BmcCard] and the in-place overlay flight proxy.
  static Widget buildMarkBadge(
    BuildContext context, {
    required Color dotColor,
    Color? cutoutBg,
  }) => StatusMarkBadge(
    icon: Icons.developer_board,
    dotColor: dotColor,
    cutoutBg: cutoutBg,
  );

  Widget _buildMark(BuildContext context, BmcSummaryState s) {
    final scheme = Theme.of(context).colorScheme;
    final mark = buildMarkBadge(
      context,
      dotColor: statusDotColor(s),
      cutoutBg: highlighted ? scheme.secondaryContainer : cardColorOf(context),
    );
    return IgnorePointer(
      ignoring: hideMark,
      child: Opacity(
        opacity: hideMark ? 0 : 1,
        child: FlightAnchor(
          binding: markAnchor,
          child: SharedElementHero(
            tag: 'bmc_mark_${target.id}',
            enabled: !opensInPlace,
            fit: BoxFit.contain,
            child: mark,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, BmcSummaryState s) {
    final scheme = Theme.of(context).colorScheme;
    return StatusCardShell(
      name: target.name,
      mark: _buildMark(context, s),
      selected: selected,
      rightText: _headerRightText(s),
      rightStyle: TextStyle(
        fontSize: 12,
        height: 1.2,
        color: s.hasData && s.powerState == PowerState.off
            ? Colors.grey
            : scheme.onSurfaceVariant,
        fontFeatures: kTabularFigures,
      ),
      action: _buildAction(context, ref, s),
      body: BmcCardBody.hasContent(s)
          ? BmcCardBody(target: target, summary: s, selected: selected)
          : null,
    );
  }

  Widget _buildRow(BuildContext context, WidgetRef ref, BmcSummaryState s) {
    final scheme = Theme.of(context).colorScheme;
    final (rightWord, rightColor) = switch (s) {
      _ when s.needsCertReview => (l10n.bmcCert, StatePalette.warn),
      BmcSummaryState(failure: != null) => (libL10n.retry, StatePalette.failed),
      BmcSummaryState(hasData: false, isBusy: true) => (
        libL10n.loadingEllipsis,
        Colors.grey,
      ),
      _ => (bmcPowerText(s.powerState), Colors.grey),
    };

    return StatusRowShell(
      name: target.name,
      dotColor: statusDotColor(s),
      selected: selected,
      rightWord: rightWord,
      rightColor: rightColor,
      middleBuilder: (_) => _buildRowMiddle(scheme, s),
      action: !s.hasData && s.isBusy
          ? const SizedBox(width: ServerCardSizes.action)
          : _buildAction(context, ref, s),
    );
  }

  Widget _buildRowMiddle(ColorScheme scheme, BmcSummaryState s) {
    if (!s.hasData && s.isBusy) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: LinearProgressIndicator(
          minHeight: ServerCardSizes.bar,
          borderRadius: BorderRadius.all(Radius.circular(ServerCardSizes.bar)),
        ),
      );
    }
    if (s.failure case final failure?) {
      return Text(
        bmcFailureText(failure, s.failureDetail),
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          color: s.needsCertReview ? StatePalette.warn : StatePalette.failed,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final model = s.topology?.system?.model?.trim();
    final health = s.topology?.system?.health;
    final spans = <InlineSpan>[];
    void sep() {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: '   '));
    }

    if (s.watts case final watts?) {
      spans.addAll([
        TextSpan(
          text: 'PWR ',
          style: TextStyle(fontSize: 10, height: 1, color: scheme.primary),
        ),
        TextSpan(
          text: '${watts.toStringAsFixed(0)} W',
          style: const TextStyle(
            fontSize: 11,
            height: 1,
            fontFeatures: kTabularFigures,
          ),
        ),
      ]);
    }
    if (BmcCardBody.hasHealthAlert(s)) {
      sep();
      spans.add(
        TextSpan(
          text: health!,
          style: TextStyle(
            fontSize: 11,
            height: 1,
            color: bmcHealthColor(health) ?? StatePalette.warn,
          ),
        ),
      );
    }
    if (model != null && model.isNotEmpty) {
      sep();
      spans.add(
        TextSpan(
          text: model,
          style: const TextStyle(
            fontSize: 11,
            height: 1.2,
            color: Colors.grey,
          ),
        ),
      );
    } else if (spans.isEmpty) {
      spans.add(
        const TextSpan(
          text: 'BMC',
          style: TextStyle(fontSize: 11, height: 1.2, color: Colors.grey),
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildGridTile(BuildContext context, BmcSummaryState s) {
    final scheme = Theme.of(context).colorScheme;
    final (shortVal, valColor) = switch (s) {
      _ when s.needsCertReview => (l10n.bmcCert, StatePalette.warn),
      BmcSummaryState(failure: != null) => (libL10n.fail, StatePalette.failed),
      BmcSummaryState(watts: final watts?) => (
        '${watts.toStringAsFixed(0)}W',
        Colors.grey,
      ),
      BmcSummaryState(hasData: true) => (
        bmcPowerText(s.powerState),
        Colors.grey,
      ),
      _ => ('—', Colors.grey),
    };

    final isOn = s.failure == null && s.hasData && s.powerState == PowerState.on_;
    final fillFactor = !isOn
        ? 0.0
        : (s.watts != null ? (s.watts! / 300.0).clamp(0.14, 1.0) : 1.0);
    final fillColor = BmcCardBody.hasHealthAlert(s)
        ? (bmcHealthColor(s.topology?.system?.health) ?? StatePalette.warn)
        : StatePalette.running;

    return StatusGridTileShell(
      selected: selected,
      dotColor: statusDotColor(s),
      title: StatusGridTileShell.defaultTitle(target.name),
      valueText: shortVal,
      valueColor: valColor,
      bottom: ClipRRect(
        borderRadius: const BorderRadius.all(
          Radius.circular(ServerCardSizes.bar),
        ),
        child: Container(
          height: ServerCardSizes.bar,
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.centerLeft,
          child: fillFactor > 0
              ? FractionallySizedBox(
                  widthFactor: fillFactor,
                  child: Container(
                    color: fillColor.withValues(
                      alpha: s.watts != null ? 0.9 : 0.45,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _onQuickPowerOn(BuildContext context, WidgetRef ref) =>
      confirmAndRunBmcPowerOn(
        context: context,
        ref: ref,
        target: target,
        run: () => ref
            .read(bmcSummaryProvider(target.id).notifier)
            .power(PowerIntent.on_),
      );
}
