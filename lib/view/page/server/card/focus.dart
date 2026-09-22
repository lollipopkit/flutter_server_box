import 'dart:ui' show lerpDouble;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/arrival.dart';
import 'package:server_box/view/page/server/card/fold.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/reading_text.dart';

/// When the chart's scale arrives, over the movement that takes the card to
/// the page.
///
/// The second half of it, not all of it. A card two lines of text tall has
/// nowhere to put five tick labels, so for the first half there is nothing to
/// draw and the chart is held exactly as it was — which is what makes it free.
/// It lands on 1 with the movement, so the page takes over a chart already
/// drawn the way the page draws it.
const _kChartAxis = Interval(0.5, 1);

/// One reading drawn in full: what it is, what it says now, and the window
/// this app kept of it.
///
/// At rest it is a block inside the card. At the far end it is a card of its
/// own with the page's own 17/13 inset, which is the shape the detail draws
/// — so the surface grows under the chart rather than appearing around it.
///
/// The number moves as it goes: on the card it sits at the right of the
/// label's line, and on the page it is a headline of its own underneath.
/// Both are drawn, crossing over, and the headline's line grows from nothing
/// — so what reads is one number travelling down and getting bigger.
class ServerCardFocus extends StatelessWidget {
  const ServerCardFocus({
    super.key,
    required this.metric,
    required this.others,
    required this.name,
    required this.openness,
    required this.stale,
    required this.twoColumns,
    required this.expanded,
    required this.fold,
    required this.onTap,
    required this.onPromote,
    this.selected,
  });

  /// The reading drawn in full.
  final ServerMetric metric;

  /// Every other reading the machine reports.
  final List<ServerMetric> others;

  /// The machine's name, which heads the menu the switch raises.
  final String name;

  /// How far the card is on its way to the page — see `ServerCard.openness`.
  final double openness;

  /// Whether the numbers have stopped, which greys the chart.
  final bool stale;

  /// Whether the page this grows into puts the facts beside the readings.
  final bool twoColumns;

  /// Whether the rows under this are to be showing — see
  /// `ServerCard.expanded`.
  final bool expanded;

  /// How far those rows are unfolded.
  final Animation<double> fold;

  /// Whether this machine is one of the ones being acted on, or null when
  /// nothing is — see `ServerCard.selected`.
  final bool? selected;

  /// What a press on the switch does while [selected] is not null.
  final VoidCallback onTap;

  /// A different reading was chosen to be drawn in full.
  final ValueChanged<ServerMetricKind> onPromote;

  @override
  Widget build(BuildContext context) {
    final m = metric;
    final t = openness;
    // With something under it to fold away. A machine that reports the one
    // reading has nothing under it either way, and is drawn as unfolded.
    final foldable = others.isNotEmpty;
    // Anything at all to plot. A reading the history does not keep has a
    // number and nothing to draw it against; the card held the chart's room
    // for it anyway, and a box with nothing in it reads as a chart that
    // failed to load. One sample is enough: [MetricChart] draws it as a
    // point, and holding out for the line would be a poll's wait on every
    // connection for a card that already has something to show.
    //
    // Only at rest. The page has a chart's room whatever is in it, so the box
    // grows from nothing on the way there rather than from a card's worth —
    // the same rule the rows that are not on the card grow in by.
    final drawn = m.samples.any((v) => v != null);
    final height = lerpDouble(
      drawn ? ServerCardSizes.chart : 0,
      twoColumns
          ? ServerCardSizes.openChart
          : ServerCardSizes.openChartNarrow,
      t,
    )!;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: t <= 0
              ? null
              : lerpDouble(ServerCardSizes.big, ServerCardSizes.openHead, t),
          child: Row(
          children: [
            Icon(m.icon, size: 18, color: ChartPalette.accent),
            const SizedBox(width: 9),
            Text(
              m.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            // The card's only. On the page every reading has a row, and
            // pressing one is how a different one is chosen there.
            if (others.isNotEmpty && t < 1)
              Opacity(
                opacity: 1 - t,
                child: ServerCardSwitch(
                  others: others,
                  title: name,
                  moving: t > 0,
                  selected: selected,
                  onTap: onTap,
                  onPromote: onPromote,
                ),
              ),
            const Spacer(),
            if (t < 1)
              Opacity(
                opacity: 1 - t,
                child: Text(
                  m.value,
                  style: const TextStyle(
                    fontSize: ServerCardSizes.big,
                    height: 1,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
          ],
          ),
        ),
        if (t > 0) _headline(m, t),
        if (drawn) SizedBox(height: lerpDouble(ServerCardSizes.gap, 0, t)),
        if (drawn || t > 0) _chart(m, stale: stale, height: height, t: t),
        // Under the chart on the card; on the page it is up in the head row,
        // where it arrives with the page.
        //
        // A reading that says nothing about itself still has the line while
        // it is folded, for the control that is on it — and gives it up as
        // that leaves, rather than on the frame it sets off.
        if ((m.note.isNotEmpty || foldable) && t < 1)
          SizeTransition(
            alignment: Alignment.topCenter,
            sizeFactor: m.note.isNotEmpty
                ? AlwaysStoppedAnimation(1 - t)
                : fold.drive(Tween(begin: 1 - t, end: 0)),
            child: Opacity(
              opacity: 1 - t,
              child: Padding(
                // Less than a gap by what the line has over its text, which
                // is centred in it — so the text is a gap under the chart.
                padding: const EdgeInsets.only(top: ServerCardSizes.gap - 4),
                child: _under(
                  m.note,
                  unseen: others.length,
                  fold: foldable ? fold : kAlwaysCompleteAnimation,
                ),
              ),
            ),
          ),
      ],
    );

    return _surface(context, t, child: body, padding: ServerCardSizes.focusPad);
  }

  /// The line under the chart: what the reading is of, and folded, the way
  /// to the rest of the readings at the end of it.
  ///
  /// Folded, this is the last line of the card, so the control is on it rather
  /// than on a line of its own under a rule — which was a third of the card's
  /// height spent on saying there is more. The note starts at the left then,
  /// because it is sharing the line and a caption centred in what is left of
  /// one is centred on nothing.
  ///
  /// Unfolded, the line is the note's alone and it is a caption again, under
  /// the middle of the chart. It travels there along [fold], as the control
  /// leaves for the line under the rows.
  ///
  /// The control itself is not in this row. It is one control in both places
  /// and is drawn over the card — see `ServerCard._body` — so what is here is
  /// the room it takes while it is on this line: its own face, not drawn,
  /// closing as it goes. A width would have to be guessed, and what it says is
  /// as long as the language makes it.
  Widget _under(
    String note, {
    required int unseen,
    required Animation<double> fold,
  }) {
    return SizedBox(
      height: ServerCardSizes.underLine,
      child: Row(
        children: [
          Expanded(
            child: AlignTransition(
              alignment: fold.drive(
                AlignmentTween(
                  begin: Alignment.centerLeft,
                  end: Alignment.center,
                ),
              ),
              child: Text(
                note,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizeTransition(
            axis: Axis.horizontal,
            // Closing towards the edge of the card it sits against.
            alignment: Alignment.centerRight,
            sizeFactor: ReverseAnimation(fold),
            // Nothing once it has gone: the room is closed by then. Asked of
            // where it is going as well as where it is, because on the way
            // back this is built before the clock has moved.
            child: !expanded || fold.value < 1
                ? Visibility.maintain(
                    visible: false,
                    child: ServerCardFoldFace(
                      unseen: unseen,
                      shown: kAlwaysCompleteAnimation,
                      fold: fold,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// The window of this reading.
  ///
  /// The page's own chart, at both ends of the movement — so there is nothing
  /// to swap when the page takes over, only a scale and a set of lines growing
  /// in beside a line that has not moved. A card the height of two lines of
  /// text cannot carry five tick labels, so at rest it has none; the gutter
  /// they sit in is a width, and the plot narrows into it rather than jumping
  /// when it appears.
  Widget _chart(
    ServerMetric m, {
    required bool stale,
    required double height,
    required double t,
  }) {
    final axis = _kChartAxis.transform(t);
    // Grey rather than the card dimmed as a whole: pressing the opacity down
    // would take the text with it, and the numbers are still worth reading.
    // What is out of date is the shape.
    final series = [
      HistorySeries(
        m.label,
        stale ? Colors.grey : ChartPalette.accent,
        m.samples,
      ),
    ];
    // The chart height must follow the parent transition so it does not freeze
    // at an intermediate value during the reverse animation.
    return SizedBox(
      height: height,
      // A layer of its own: the line eases to each new sample over 150ms, and
      // without this every one of those frames painted the card round it —
      // its name, its number, its note — for every card a poll had reached.
      child: RepaintBoundary(
      child: Held(
      // Nothing about the chart changes over the first half of the movement:
      // the axis is not in yet and the line is the same line. Held there, the
      // box goes on growing around a chart that is laid out and painted but
      // never built — see [Held], and see [_kChartAxis] for why letting go
      // halfway is continuous.
      hold: t > 0 && axis <= 0,
      child: MetricChart(
      MetricChartSpec(
        series: series,
        format: m.format,
        times: m.times,
        // The same window the page draws live, so the line is where it was at
        // both ends of the movement — and a machine that stopped answering
        // leaves the same trailing gap at both.
        window: watchedWindow(
          m.times,
          series,
          until: stale ? DateTime.now().millisecondsSinceEpoch : null,
        ),
        binaryScale: m.binary,
        height: height,
        fill: true,
        axis: axis,
      ),
      ),
      ),
      ),
    );
  }

  /// The number on its own line, growing in under the label as the card
  /// becomes the page.
  Widget _headline(ServerMetric m, double t) {
    return ServerCardReveal(
      shown: t,
      child: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              m.value,
              style: const TextStyle(fontSize: 27, fontFeatures: kTabularFigures),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                m.bigNote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A block that is part of the card at rest and a card of its own at the
  /// end.
  ///
  /// The surface is there from the start of the movement and the inset arrives
  /// with everything else, so what happens is a surface growing under contents
  /// that are already travelling — rather than one appearing around them at
  /// the point they stop.
  Widget _surface(
    BuildContext context,
    double t, {
    required Widget child,
    required EdgeInsets padding,
  }) {
    if (t <= 0) return child;
    return CardX(
      // In before the card's own surface starts going — see `ServerCard.build`
      // and [blockSurfaceAt].
      color: Color.lerp(Colors.transparent, cardColorOf(context), blockSurfaceAt(t)),
      margin: EdgeInsets.lerp(EdgeInsets.zero, const EdgeInsets.all(4), t),
      child: Padding(
        padding: EdgeInsets.lerp(EdgeInsets.zero, padding, t)!,
        child: child,
      ),
    );
  }
}

/// Beside the name of the reading drawn in full: which one that is.
///
/// Pressing a row is the other way, and on a card at rest there are no rows
/// — see `ServerCard.expanded`. Here it does not depend on what is unfolded,
/// and it reaches the readings the card has no slot for as well.
///
/// No taller than the line it is on. That line takes the height of what is
/// in it at rest and a stated one from the first frame of the movement, so
/// anything taller than the number beside it is a chart that jumps by the
/// difference on that frame.
class ServerCardSwitch extends StatelessWidget {
  const ServerCardSwitch({
    super.key,
    required this.others,
    required this.title,
    required this.onTap,
    required this.onPromote,
    this.moving = false,
    this.selected,
  });

  /// What it offers: every reading but the one already drawn in full.
  final List<ServerMetric> others;

  /// Over the menu it raises.
  final String title;

  /// Whether the card is on its way to the page, which this is leaving.
  final bool moving;

  /// Whether this machine is one of the ones being acted on, or null when
  /// nothing is — see `ServerCard.selected`.
  final bool? selected;

  /// What a press does while [selected] is not null.
  final VoidCallback onTap;

  /// A reading was chosen from the menu.
  final ValueChanged<ServerMetricKind> onPromote;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // On its way out, so not something to press.
      ignoring: moving,
      child: Builder(
        // The button's own box, which is what the menu hangs off.
        builder: (context) => Semantics(
          button: true,
          label: libL10n.switch_,
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            // While a set is being built up a press means "this one too",
            // wherever on the card it lands — see `ServerCard._row`.
            onTap: selected == null
                ? () => _pickReading(context, others)
                : onTap,
            child: const SizedBox(
              width: ServerCardSizes.action,
              height: ServerCardSizes.big,
              child: Icon(Icons.unfold_more, size: 15, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  /// Raises the readings this machine has, to choose the one drawn in full.
  ///
  /// Every one but the one already there: choosing that would do nothing, and
  /// it is named an inch above the menu. What each reads now is beside its
  /// name, because that is usually the reason for picking it.
  void _pickReading(BuildContext context, List<ServerMetric> others) {
    final box = context.findRenderObject();
    // Under the button in every window, a phone's included: what it hangs off
    // is a control the size of a finger, not a card the height of the screen,
    // so there is always somewhere to put it. A sheet only when there is
    // nothing to measure.
    final at = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset(0, box.size.height))
        : null;
    showContextMenu(
      context,
      [
        for (final m in others)
          ContextMenuAction(
            icon: m.icon,
            text: m.label,
            note: m.value,
            onTap: () => onPromote(m.kind),
          ),
      ],
      title: title,
      at: at,
      sheet: at == null,
    );
  }
}
