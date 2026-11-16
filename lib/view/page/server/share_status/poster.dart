import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/share_status/data.dart';

/// The poster: what is shared as an image, drawn as it is saved.
///
/// [width] is fixed rather than the screen's, so the image is the same shape
/// from a phone and from a desktop window.
class StatusPosterCard extends StatelessWidget {
  const StatusPosterCard({
    super.key,
    required this.poster,
    required this.shown,
    required this.range,
    required this.hideName,
    required this.hideSystem,
    required this.dot,
  });

  static const width = 390.0;

  final StatusPoster poster;
  final Set<PosterSection> shown;
  final String range;
  final bool hideName;
  final bool hideSystem;

  /// The server's state, as the list draws it.
  final Color dot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocks = [
      for (final s in PosterSection.values)
        if (shown.contains(s))
          if (poster.sections[s] case final b?) (s, b),
    ];
    return Container(
      width: width,
      padding: const EdgeInsets.all(7),
      // Square: the image is the poster, and rounded corners would be
      // transparent pixels around it.
      color: scheme.surfaceContainer,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSurface, fontSize: 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _head(scheme),
            ..._grid(blocks),
            _foot(scheme),
          ],
        ),
      ),
    );
  }

  Widget _head(ColorScheme scheme) {
    final sub = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Row(
            spacing: 9,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  hideName ? libL10n.server : poster.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, height: 1.25),
                ),
              ),
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  range,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (!hideSystem && poster.system != null) Text(poster.system!, style: sub),
          if (poster.line case final line?) Text(line, style: sub),
        ],
      ),
    );
  }

  /// In order, two adjacent half-width sections side by side; any other a
  /// row of its own.
  List<Widget> _grid(List<(PosterSection, PosterBlock)> blocks) {
    final rows = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final entry = blocks[i];
      final next = i + 1 < blocks.length ? blocks[i + 1] : null;
      if (entry.$1.half && next != null && next.$1.half) {
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 7,
              children: [
                Expanded(child: _Section(entry)),
                Expanded(child: _Section(next)),
              ],
            ),
          ),
        );
        i++;
      } else {
        rows.add(_Section(entry));
      }
    }
    return [
      for (final (i, row) in rows.indexed) ...[if (i > 0) UIs.height7, row],
    ];
  }

  Widget _foot(ColorScheme scheme) {
    final style = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 5),
      child: Row(
        children: [
          Text(
            'ServerBox',
            style: style.copyWith(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(poster.at.ymdhms(), style: style),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.entry);

  final (PosterSection, PosterBlock) entry;

  @override
  Widget build(BuildContext context) {
    final (section, b) = entry;
    final scheme = Theme.of(context).colorScheme;
    final sub = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    const big = TextStyle(
      fontSize: 27,
      height: 1.25,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 7,
        children: [
          Row(
            spacing: 7,
            children: [
              Icon(section.icon, size: 15, color: scheme.onSurfaceVariant),
              Expanded(
                child: Text(
                  [section.label, ?b.title].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sub,
                ),
              ),
              if (b.aside case final aside?) Text(aside, style: sub),
            ],
          ),
          if (b.pair case final pair?)
            Row(
              children: [
                for (final r in [pair.a, pair.b])
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.value, style: big.copyWith(fontSize: 21)),
                        Text(r.name, style: sub),
                      ],
                    ),
                  ),
              ],
            )
          else if (b.value.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.value, style: big),
                      // Under the bar where there is one.
                      if (b.percent == null && b.note != null)
                        Text(b.note!, style: sub),
                    ],
                  ),
                ),
                if (b.bars.isNotEmpty) _Cores(b.bars),
              ],
            ),
          if (b.percent case final p?) ...[
            _Bar(p),
            if (b.note case final note?) Text(note, style: sub),
          ],
          for (final r in b.rows)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 5,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(r.value, style: sub),
                  ],
                ),
                if (r.percent case final p?) _Bar(p),
              ],
            ),
          // A picture: a tooltip under the pointer would be saved with it.
          if (b.chart case final spec?) IgnorePointer(child: MetricChart(spec)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.value);

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 5,
        color: scheme.primary,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}

/// A column a core, filled to its load now.
class _Cores extends StatelessWidget {
  const _Cores(this.loads);

  final List<double> loads;

  /// More than this and the columns get too thin to read; the average says
  /// the rest.
  static const _max = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 5,
      children: [
        for (final load in loads.take(_max))
          Container(
            width: 9,
            height: 40,
            alignment: Alignment.bottomCenter,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              heightFactor: load.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
