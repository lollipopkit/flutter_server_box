import 'dart:ui' show lerpDouble;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// The rail's geometry, in both of the shapes it has.
///
/// It stands collapsed — an icon in a pill and nothing else — and opens under
/// the pointer, over the tab beside it rather than pushing it. So the width it
/// *takes* is the collapsed one, always; [expandedWidth] is only ever painted.
///
/// Nothing here is a `NavigationRail` argument: its vertical spacing is
/// private to the M3 implementation, and an item there is 88pt against the 39
/// below — which is what let six tabs and the settings button fill a laptop
/// window's whole height.
abstract final class NavRailMetrics {
  /// What the rail takes from the tab beside it.
  static const width = 56.0;

  /// What it is while the pointer is on it. Painted over the tab, so it costs
  /// the tab nothing.
  static const expandedWidth = 180.0;

  /// Above the first item and below the footer.
  static const padding = 13.0;

  /// The indicator the icon sits in, closed and open.
  static const indicatorWidth = 40.0;
  static const expandedIndicatorWidth = 164.0;
  static const indicatorHeight = 34.0;
  static const expandedIndicatorHeight = 36.0;

  /// Between two indicators.
  static const itemGap = 5.0;
  static const expandedItemGap = 2.0;

  /// Inside an indicator, before the icon. Closed, this is what centres a
  /// 22pt glyph in a 40pt pill.
  static const indicatorPadding = (indicatorWidth - iconSize) / 2;
  static const expandedIndicatorPadding = 11.0;

  /// Between the icon and the name, once there is a name.
  static const labelGap = 11.0;

  static const iconSize = 22.0;
  static const expandedIconSize = 20.0;
  static const labelSize = 13.0;

  /// How much one item takes vertically.
  ///
  /// A constant now, and that is the point of the collapsed rail: there is no
  /// label under the icon, so nothing here moves with the text scale. The open
  /// shape is 38 — a point less — so a rail counted by this one never
  /// overflows when it opens.
  static const itemExtent = indicatorHeight + itemGap;

  /// What the rail spends on things that are not items.
  static const chromeHeight = padding * 2 + indicatorHeight;
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

  /// Read out beside the icon when the rail is open, and as the item's tooltip
  /// when it is not.
  final String label;

  /// The count an item carries, faded by what it is given.
  ///
  /// On the indicator's top-right corner while the rail is shut — over the
  /// indicator and not over the icon, which is the one thing the item has to
  /// stay readable as — and after the name once there is one. Given the fade
  /// rather than wrapped in one, because an `Opacity` is a `saveLayer` and
  /// this is redrawn on every frame of the rail opening.
  final Widget Function(double opacity)? badge;

  /// A long press, and a right-click on a desktop.
  final ContextMenuOpener? onMenu;
}

/// The app's navigation rail.
///
/// Shut until the pointer is on it. Where there is no pointer it stays shut
/// and every item answers to its tooltip instead.
///
/// Scrolls rather than overflows when it runs out of height — the caller
/// decides how many items to give it, from [NavRailMetrics.itemExtent].
class AppNavRail extends StatefulWidget {
  const AppNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.footer,
    this.footerSelected = false,
    this.onFooterTap,
  });

  final List<NavRailItem> items;

  /// Which item is lit. Out of range lights none, which is what a rail whose
  /// tab is behind "more" — or whose settings are what is showing — would
  /// otherwise assert on.
  final int selectedIndex;

  final ValueChanged<int> onSelected;

  /// Pinned to the foot, under whatever room the items leave.
  ///
  /// The same shape as an item, because that is what it is: it shows the
  /// settings where a tab is shown. It is not one of [items] only because it
  /// is never arranged and never stored.
  final NavRailItem? footer;

  final bool footerSelected;
  final VoidCallback? onFooterTap;

  @override
  State<AppNavRail> createState() => _AppNavRailState();
}

class _AppNavRailState extends State<AppNavRail>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: Durations.short4,
  );
  late final _open = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _open.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => _ctrl.forward(),
      onExit: (_) => _ctrl.reverse(),
      // Its own layer: the rail redraws on every frame of opening, and what it
      // is painted over is a whole tab.
      child: RepaintBoundary(
        child: AnimatedBuilder(
        animation: _open,
        builder: (context, _) {
          final open = _open.value;
          return SizedBox(
            width: lerpDouble(
              NavRailMetrics.width,
              NavRailMetrics.expandedWidth,
              open,
            ),
            child: Material(
              // Opaque whatever it is doing: open, it is painted over the tab
              // beside it, and the shadow is what says so. Shut, the colour is
              // the one already behind it and the shadow is nothing.
              color: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              // On or off rather than eased in: a shadow is recomputed
              // wherever its elevation lands, and 200ms of that buys a
              // gradient nobody watches under a panel that is still moving.
              elevation: open == 0 ? 0 : 3,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        top: NavRailMetrics.padding,
                      ),
                      child: Column(
                        children: [
                          for (final (at, item) in widget.items.indexed)
                            _NavRailTile(
                              item: item,
                              selected: at == widget.selectedIndex,
                              open: open,
                              onTap: () => widget.onSelected(at),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.footer case final footer?)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: NavRailMetrics.padding,
                      ),
                      child: _NavRailTile(
                        item: footer,
                        selected: widget.footerSelected,
                        open: open,
                        onTap: widget.onFooterTap ?? () {},
                      ),
                    ),
                ],
              ),
            ),
          );
          },
        ),
      ),
    );
  }
}

class _NavRailTile extends StatelessWidget {
  const _NavRailTile({
    required this.item,
    required this.selected,
    required this.open,
    required this.onTap,
  });

  final NavRailItem item;
  final bool selected;

  /// How far the rail is open, 0 to 1. Every measurement the two shapes
  /// disagree about is read off this.
  final double open;

  final VoidCallback onTap;

  double _lerp(double shut, double opened) => lerpDouble(shut, opened, open)!;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.outline;

    // Halfway, which is where the name has room to be read and the badge has
    // room to sit after it. Below it the row is an icon and the badge is on
    // the corner; above it they have swapped.
    final named = open > 0.5;
    final fade = ((open - 0.5) * 2).clamp(0.0, 1.0);

    // Geometry here and the fill below, rather than one `AnimatedContainer`
    // doing both. It would animate the width and the padding *towards* what
    // this frame asked for, a frame or two behind the row inside — and a row
    // laid out for a pill wider than the one it is in is an overflow.
    Widget indicator = SizedBox(
      width: _lerp(
        NavRailMetrics.indicatorWidth,
        NavRailMetrics.expandedIndicatorWidth,
      ),
      height: _lerp(
        NavRailMetrics.indicatorHeight,
        NavRailMetrics.expandedIndicatorHeight,
      ),
      child: AnimatedContainer(
        // The fill, and only the fill: it is the one thing here that changes
        // without the rail opening or shutting.
        duration: Durations.short3,
        curve: Curves.easeOut,
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: selected ? scheme.secondaryContainer : Colors.transparent,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _lerp(
              NavRailMetrics.indicatorPadding,
              NavRailMetrics.expandedIndicatorPadding,
            ),
          ),
          child: Row(
            children: [
              IconTheme.merge(
                data: IconThemeData(
                  size: _lerp(
                    NavRailMetrics.iconSize,
                    NavRailMetrics.expandedIconSize,
                  ),
                  color: fg,
                ),
                child: selected ? item.selectedIcon : item.icon,
              ),
              // Absent rather than transparent while the rail is shut: a name
              // with no room left is a `Text` laid out in a box of no width.
              if (open > 0) ...[
                SizedBox(width: NavRailMetrics.labelGap * open),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: NavRailMetrics.labelSize,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      // The colour, not an `Opacity` around it — see
                      // [NavRailBadge.opacity].
                      color:
                          (selected
                                  ? scheme.onSecondaryContainer
                                  : Colors.grey)
                              .withValues(alpha: open),
                    ),
                  ),
                ),
              ],
              // Past the halfway point only. A faded badge is still as wide as
              // a badge, so one held here from the start would be 26 points of
              // row in a pill that is not yet that wide.
              if (named)
                if (item.badge case final badge?) badge(fade),
            ],
          ),
        ),
      ),
    );

    if (item.badge case final badge? when !named) {
      indicator = Stack(
        // The badge hangs off two of the indicator's edges by design, and a
        // clip here would take the corner off it.
        clipBehavior: Clip.none,
        children: [
          indicator,
          Positioned(top: -4, right: -6, child: badge(1 - fade)),
        ],
      );
    }

    final tile = InkWell(
      onTap: onTap,
      // None of it. The rail opens under the pointer and the pill moves to
      // what was tapped; a highlight under each item on top of those two is a
      // third thing answering one movement of the mouse.
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      focusColor: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: _lerp(NavRailMetrics.itemGap, NavRailMetrics.expandedItemGap),
        ),
        child: indicator,
      ),
    );

    // Only while it is the only thing naming the item. Open, the name is on
    // the row and a bubble repeating it would be over the row it names.
    final withName = named
        ? tile
        : Tooltip(
            message: item.label,
            waitDuration: Durations.long2,
            child: tile,
          );

    return switch (item.onMenu) {
      null => withName,
      // Translucent, so the tap that switches tabs still reaches the ink
      // response this sits inside. A long press wins the arena over that tap
      // by holding past the timeout, which is what lets one target carry both.
      final onMenu => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => onMenu(null),
        child: withName,
      ).onSecondary(onMenu),
    };
  }
}

/// The mark a rail item carries: on the indicator's corner while the rail is
/// shut, and after the name once it is open.
class NavRailBadge extends StatelessWidget {
  const NavRailBadge({super.key, required this.label, this.opacity = 1});

  final String label;

  /// Faded by its own colours rather than by an [Opacity] around it.
  ///
  /// An `Opacity` between 0 and 1 is a `saveLayer`, and the rail draws two of
  /// these per item on every frame of opening — which is what made opening it
  /// stutter.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 15,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: scheme.primaryContainer.withValues(alpha: opacity),
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
                color: scheme.onPrimaryContainer.withValues(alpha: opacity),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
