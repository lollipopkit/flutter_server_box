import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/summary.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/bmc/common.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/shared_hero.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/card/title.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';
import 'package:server_box/view/page/server/widget/server_side_tile.dart';

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

  static const _compactRadius = BorderRadius.all(Radius.circular(9));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(bmcSummaryProvider(target.id));
    final color = highlighted
        ? Theme.of(context).colorScheme.secondaryContainer
        : null;
    final (radius, margin, body) = switch (density) {
      ServerListDensity.rows => (
        _compactRadius,
        const EdgeInsets.symmetric(vertical: 1),
        _buildRow(context, ref, summary),
      ),
      ServerListDensity.grid => (
        _compactRadius,
        EdgeInsets.zero,
        _buildGridTile(context, summary),
      ),
      ServerListDensity.cards || ServerListDensity.auto => (
        null,
        const EdgeInsets.all(4),
        _buildCard(context, ref, summary),
      ),
    };

    return FadingCard(
      outline: 1,
      color: color,
      radius: radius,
      margin: margin,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: body),
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

  bool _hasHealthAlert(BmcSummaryState s) {
    final health = s.topology?.system?.health;
    return health != null && health.isNotEmpty && health != 'OK';
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

    final slot = SizedBox(
      height: 23,
      width: ServerCardSizes.action,
      child: Center(child: child),
    );
    // In bulk-selection mode, let taps bubble to the card's selection toggle.
    if (onPressed == null || selected != null) return slot;
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onPressed,
        child: slot,
      ),
    );
  }

  /// Renders the board mark icon with its status dot cutout, reused by both
  /// [BmcCard] and the in-place overlay flight proxy.
  static Widget buildMarkBadge(
    BuildContext context, {
    required Color dotColor,
    Color? cutoutBg,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg = cutoutBg ?? cardColorOf(context);
    return SizedBox(
      width: kSideMarkSize,
      height: kSideMarkSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Icon(
              Icons.developer_board,
              size: kSideMarkSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: DecoratedBox(
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: Container(
                  width: SideMarkDot.size,
                  height: SideMarkDot.size,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
    final rightLine = _headerRightText(s);
    final body = _buildCardBody(context, ref, s);

    return Padding(
      padding: const EdgeInsets.all(ServerCardSizes.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (_, cons) => Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected case final sel?)
                        ServerCardCheck(selected: sel),
                      _buildMark(context, s),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          target.name,
                          style: const TextStyle(
                            fontSize: ServerCardSizes.name,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 17,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
                if (rightLine != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cons.maxWidth.isFinite
                          ? cons.maxWidth * 0.48
                          : double.infinity,
                    ),
                    child: Text(
                      rightLine,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: s.hasData && s.powerState == PowerState.off
                            ? Colors.grey
                            : scheme.onSurfaceVariant,
                        fontFeatures: kTabularFigures,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(width: 7),
                _buildAction(context, ref, s),
              ],
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: ServerCardSizes.gap),
            body,
          ],
        ],
      ),
    );
  }

  Widget? _buildCardBody(
    BuildContext context,
    WidgetRef ref,
    BmcSummaryState s,
  ) {
    final scheme = Theme.of(context).colorScheme;

    if (s.failure case final failure?) {
      final isCert = s.needsCertReview;
      final tone = isCert ? StatePalette.warn : StatePalette.failed;
      final title = isCert ? l10n.bmcCert : bmcFailureText(failure, null);
      final detail = isCert
          ? bmcFailureText(failure, s.failureDetail)
          : s.failureDetail;
      final content = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: _compactRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isCert ? Icons.verified_user_outlined : Icons.link_off,
                  size: 15,
                  color: tone,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: tone,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (detail != null && detail.isNotEmpty && detail != title) ...[
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.grey,
                  fontFamily: 'monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
      if (!isCert || selected != null) return content;
      return InkWell(
        borderRadius: _compactRadius,
        onTap: () => unawaited(trustBmcTargetCert(context, ref, target)),
        child: content,
      );
    }

    if (!s.hasData) return null;

    final system = s.topology?.system;
    final model = system?.model?.trim();
    final hasModel = model != null && model.isNotEmpty;
    final health = system?.health;
    final healthAlert = _hasHealthAlert(s);
    final isOff = s.powerState == PowerState.off;

    if (s.watts case final watts?) {
      final showSubModel = isOff && hasModel;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: kSideMarkSize,
                child: Center(
                  child: Icon(
                    Icons.bolt,
                    size: 17,
                    color: isOff ? StatePalette.idle : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                l10n.power,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${watts.toStringAsFixed(0)} W',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  fontFeatures: kTabularFigures,
                  color: isOff ? Colors.grey : null,
                ),
              ),
            ],
          ),
          if (showSubModel || healthAlert) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                if (showSubModel)
                  Expanded(
                    child: Text(
                      model,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                if (healthAlert) _healthBadge(health!),
              ],
            ),
          ],
        ],
      );
    }

    if (hasModel || healthAlert) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: Hairline.thickness,
            thickness: Hairline.thickness,
            color: Hairline.color(context),
          ),
          const SizedBox(height: ServerCardSizes.gap),
          Row(
            children: [
              if (hasModel)
                Expanded(
                  child: Text(
                    model,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              if (healthAlert) _healthBadge(health!),
            ],
          ),
        ],
      );
    }

    return null;
  }

  Widget _healthBadge(String health) {
    final color = bmcHealthColor(health) ?? StatePalette.warn;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          health,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
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

    Widget middle() {
      if (!s.hasData && s.isBusy) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: LinearProgressIndicator(
            minHeight: ServerCardSizes.bar,
            borderRadius: BorderRadius.all(
              Radius.circular(ServerCardSizes.bar),
            ),
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
      final healthAlert = _hasHealthAlert(s);
      final spans = <InlineSpan>[];
      void sep() {
        if (spans.isNotEmpty) spans.add(const TextSpan(text: '   '));
      }

      if (s.watts case final watts?) {
        spans.add(
          TextSpan(
            text: 'PWR ',
            style: TextStyle(fontSize: 10, height: 1, color: scheme.primary),
          ),
        );
        spans.add(
          TextSpan(
            text: '${watts.toStringAsFixed(0)} W',
            style: const TextStyle(
              fontSize: 11,
              height: 1,
              fontFeatures: kTabularFigures,
            ),
          ),
        );
      }
      if (healthAlert) {
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

    return SizedBox(
      height: isMobile ? ServerCardSizes.rowTouch : ServerCardSizes.row,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: LayoutBuilder(
          builder: (_, cons) => Row(
            children: [
              if (selected case final sel?) ServerCardCheck(selected: sel),
              Container(
                width: ServerCardSizes.dot,
                height: ServerCardSizes.dot,
                decoration: BoxDecoration(
                  color: statusDotColor(s),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 11),
              SizedBox(
                width: 96,
                child: Text(
                  target.name,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(child: middle()),
              if (cons.maxWidth >= 560) ...[
                const SizedBox(width: 13),
                SizedBox(
                  width: 88,
                  child: Text(
                    rightWord,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1,
                      color: rightColor,
                      fontFeatures: kTabularFigures,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(width: 3),
              if (!s.hasData && s.isBusy)
                const SizedBox(width: ServerCardSizes.action)
              else
                _buildAction(context, ref, s),
            ],
          ),
        ),
      ),
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
    final fillColor = _hasHealthAlert(s)
        ? (bmcHealthColor(s.topology?.system?.health) ?? StatePalette.warn)
        : StatePalette.running;

    return SizedBox(
      height: isMobile ? ServerCardSizes.tileTouch : ServerCardSizes.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (selected case final sel?) ServerCardCheck(selected: sel),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusDotColor(s),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    target.name,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 64),
                  child: Text(
                    shortVal,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: valColor,
                      fontFeatures: kTabularFigures,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
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
          ],
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
