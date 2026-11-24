import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/provider/bmc/summary.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/bmc/common.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/card/status_shell.dart';
import 'package:server_box/view/page/server/widget/server_side_tile.dart';

/// Card-mode body content (failure banner, power wattage, or hardware model +
/// health alert) rendered beneath [BmcCard]'s header.
final class BmcCardBody extends ConsumerWidget {
  final BmcTarget target;
  final BmcSummaryState summary;
  final bool? selected;

  const BmcCardBody({
    super.key,
    required this.target,
    required this.summary,
    this.selected,
  });

  static bool hasHealthAlert(BmcSummaryState s) {
    final health = s.topology?.system?.health;
    return health != null && health.isNotEmpty && health != 'OK';
  }

  static bool hasContent(BmcSummaryState s) {
    if (s.failure != null) return true;
    if (!s.hasData) return false;
    if (s.watts != null) return true;
    final model = s.topology?.system?.model?.trim();
    return (model != null && model.isNotEmpty) || hasHealthAlert(s);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = summary;

    if (s.failure case final failure?) {
      final isCert = s.needsCertReview;
      final tone = isCert ? StatePalette.warn : StatePalette.failed;
      final title = isCert ? l10n.bmcCert : bmcFailureText(failure, null);
      final detail = isCert
          ? bmcFailureText(failure, s.failureDetail)
          : s.failureDetail;
      return StatusNoticeBanner(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        onTap: isCert && selected == null
            ? () => unawaited(trustBmcTargetCert(context, ref, target))
            : null,
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
    }

    if (!s.hasData) return const SizedBox.shrink();

    final system = s.topology?.system;
    final model = system?.model?.trim();
    final hasModel = model != null && model.isNotEmpty;
    final health = system?.health;
    final healthAlert = hasHealthAlert(s);
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
            _buildModelHealthRow(
              model: showSubModel ? model : null,
              fontSize: 11,
              health: healthAlert ? health : null,
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
          _buildModelHealthRow(
            model: hasModel ? model : null,
            fontSize: 12,
            health: healthAlert ? health : null,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildModelHealthRow({
    required String? model,
    required double fontSize,
    required String? health,
  }) => Row(
    children: [
      if (model != null)
        Expanded(
          child: Text(
            model,
            style: TextStyle(fontSize: fontSize, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        )
      else
        const Spacer(),
      if (health != null) _healthBadge(health),
    ],
  );

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
}
