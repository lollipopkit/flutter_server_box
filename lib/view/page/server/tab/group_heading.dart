import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/chart_palette.dart';

/// One section's heading: what these machines have in common, how many of
/// them there are, and how many are over the line.
///
/// The count is what a heading is for at this size — a section of eight is
/// eight tiles nobody counts — and the alert count beside it is the one
/// thing that would otherwise need the section read to find. A section with
/// nothing wrong in it says nothing about alerts rather than saying zero.
class ServerGroupHeading extends StatelessWidget {
  const ServerGroupHeading({
    super.key,
    required this.label,
    required this.count,
    required this.over,
    required this.first,
  });

  /// What the section's machines have in common — the label `groupByTag`
  /// gave it. Null is drawn as the section of machines that carry no tag.
  final String? label;

  /// How many machines the section holds.
  final int count;

  /// How many of them are over the line. Nothing is drawn for it at 0.
  final int over;

  /// Whether this is the topmost section, which has no section above it to
  /// be kept apart from.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lined up with the cards under it, which carry their own margin.
      padding: EdgeInsets.fromLTRB(4, first ? 3 : 17, 4, 7),
      child: Row(
        children: [
          Text(
            label ?? l10n.ungrouped,
            style: const TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Divider(
              height: Hairline.thickness,
              thickness: Hairline.thickness,
              color: Hairline.color(context),
            ),
          ),
          const SizedBox(width: 9),
          Text('$count', style: UIs.text11Grey),
          if (over > 0) ...[
            const SizedBox(width: 7),
            const Icon(Icons.warning_amber, size: 13, color: StatePalette.warn),
            const SizedBox(width: 3),
            Text(
              '$over',
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: StatePalette.warn,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
