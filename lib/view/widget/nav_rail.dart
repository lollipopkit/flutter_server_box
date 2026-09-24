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

  /// The indicator the icon sits in.
  ///
  /// Its width is the **only** thing about an item that the opening changes.
  /// The height, the padding, the glyph and the gap under it were all a point
  /// or three different between the two shapes, and every one of them moved
  /// the icon a fraction of a pixel on every frame — a glyph re-rasterised at
  /// 23.78pt and then 23.55pt does not slide, it crawls. So the icon is the
  /// thing that stands still and the pill grows out from under it.
  static const indicatorWidth = 40.0;
  static const expandedIndicatorWidth = 164.0;
  static const indicatorHeight = 34.0;

  /// Between two indicators.
  static const itemGap = 5.0;

  /// Inside an indicator, before the icon. This is what centres the glyph in
  /// the shut pill, and where it stays in the open one.
  static const indicatorPadding = (indicatorWidth - iconSize) / 2;

  /// Between the icon and the name, once there is a name.
  static const labelGap = 11.0;

  static const iconSize = 24.0;
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
    final railTheme = NavigationRailTheme.of(context);

    // What the rail is painted with.
    //
    // Shut it stands in room the `Row` beside it holds open, so the colour
    // behind it is the page's — and with a background image that is
    // [Colors.transparent] on purpose, which is the wallpaper being seen
    // around the icons. Open it is a panel standing *over* the tab, and there
    // that same colour let the tab's own rows read through it: two sets of
    // names, one on top of the other.
    //
    // So it takes a colour of its own as it opens, crossed over with the same
    // value the width is read off — the two are one movement, and a colour
    // that switched at the end of it would be a panel changing its mind about
    // what it is after it has finished arriving.
    final surface = theme.colorScheme.surface;
    final chrome = railTheme.backgroundColor ?? theme.scaffoldBackgroundColor;

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
                color: chrome.a == 1
                    ? chrome
                    : Color.lerp(surface.withValues(alpha: 0), surface, open)!,
                surfaceTintColor: Colors.transparent,
                // On or off rather than eased in: a shadow is recomputed
                // wherever its elevation lands, and 200ms of that buys a
                // gradient nobody watches under a panel that is still moving.
                elevation: railTheme.elevation ?? (open == 0 ? 0 : 3),
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
    // How far this item is the one being looked at, 0 to 1.
    //
    // Everything that says so is read off it — the fill, the glyph's colour,
    // the name's colour and its weight — so the whole item crosses over
    // together rather than the pill fading under a label that snapped. It is
    // its own animation because it is its own event: the rail opening does not
    // change which item is selected, and selecting one does not open the rail.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1.0 : 0.0),
      duration: Durations.short4,
      curve: Curves.easeOut,
      builder: (context, on, _) => _build(context, on),
    );
  }

  Widget _build(BuildContext context, double on) {
    final scheme = Theme.of(context).colorScheme;
    final railTheme = NavigationRailTheme.of(context);
    final fg = Color.lerp(
      railTheme.unselectedIconTheme?.color ?? scheme.outline,
      railTheme.selectedIconTheme?.color ?? scheme.onSecondaryContainer,
      on,
    );

    // Halfway, which is where the name has room to be read and the badge has
    // room to sit after it. Below it the badge is on the indicator's corner;
    // above it, after the name.
    final named = open > 0.5;
    final inline = ((open - 0.5) * 2).clamp(0.0, 1.0);
    final corner = 1 - (open * 2).clamp(0.0, 1.0);

    // Every measurement written out rather than left to an
    // `AnimatedContainer`: it would ease the width and the padding *towards*
    // what this frame asked for, a frame or two behind the row inside — and a
    // row laid out for a pill wider than the one it is in is an overflow.
    final indicator = SizedBox(
      width: _lerp(
        NavRailMetrics.indicatorWidth,
        NavRailMetrics.expandedIndicatorWidth,
      ),
      height: NavRailMetrics.indicatorHeight,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: railTheme.indicatorShape ?? const StadiumBorder(),
          color: Color.lerp(
            Colors.transparent,
            railTheme.indicatorColor ?? scheme.secondaryContainer,
            on,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NavRailMetrics.indicatorPadding,
          ),
          child: Row(
            children: [
              // The badge is anchored to the glyph, not to the pill.
              //
              // On the pill's own corner it kept station with an edge that
              // travels 120 points as the rail opens — so it flew off to the
              // right, across the name arriving under it, while fading out.
              // On the glyph it stays where it was and only fades.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(
                      size: NavRailMetrics.iconSize,
                      color: fg,
                    ),
                    // Round the glyph and nothing else.
                    //
                    // A `Tooltip` builds two different trees — with an
                    // `OverlayPortal` and without — depending on whether it is
                    // allowed to show anything, so turning it off halfway through
                    // the opening re-parents everything under it. Under it here is
                    // one `Icon`, which has nothing to lose by that.
                    child: TooltipVisibility(
                      // Only while the name is not on the row already.
                      visible: !named,
                      child: Tooltip(
                        message: item.label,
                        waitDuration: Durations.long2,
                        child: on > 0.5 ? item.selectedIcon : item.icon,
                      ),
                    ),
                  ),
                  // Always here, faded out over the first half of the opening
                  // rather than taken away at the halfway mark: dropped there
                  // it went from fully drawn to gone between two frames, on
                  // the one item that has a badge.
                  if (item.badge case final badge?)
                    Positioned(top: -4, right: -6, child: badge(corner)),
                ],
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
                      fontWeight: FontWeight.lerp(
                        FontWeight.w400,
                        FontWeight.w500,
                        on,
                      ),
                      // The colour, not an `Opacity` around it — see
                      // [NavRailBadge.opacity].
                      color: Color.lerp(
                        railTheme.unselectedLabelTextStyle?.color ??
                            Colors.grey,
                        railTheme.selectedLabelTextStyle?.color ??
                            scheme.onSecondaryContainer,
                        on,
                      )?.withValues(alpha: open),
                    ),
                  ),
                ),
                // Narrowed as it fades rather than only faded: a badge at
                // opacity zero is still as wide as a badge, and this one
                // arrives in a pill that has not finished widening.
                if (item.badge case final badge?)
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: inline,
                      child: badge(inline),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    final tile = Padding(
      // Outside the ink rather than inside it, so that what lights under the
      // pointer is the pill and not the pill plus the gap under it.
      padding: const EdgeInsets.only(bottom: NavRailMetrics.itemGap),
      child: InkWell(
        onTap: onTap,
        // The pill's own shape. A rectangle under a stadium reads as a second
        // control behind the first.
        customBorder: railTheme.indicatorShape ?? const StadiumBorder(),
        // The hover and nothing else: the rail opens under the pointer and the
        // pill moves to what was tapped, so a ripple on top of those two is a
        // third thing answering one movement of the mouse.
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: indicator,
      ),
    );

    return switch (item.onMenu) {
      null => tile,
      // Translucent, so the tap that switches tabs still reaches the ink
      // response this sits inside. A long press wins the arena over that tap
      // by holding past the timeout, which is what lets one target carry both.
      final onMenu => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => onMenu(null),
        child: tile,
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
