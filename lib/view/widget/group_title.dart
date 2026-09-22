import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// The heading over a group of rows: a name, a rule to where the group ends,
/// and optionally what the group currently says.
///
/// Shared by the server editor and the settings, which is the point: a group
/// of form rows reads the same wherever it is, and two copies of this drifted
/// apart the first time one of them was tuned.
class GroupTitle extends StatelessWidget {
  const GroupTitle(
    this.title, {
    super.key,
    this.right,
    this.padding = const EdgeInsets.fromLTRB(3, 17, 3, 7),
  });

  final String title;

  /// A summary of the group, at the far end of the rule.
  final String? right;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      // Measured first, because the rule and the value want opposite things.
      // As two flex children they split the free space, so the rule stopped
      // halfway across and a short value floated in the middle with a gap
      // after it; as a bare `Text` the value takes its natural width, and one
      // that turned out to be a whole sentence took the row 52 points past the
      // window. Held back to what is left over the rule's own minimum, the
      // value is its own width until there is no room for it to be.
      child: LayoutBuilder(
        builder: (_, cons) {
          final rightMax = cons.maxWidth.isFinite
              ? (cons.maxWidth * 0.5).clamp(0.0, cons.maxWidth)
              : double.infinity;
          return Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.9,
                  color: UIs.textGrey.color,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(child: Divider(height: 1)),
              if (right != null) ...[
                const SizedBox(width: 9),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: rightMax),
                  child: Text(
                    right!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UIs.text11Grey,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
