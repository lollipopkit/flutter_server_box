import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// The rail's geometry.
///
/// An item is an indicator with its label directly under it and nothing else:
/// 55pt against `NavigationRail`'s 88, which is what used to let six tabs and
/// the settings button fill a laptop window's whole height. Nothing here is a
/// `NavigationRail` argument — its vertical spacing is private to the M3
/// implementation — so the rail is laid out here instead.
abstract final class NavRailMetrics {
  /// The width the rail takes from the tab beside it.
  static const width = 76.0;

  /// One item's own width, inside [width].
  static const itemWidth = 68.0;

  /// Above the first item and below the footer.
  static const padding = 13.0;

  /// One item's own, over and under the pair it holds.
  static const itemPadding = 5.0;

  /// The indicator the icon sits in.
  static const indicatorWidth = 52.0;
  static const indicatorHeight = 30.0;

  /// Between the indicator and the label.
  static const gap = 3.0;

  static const iconSize = 22.0;
  static const labelSize = 10.0;
  static const labelHeight = 1.2;

  /// The footer's own pill, which is an item's indicator without a label.
  static const footerHeight = indicatorHeight;
  static const footerIconSize = 20.0;

  /// How much one item takes vertically.
  ///
  /// Only the label moves with the text scale, which this app lets the user
  /// set — so a constant would be wrong on exactly the installs where the
  /// count of items that fit matters most.
  ///
  /// Rounded **up**: a text layout rounds a line to a whole pixel, and being a
  /// pixel under is a rail that overflows its box rather than one with a spare
  /// slot.
  static double itemExtent(BuildContext context) {
    final label = MediaQuery.textScalerOf(context).scale(labelSize);
    return itemPadding * 2 +
        indicatorHeight +
        gap +
        (label * labelHeight).ceilToDouble();
  }

  /// What the rail spends on things that are not items.
  static const chromeHeight = padding * 2 + footerHeight;
}

/// One item of [AppNavRail].
class NavRailItem {
  const NavRailItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge,
    this.onMenu,
  });

  final Widget icon;

  /// The filled form, for the item being looked at.
  final Widget selectedIcon;

  final String label;

  /// Hung on the indicator's top-right corner.
  ///
  /// Over the indicator and not over the icon: a badge drawn on the glyph
  /// covers the one thing the item has to stay readable as.
  final Widget? badge;

  /// A long press, and a right-click on a desktop.
  final ContextMenuOpener? onMenu;
}

/// The app's navigation rail.
///
/// Scrolls rather than overflows when it runs out of height — the caller
/// decides how many items to give it, from [NavRailMetrics.itemExtent], and
/// that is an estimate of a layout this performs rather than a measurement of
/// one it has already performed.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.footer,
  });

  final List<NavRailItem> items;

  /// Which item is lit. Out of range lights none, which is what a rail whose
  /// tab is behind "more" would otherwise assert on.
  final int selectedIndex;

  final ValueChanged<int> onSelected;

  /// Pinned to the foot, under whatever room the items leave.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: NavRailMetrics.width,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: NavRailMetrics.padding),
              child: Column(
                children: [
                  for (final (at, item) in items.indexed)
                    _NavRailTile(
                      item: item,
                      selected: at == selectedIndex,
                      onTap: () => onSelected(at),
                    ),
                ],
              ),
            ),
          ),
          if (footer case final footer?)
            Padding(
              padding: const EdgeInsets.only(bottom: NavRailMetrics.padding),
              child: footer,
            ),
        ],
      ),
    );
  }
}

class _NavRailTile extends StatelessWidget {
  const _NavRailTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavRailItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Animated, because what lights this is not always a tap on it: picking
    // the settings at the foot of the rail puts every item out, and a fill
    // that vanished between two frames read as the rail redrawing rather than
    // as the selection moving.
    Widget indicator = AnimatedContainer(
      duration: Durations.short3,
      curve: Curves.easeOut,
      width: NavRailMetrics.indicatorWidth,
      height: NavRailMetrics.indicatorHeight,
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: selected ? scheme.secondaryContainer : Colors.transparent,
      ),
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(
            size: NavRailMetrics.iconSize,
            color: selected ? scheme.onSecondaryContainer : scheme.outline,
          ),
          child: selected ? item.selectedIcon : item.icon,
        ),
      ),
    );

    if (item.badge case final badge?) {
      indicator = Stack(
        // The badge hangs off two of the indicator's edges by design, and a
        // clip here would take the corner off it.
        clipBehavior: Clip.none,
        children: [
          indicator,
          Positioned(top: -4, right: -3, child: badge),
        ],
      );
    }

    final tile = InkWell(
      onTap: onTap,
      borderRadius: CardX.borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: NavRailMetrics.itemPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            indicator,
            const SizedBox(height: NavRailMetrics.gap),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: NavRailMetrics.labelSize,
                height: NavRailMetrics.labelHeight,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? scheme.onSurface : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      width: NavRailMetrics.itemWidth,
      child: switch (item.onMenu) {
        null => tile,
        // Translucent, so the tap that switches tabs still reaches the ink
        // response this sits inside. A long press wins the arena over that tap
        // by holding past the timeout, which is what lets one target carry
        // both.
        final onMenu => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: () => onMenu(null),
          child: tile,
        ).onSecondary(onMenu),
      },
    );
  }
}

/// The one control at the foot of the rail.
///
/// A destination in every way but one: it has no label, because the rail has
/// room for exactly one of these and the glyph is the whole of it.
class NavRailFooterButton extends StatelessWidget {
  const NavRailFooterButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: Durations.short3,
          curve: Curves.easeOut,
          width: NavRailMetrics.indicatorWidth,
          height: NavRailMetrics.indicatorHeight,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: selected ? scheme.secondaryContainer : Colors.transparent,
          ),
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(
                size: NavRailMetrics.footerIconSize,
                color: selected ? scheme.onSecondaryContainer : scheme.outline,
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

/// The mark a rail item carries on its indicator's corner.
class NavRailBadge extends StatelessWidget {
  const NavRailBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 15,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: scheme.primaryContainer,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          // `widthFactor`, not a bare `Center`: with no width to fill — the
          // badge is positioned by one corner — an unfactored one would take
          // whatever the `Stack` hands down.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w500,
                color: scheme.onPrimaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
