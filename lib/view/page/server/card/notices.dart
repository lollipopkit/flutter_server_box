import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/sizes.dart';

// --- The states that are not a body ---
//
// Connecting is not one of them. The height does not move and the spinner
// in [ServerCardConnAction]'s slot says something is happening; a line under
// the title as well was the same answer twice, which is what a line in the
// list already declines to do by giving up its spinner for the one across
// its middle.
//
// Not a skeleton either. A skeleton grows to the height of a success first
// and has to shrink back when the answer is that there is nothing — which
// is the one movement a list of cards cannot afford.

/// What went wrong, and what was actually said.
///
/// Both, because the first is this app's guess and the second is the only
/// thing a search engine or a bug report can use.
class ServerCardError extends StatelessWidget {
  const ServerCardError({super.key, required this.err});

  final Err err;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: ServerCardSizes.gap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              err.solution ?? libL10n.fail,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: StatePalette.warn,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (err.message case final message? when message.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.grey,
                  fontFamily: 'monospace',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The connection is up and the numbers have stopped.
///
/// The numbers stay exactly as they were: the last reading is still the most
/// recent thing known about the machine, and falling back to the connecting
/// state would throw that away. What changes is that the chart goes grey and
/// this says how old they are.
class ServerCardStale extends StatelessWidget {
  const ServerCardStale({super.key, required this.at});

  /// When the last sample landed.
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: ServerCardSizes.gap),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 15, color: StatePalette.warn),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              l10n.lastSampleFmt(at.toAgoStr()),
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: StatePalette.warn,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The one thing worth saying about this machine, or nothing.
///
/// Drawn only when a reading is over the line: a footer that is always there
/// is a line of text on every card that nobody reads, and this one has to be
/// read the once it appears.
class ServerCardFoot extends StatelessWidget {
  const ServerCardFoot({super.key, required this.over});

  /// The first reading that is over its line, which is what this says.
  final ServerMetric over;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ServerCardSizes.rowGap),
      child: Row(
        children: [
          Container(
            width: ServerCardSizes.dot,
            height: ServerCardSizes.dot,
            decoration: const BoxDecoration(
              color: StatePalette.warn,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${over.label} ${over.value} · ${over.note}',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: StatePalette.warn,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
