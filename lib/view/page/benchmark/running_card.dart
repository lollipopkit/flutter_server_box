import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/view/page/benchmark/estimate.dart';
import 'package:server_box/view/page/benchmark/history_tile.dart';
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
    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                UIs.width13,
                Expanded(child: Text(phase.label, style: UIs.text15Bold)),
                Text(fmtDuration(run.elapsed), style: UIs.textGrey),
              ],
            ),
            UIs.height13,
            // The estimate is what makes a fifteen-minute wait legible. It is
            // not a progress bar because there is nothing to base one on: yabs
            // reports no progress inside a phase.
            Text(
              l10n.benchmarkEstimatedTime(
                '${BenchmarkEstimate(run.options).minutes}',
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
                  const Icon(
                    Icons.sync_problem,
                    size: 15,
                    color: Colors.orange,
                  ),
                  UIs.width7,
                  Expanded(
                    child: Text(
                      run.pollError,
                      style: UIs.text12Grey.copyWith(color: Colors.orange),
                    ),
                  ),
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      run.processes,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
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
            UIs.height13,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onCancel,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(libL10n.stop),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
