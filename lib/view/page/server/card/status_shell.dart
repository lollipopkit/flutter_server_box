import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/card/title.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/widget/server_side_tile.dart';

/// Shared border radius for compact Status-tab rows, grid tiles, and banners.
const kStatusCompactRadius = BorderRadius.all(Radius.circular(9));

/// Density-aware card wrapper shared by Status-tab items (`BmcCard`,
/// `UptimerCard`) to keep radius, margin, and selection highlight uniform.
final class StatusDensityCard extends StatelessWidget {
  final ServerListDensity density;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const StatusDensityCard({
    super.key,
    required this.density,
    this.highlighted = false,
    required this.onTap,
    this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? Theme.of(context).colorScheme.secondaryContainer
        : null;
    final (radius, margin) = switch (density) {
      ServerListDensity.rows => (
        kStatusCompactRadius,
        const EdgeInsets.symmetric(vertical: 1),
      ),
      ServerListDensity.grid => (kStatusCompactRadius, EdgeInsets.zero),
      ServerListDensity.cards ||
      ServerListDensity.auto => (null, const EdgeInsets.all(4)),
    };
    return FadingCard(
      outline: 1,
      color: color,
      radius: radius,
      margin: margin,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: child),
    );
  }
}

/// Renders a [kSideMarkSize] icon with a bottom-right status dot cutout.
final class StatusMarkBadge extends StatelessWidget {
  final IconData icon;
  final Color dotColor;
  final Color? cutoutBg;

  const StatusMarkBadge({
    super.key,
    required this.icon,
    required this.dotColor,
    this.cutoutBg,
  });

  @override
  Widget build(BuildContext context) {
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
              icon,
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
}

/// Fixed-width trailing action slot for Status-tab cards and rows.
///
/// In bulk-selection mode ([selected] != null), taps pass through to the card.
final class StatusCardActionSlot extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final bool? selected;

  const StatusCardActionSlot({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final slot = SizedBox(
      height: 23,
      width: ServerCardSizes.action,
      child: Center(child: child),
    );
    if (onPressed == null || selected != null) return slot;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onPressed,
        child: slot,
      ),
    );
  }
}

/// Standard padded card layout: mark + name + chevron + right label + action,
/// followed by an optional [body].
final class StatusCardShell extends StatelessWidget {
  final String name;
  final Widget mark;
  final Widget action;
  final bool? selected;
  final String? rightText;
  final TextStyle? rightStyle;
  final double rightMaxWidthFraction;
  final Widget? body;

  const StatusCardShell({
    super.key,
    required this.name,
    required this.mark,
    required this.action,
    this.selected,
    this.rightText,
    this.rightStyle,
    this.rightMaxWidthFraction = 0.48,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
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
                      mark,
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          name,
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
                if (rightText case final right?)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cons.maxWidth.isFinite
                          ? cons.maxWidth * rightMaxWidthFraction
                          : double.infinity,
                    ),
                    child: Text(
                      right,
                      style: rightStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(width: 7),
                action,
              ],
            ),
          ),
          if (body case final content?) ...[
            const SizedBox(height: ServerCardSizes.gap),
            content,
          ],
        ],
      ),
    );
  }
}

/// Compact horizontal row layout shared by Status-tab items in `rows` density.
final class StatusRowShell extends StatelessWidget {
  final String name;
  final Color dotColor;
  final bool? selected;
  final Widget Function(double maxWidth) middleBuilder;
  final List<Widget> Function(double maxWidth)? extraWideColumnsBuilder;
  final String rightWord;
  final Color rightColor;
  final Widget action;

  const StatusRowShell({
    super.key,
    required this.name,
    required this.dotColor,
    this.selected,
    required this.middleBuilder,
    this.extraWideColumnsBuilder,
    required this.rightWord,
    required this.rightColor,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isMobile ? ServerCardSizes.rowTouch : ServerCardSizes.row,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: LayoutBuilder(
          builder: (_, cons) {
            final wide = cons.maxWidth;
            return Row(
              children: [
                if (selected case final sel?) ServerCardCheck(selected: sel),
                Container(
                  width: ServerCardSizes.dot,
                  height: ServerCardSizes.dot,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 11),
                SizedBox(
                  width: 96,
                  child: Text(
                    name,
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
                Expanded(child: middleBuilder(wide)),
                if (extraWideColumnsBuilder case final extra?) ...extra(wide),
                if (wide >= 560) ...[
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
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Compact tile layout shared by Status-tab items in `grid` density.
final class StatusGridTileShell extends StatelessWidget {
  final Color dotColor;
  final Widget title;
  final String valueText;
  final Color valueColor;
  final double? valueMaxWidth;
  final bool? selected;
  final Widget bottom;

  const StatusGridTileShell({
    super.key,
    required this.dotColor,
    required this.title,
    required this.valueText,
    required this.valueColor,
    this.valueMaxWidth = 64,
    this.selected,
    required this.bottom,
  });

  static Widget defaultTitle(String name) => Text(
    name,
    style: const TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w500,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  @override
  Widget build(BuildContext context) {
    final valueWidget = Text(
      valueText,
      style: TextStyle(
        fontSize: 10,
        height: 1.2,
        color: valueColor,
        fontFeatures: kTabularFigures,
      ),
      maxLines: 1,
      overflow: valueMaxWidth != null ? TextOverflow.ellipsis : null,
    );

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
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(child: title),
                const SizedBox(width: 5),
                if (valueMaxWidth case final maxW?)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: valueWidget,
                  )
                else
                  valueWidget,
              ],
            ),
            const SizedBox(height: 5),
            bottom,
          ],
        ),
      ),
    );
  }
}

/// Tinted rounded surface container for inline alerts, notices, and errors.
final class StatusNoticeBanner extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Widget child;

  const StatusNoticeBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: kStatusCompactRadius,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: kStatusCompactRadius,
      onTap: onTap,
      child: content,
    );
  }
}
