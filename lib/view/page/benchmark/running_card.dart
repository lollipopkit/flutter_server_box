import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/benchmark/estimate.dart';
import 'package:server_box/view/page/benchmark/log_view.dart';
import 'package:server_box/view/page/benchmark/phase.dart';

/// A run in flight.
class BenchmarkRunningCard extends StatelessWidget {
  const BenchmarkRunningCard({
    super.key,
    required this.run,
    required this.onCancel,
    this.busy = false,
  });

  final BenchmarkRun run;
  final VoidCallback onCancel;

  /// A cancel is in flight. Not "a run is in flight" — that is the whole card.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final phase = BenchmarkPhase.of(run.log);
    final scheme = Theme.of(context).colorScheme;
    return CardX(
      child: Padding(
        // A titled block: 17 either side, 13 above and below.
        padding: UIs.roundRectCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Fixed-size, so the title beside it does not move when the
                // ring is swapped in or out.
                const SizedLoading(
                  17,
                  padding: 0,
                  builder: SizedLoading.circularBuilder,
                ),
                UIs.width13,
                Expanded(child: Text(phase.label, style: UIs.text15Bold)),
                // Tabular, so the clock does not shift as it counts.
                Text(fmtDuration(run.elapsed), style: _tabularGrey),
              ],
            ),
            UIs.height13,
            // The estimate is what makes a fifteen-minute wait legible. It is
            // not a progress bar because there is nothing to base one on: yabs
            // reports no progress inside a phase.
            Text(
              l10n.benchmarkEstimatedTime(
                BenchmarkEstimate(run.options).minutes,
              ),
              style: UIs.text12Grey,
            ),
            // A poll that keeps failing is the one thing a spinner actively
            // misrepresents: it says the run is progressing when this device
            // has not heard from the server in half an hour. The run itself is
            // untouched — it is in its own session — so this is about the page
            // being honest, not about the benchmark.
            if (run.pollError.isNotEmpty) ...[
              UIs.height7,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The warning hue on the glyph only: at 12px it is too
                  // faint on a light card to carry text, and the message is
                  // something to read.
                  const Icon(
                    Icons.sync_problem,
                    size: 15,
                    color: StatePalette.warn,
                  ),
                  UIs.width7,
                  Expanded(child: Text(run.pollError, style: UIs.text12)),
                ],
              ),
            ],
            // Said only once the silence is longer than a start should take.
            // yabs prints nothing until it has probed two addresses that a good
            // share of networks blackhole, and without this the card is a
            // spinner over an empty log with no account of itself.
            if (phase == BenchmarkPhase.starting &&
                run.elapsed > const Duration(seconds: 20)) ...[
              UIs.height7,
              Text(l10n.benchmarkNoOutputYet, style: UIs.text12Grey),
              // What it is actually sitting in. The only thing that turns
              // "stuck" into something anybody can act on.
              if (run.processes.isNotEmpty) ...[
                UIs.height7,
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 140),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(run.processes, style: _mono),
                  ),
                ),
              ],
            ],
            if (run.log.isNotEmpty) ...[
              UIs.height13,
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: true,
                // `ExpansionTile` draws a divider above and below itself once
                // open, which inside a card reads as two stray rules across it.
                // An empty `Border` is how the widget is told to draw none —
                // there is no flag for it.
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(l10n.benchmarkRawLog, style: UIs.text13Grey),
                children: [BenchmarkLogView(log: run.log)],
              ),
            ],
            UIs.height7,
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Btn.row(
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                text: libL10n.stop,
                mainAxisSize: MainAxisSize.min,
                onTap: busy ? null : onCancel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _tabularGrey = TextStyle(
    color: Colors.grey,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The mono caption: a dump read beside 12px text.
  static const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12);
}
