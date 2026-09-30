import 'dart:ui' show lerpDouble;

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/widget/nav_rail.dart';

/// The bar's geometry.
///
/// Not `NavigationBar`'s: that one gives every destination an equal share of
/// the width and has to light one of them, so a "more" could be neither a
/// small button at the edge nor something that is not a place. The glyph and
/// the pill are M3's own measurements, so the two read the same.
abstract final class NavBarMetrics {
  /// Above the system's own inset. What `NavigationBar` was given here.
  static const height = kBottomNavigationBarHeight * 1.1;

  static const indicatorWidth = 64.0;
  static const indicatorHeight = 32.0;
  static const iconSize = 24.0;

  /// Between the pill and the name under it.
  static const labelGap = 4.0;

  /// What the trailing button takes at the right edge.
  static const trailingWidth = 48.0;

  /// Above the pill and below the name, once large text has made the bar
  /// taller than [height]. Small enough that at the default text size the
  /// bar is [height] exactly, as it was.
  static const labelInset = 4.0;
}

/// The app's bottom bar: [AppNavRail]'s counterpart on a phone.
///
/// A tab shows its name only while it is the one open, as the rail shows it
/// only while open. The trailing button is an action, never a place — it is
/// not lit, and [selectedIndex] never points at it.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.trailing,
    this.onTrailingTap,
  });

  final List<NavRailItem> items;

  /// Which item is lit. Out of range lights none: the tab that is open is
  /// behind [trailing].
  final int selectedIndex;

  final ValueChanged<int> onSelected;

  /// A glyph-only button against the right edge.
  final NavRailItem? trailing;
  final VoidCallback? onTrailingTap;

  /// As tall as the selected tab's pill and name need, and never shorter than
  /// [NavBarMetrics.height].
  ///
  /// The name is laid out at the text scale the system asks for, which the
  /// fixed height did not allow for: at twice the size it overflowed the bar.
  double _height(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: _labelStyle(context)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final label = painter.height;
    painter.dispose();
    final needed =
        NavBarMetrics.indicatorHeight +
        NavBarMetrics.labelGap +
        label +
        2 * NavBarMetrics.labelInset;
    return needed > NavBarMetrics.height ? needed : NavBarMetrics.height;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barTheme = NavigationBarTheme.of(context);
    return Material(
      // `NavigationBar`'s own defaults, so a theme that sets nothing sees no
      // change.
      color: barTheme.backgroundColor ?? scheme.surfaceContainer,
      elevation: barTheme.elevation ?? 3,
      shadowColor: barTheme.shadowColor ?? Colors.transparent,
      surfaceTintColor: barTheme.surfaceTintColor ?? Colors.transparent,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _height(context),
          child: Row(
            children: [
              for (final (at, item) in items.indexed)
                Expanded(
                  child: _NavBarTile(
                    item: item,
                    selected: at == selectedIndex,
                    onTap: () => onSelected(at),
                  ),
                ),
              if (trailing case final trailing?)
                SizedBox(
                  width: NavBarMetrics.trailingWidth,
                  child: _NavBarTrailing(
                    item: trailing,
                    onTap: onTrailingTap ?? () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a selected tab's name is drawn in, from the bar's theme and then M3's.
TextStyle? _labelStyle(BuildContext context) {
  final theme = Theme.of(context);
  return NavigationBarTheme.of(
        context,
      ).labelTextStyle?.resolve({WidgetState.selected}) ??
      theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface);
}

/// The colours an item is drawn in, from the bar's theme and then M3's.
Color? _iconColor(BuildContext context, bool selected) {
  final scheme = Theme.of(context).colorScheme;
  final states = {if (selected) WidgetState.selected};
  return NavigationBarTheme.of(context).iconTheme?.resolve(states)?.color ??
      (selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant);
}

class _NavBarTile extends StatelessWidget {
  const _NavBarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavRailItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // How far this item is the one being looked at, 0 to 1 — the pill, the
    // glyph's colour and the name arriving under it are one movement.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1.0 : 0.0),
      duration: context.motion(Durations.short4),
      curve: Curves.easeOut,
      builder: (context, on, _) => _build(context, on),
    );
  }

  Widget _build(BuildContext context, double on) {
    final theme = Theme.of(context);
    final barTheme = NavigationBarTheme.of(context);
    final shape = barTheme.indicatorShape ?? const StadiumBorder();
    final labelStyle = _labelStyle(context);
    // The count while there is one, and otherwise the mark while selected —
    // on the pill's corner, the one place the bar has for either. A row of
    // beta tabs is not a row of marks.
    final corner = item.badge?.call(1) ?? (on > 0.5 ? item.mark?.call(on) : null);

    final pill = SizedBox(
      width: NavBarMetrics.indicatorWidth,
      height: NavBarMetrics.indicatorHeight,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          color: Color.lerp(
            Colors.transparent,
            barTheme.indicatorColor ?? theme.colorScheme.secondaryContainer,
            on,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IconTheme.merge(
              data: IconThemeData(
                size: NavBarMetrics.iconSize,
                color: Color.lerp(
                  _iconColor(context, false),
                  _iconColor(context, true),
                  on,
                ),
              ),
              child: on > 0.5 ? item.selectedIcon : item.icon,
            ),
            if (corner != null) Positioned(top: -4, right: 2, child: corner),
          ],
        ),
      ),
    );

    final tile = InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            pill,
            // Grown in rather than switched on, so the pill rises to make
            // room as the name arrives instead of jumping.
            SizedBox(height: lerpDouble(0, NavBarMetrics.labelGap, on)),
            ClipRect(
              child: Align(
                heightFactor: on,
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle?.copyWith(
                    color: labelStyle.color?.withValues(
                      alpha: (labelStyle.color?.a ?? 1) * on,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return switch (item.onMenu) {
      null => tile,
      // Translucent, so the tap that switches tabs still reaches the ink
      // response under it; the long press wins the arena by holding past the
      // timeout. The same as a rail item.
      final onMenu => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => onMenu(null),
        child: tile,
      ).onSecondary(onMenu),
    };
  }
}

class _NavBarTrailing extends StatelessWidget {
  const _NavBarTrailing({required this.item, required this.onTap});

  final NavRailItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      waitDuration: Durations.long2,
      child: InkResponse(
        onTap: onTap,
        radius: NavBarMetrics.trailingWidth / 2,
        child: Semantics(
          button: true,
          label: item.label,
          excludeSemantics: true,
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(
                size: NavBarMetrics.iconSize,
                color: _iconColor(context, false),
              ),
              child: item.icon,
            ),
          ),
        ),
      ),
    );
  }
}
