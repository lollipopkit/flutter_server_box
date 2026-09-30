import 'dart:ui' show FontFeature, lerpDouble;

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/res/chart_palette.dart';

/// The colour a [CardX] with nothing said about it actually paints.
///
/// `ThemeData.cardColor` is not it: that is the Material 2 field, and in a
/// dark scheme it is a step darker than the `surfaceContainerLow` a `Card`
/// resolves to — so a surface lerped towards it arrived a different colour
/// from the cards around it. The AMOLED theme names a translucent one in
/// `cardTheme`, which is the other reason to ask rather than to assume.
Color cardColorOf(BuildContext context) {
  final theme = Theme.of(context);
  return theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
}

/// Where in the movement the surfaces change hands.
///
/// A card has one surface behind everything; the page has one per block and
/// nothing behind them. Spread over the whole movement that swap is the one
/// thing in it a reader can see happening — the card's colour holds while the
/// card grows, so it ends up a sheet over the entire content area, and then it
/// has to go somewhere. Done with inside the first fifth, before anything has
/// travelled far, what is left to watch is only geometry.
///
/// The blocks arrive slightly ahead of the card leaving, because they are
/// drawn *on* it: two surfaces crossing at the same rate leave the middle of
/// the swap at three quarters of a surface, which is a wash nobody asked for.
/// Read off [openness], not off the clock, because what has to be true is
/// that the card has not visibly grown yet — and the movement's curve is
/// nearly flat at its start, so a short window here is a long enough moment to
/// cross in.
const _kBlockIn = 0.08;
const _kCardOutAt = 0.05;
const _kCardOut = 0.08;

/// How much of a block's own surface is there yet. See [_kBlockIn].
double blockSurfaceAt(double openness) =>
    (openness / _kBlockIn).clamp(0.0, 1.0);

/// How much of the card's own surface is left. See [_kBlockIn].
double cardSurfaceAt(double openness) =>
    1 - ((openness - _kCardOutAt) / _kCardOut).clamp(0.0, 1.0);

/// How much of a block's outline is there yet: none until the card's own has
/// gone, then all of it over the same span the card's took to go.
///
/// Not [blockSurfaceAt]. The colours cross with the blocks ahead, for the
/// reason given at [_kBlockIn]; outlines crossed at all draw every block
/// framed inside a card that is still framed, a frame within a frame, for as
/// long as the two overlap. So one follows the other.
double blockOutlineAt(double openness) =>
    ((openness - _kCardOutAt - _kCardOut) / _kCardOut).clamp(0.0, 1.0);

/// A [CardX] whose theme outline is drawn at [outline] of its strength, and
/// drawn as asked on every frame.
///
/// `CardX` draws the theme's outline whole whatever colour it is given, and
/// the surfaces above cross by colour alone: in a theme whose cards are
/// outlined, the card on its way to being the page kept a frame the size of
/// the whole content area around a surface that had already gone.
class FadingCard extends StatelessWidget {
  const FadingCard({
    super.key,
    required this.outline,
    required this.child,
    this.color,
    this.radius,
    this.margin,
  });

  /// 0 for none of the theme's outline, 1 for all of it.
  final double outline;
  final Color? color;

  /// As [CardX.radius]: null keeps the theme's shape.
  final BorderRadius? radius;
  final EdgeInsetsGeometry? margin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CardTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final shape = theme.shape;
    final side = shape is OutlinedBorder ? shape.side : BorderSide.none;
    final faded = side.copyWith(
      color: side.color.withValues(alpha: side.color.a * outline),
    );
    // `Card`'s own tree, with one difference: its `Material` eases a change of
    // shape over 200ms, which is longer than either crossing lasts. The
    // outline being asked for and the one drawn were a fifth of a second
    // apart — the card's still there as the blocks' arrived — so what is
    // drawn here is what was asked for, on every frame.
    return Semantics(
      container: true,
      child: Padding(
        padding: margin ?? theme.margin ?? const EdgeInsets.all(4),
        child: Material(
          type: MaterialType.card,
          animationDuration: Duration.zero,
          color: color ?? theme.color ?? scheme.surfaceContainerLow,
          shadowColor: theme.shadowColor ?? scheme.shadow,
          surfaceTintColor: theme.surfaceTintColor ?? Colors.transparent,
          elevation: theme.elevation ?? 0,
          clipBehavior: Clip.hardEdge,
          shape: switch ((radius, shape)) {
            (final radius?, _) => RoundedRectangleBorder(
              borderRadius: radius,
              side: faded,
            ),
            (null, final OutlinedBorder shape) => shape.copyWith(side: faded),
            (null, final shape?) => shape,
            (null, null) => const RoundedRectangleBorder(
              borderRadius: CardX.borderRadius,
            ),
          },
          child: child,
        ),
      ),
    );
  }
}

/// One reading that is not the one being drawn in full.
///
/// The same widget on a card in the list and on the page that card grows into,
/// because the card *becomes* the page: two widgets drawn from the same
/// numbers would have to be crossed over at the handover, and a crossing is
/// exactly what a reader sees as the page having been rebuilt.
///
/// [openness] is how far along that movement this row is — 0 a line inside a
/// card, 1 a card of its own on the page — and every measurement that differs
/// between the two is a lerp on it. At 0 the row is what a list of servers can
/// spare for a reading it is not being read for; at 1 it is a way in as well
/// as a number, and says so.
class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.value,
    required this.note,
    this.percent,
    this.error,
    this.over = false,
    this.selected = false,
    this.openness = 1,
    this.onTap,
    this.barMax = 340,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String value;

  /// What the value is of, or what the section said instead of a reading.
  final String note;

  /// 0-1 for a reading with a full, null for a rate: only the first kind gets
  /// a bar, because only it has something to be a share of.
  final double? percent;

  /// What this reading's section of the status said instead of a number.
  final String? error;

  /// Whether the reading is past the line the list counts alerts at.
  final bool over;

  /// Whether this is the reading drawn in full above, which is what says the
  /// chart and this row are the same thing.
  final bool selected;

  /// 0 is a line in a card, 1 a card on a page. See the class doc.
  final double openness;

  final VoidCallback? onTap;

  /// The widest the bar may be once the row is the page's.
  ///
  /// The other end is a bound that cannot bind, because a card is never wider
  /// than the page it is in — lerping to an infinity is not something
  /// [lerpDouble] will do.
  final double barMax;

  /// What the page insets a row by, and what a card does.
  static const openPad = EdgeInsets.fromLTRB(17, 11, 13, 11);
  static const pad = EdgeInsets.symmetric(horizontal: 9, vertical: 5);

  /// Both ends of the two styles that differ, as whole styles.
  ///
  /// [TextStyle.lerp] keeps whichever of the pair states a line height, so a
  /// height named on the near end is one the far end never gets rid of — and
  /// every row lands a few points off.
  static const _label = TextStyle(fontSize: 12);
  static const _openLabel = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const _value = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const _openValue = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The column the labels line up in, which is what lets the numbers on the
  /// right of six cards be compared down a page.
  static const _labelWidth = 58.0;
  static const _openLabelWidth = 84.0;

  static const _bar = 3.0;

  @override
  Widget build(BuildContext context) {
    final t = openness.clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : null;
    final failed = error != null;

    final row = Row(
      children: [
        Icon(
          icon,
          size: lerpDouble(17, 18, t),
          color: failed
              ? scheme.error
              : selected
              ? fg
              : Color.lerp(Colors.grey, color, t),
        ),
        SizedBox(width: lerpDouble(9, 13, t)),
        SizedBox(
          width: lerpDouble(_labelWidth, _openLabelWidth, t),
          child: Text(
            label,
            style: TextStyle.lerp(_label, _openLabel, t)?.copyWith(color: fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: lerpDouble(9, 13, t)),
        Expanded(child: _middle(context, t, scheme: scheme, fg: fg)),
        SizedBox(width: lerpDouble(9, 13, t)),
        Text(
          value,
          style: TextStyle.lerp(
            _value,
            _openValue,
            t,
          )?.copyWith(color: failed ? scheme.error : fg),
        ),
        // The page's rows are a way in as well as a reading, and say so. On a
        // card there is no room to say it and nothing it would lead to that
        // tapping the card does not.
        if (t > 0) ...[
          SizedBox(width: 9 * t),
          SizedBox(
            width: 17 * t,
            child: Opacity(
              opacity: t,
              child: Icon(
                failed
                    ? Icons.error_outline
                    : selected
                    ? Icons.show_chart
                    : Icons.chevron_right,
                size: 17,
                color: failed ? scheme.error : fg ?? UIs.textGrey.color,
              ),
            ),
          ),
        ],
      ],
    );

    final body = onTap == null
        ? Padding(padding: EdgeInsets.lerp(pad, openPad, t)!, child: row)
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: EdgeInsets.lerp(pad, openPad, t)!,
              child: row,
            ),
          );

    if (t <= 0) return body;
    // A card of its own at the far end, because what is above it there is the
    // same surface the chart sits on and a row with none of its own
    // disappeared into the page. It is in before the card's own starts going
    // — see [blockSurfaceAt].
    return FadingCard(
      outline: blockOutlineAt(t),
      color: Color.lerp(
        Colors.transparent,
        selected ? scheme.secondaryContainer : cardColorOf(context),
        blockSurfaceAt(t),
      ),
      margin: EdgeInsets.lerp(EdgeInsets.zero, const EdgeInsets.all(4), t),
      child: body,
    );
  }

  /// The bar and what the number is of, sharing the middle of the row.
  ///
  /// On a card only one of them fits, so a reading with a full gets the bar
  /// and a rate gets the words. On the page both are there.
  Widget _middle(
    BuildContext context,
    double t, {
    required ColorScheme scheme,
    required Color? fg,
  }) {
    final note = error ?? this.note;
    final percent = this.percent;
    if (percent == null) {
      return Text(
        note,
        style: TextStyle.lerp(
          const TextStyle(fontSize: 12, color: Colors.grey),
          UIs.text12Grey,
          t,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Grow the note's share with the transition. Reserving it while invisible
    // would make the progress bar jump at the start and end of the animation.
    const barFlex = 1000;
    final noteFlex = note.isEmpty ? 0 : (barFlex * t).round();

    return Row(
      children: [
        Flexible(
          flex: barFlex,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: lerpDouble(barMax <= 340 ? 340 : barMax, 340, t)!,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_bar),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                minHeight: _bar,
                backgroundColor: selected
                    ? (fg ?? scheme.onSurface).withValues(alpha: 0.15)
                    : scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  over ? StatePalette.warn : (selected ? fg ?? color : color),
                ),
              ),
            ),
          ),
        ),
        // Omit the flexible child at zero; flex 0 still lays out its content.
        if (noteFlex > 0)
          Flexible(
            flex: noteFlex,
            child: Opacity(
              opacity: t,
              child: Padding(
                padding: EdgeInsets.only(left: lerpDouble(0, 13, t)!),
                child: Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UIs.text12Grey,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
