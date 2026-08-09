import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// Caps page content at a readable width and centres what's left over.
///
/// [AutoMultiList] fits as many columns as the window allows, so a wide
/// desktop window produced five or more narrow columns and the eye had to
/// travel the full width of the screen to read one page. Four is the point
/// where a column still holds a chart or a form field at a usable size.
///
/// Wrap the scrolling body, not individual cards: constraining each card would
/// leave the columns where they are and only narrow their contents.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child});

  final Widget child;

  /// Four [UIs.columnWidth] columns plus the gaps between them. Derived rather
  /// than written out, so it follows if that constant ever changes.
  static const value = 4 * (UIs.columnWidth + 10);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: value),
        child: child,
      ),
    );
  }
}
