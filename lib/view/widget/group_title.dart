import 'dart:math' as math;

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
    this.rightColor,
    this.padding = const EdgeInsets.fromLTRB(3, 17, 3, 7),
  });

  final String title;

  /// A summary of the group, at the far end of the rule.
  final String? right;

  /// [right]'s colour where it is a warning rather than a summary.
  final Color? rightColor;

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
        builder: (context, cons) {
          final title = this.title.toUpperCase();
          final titleStyle = TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.9,
            color: UIs.textGrey.color,
          );
          // The name first, up to 60 %: a long one beside a sentence of a
          // value took the row past a phone's width.
          final bounded = cons.maxWidth.isFinite;
          final titleMax = bounded ? cons.maxWidth * 0.6 : double.infinity;
          final titleWidth = bounded
              ? math.min(_measure(context, title, titleStyle), titleMax)
              : 0.0;
          final rightMax = bounded
              ? math.max(0.0, cons.maxWidth - titleWidth - 2 * 9 - _ruleMin)
              : double.infinity;
          return Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: titleMax),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
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
                    style: rightColor == null
                        ? UIs.text11Grey
                        : UIs.text11Grey.copyWith(color: rightColor),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// The shortest rule worth drawing between the name and the value.
  static const _ruleMin = 17.0;

  static double _measure(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
