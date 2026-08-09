import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// The card/form grid used by the pages that lay their content out in columns.
///
/// Owns both halves of the decision, because they have to agree:
/// [AutoMultiList] derives its column count from the width it is given, so
/// setting a cap without widening the columns just leaves emptier ones, and
/// widening them without a cap lets a large window keep adding more.
///
/// Left to itself on a wide desktop window it produced five or six narrow
/// columns, and reading one page meant crossing the whole screen. Edit pages
/// suffered most: a single form became five columns of unrelated fields.
class PageColumns extends StatelessWidget {
  const PageColumns({super.key, required this.children});

  final List<Widget> children;

  /// Half again the default. A column now comfortably holds a chart with its
  /// axis labels, or a form field with its description.
  static const columnWidth = UIs.columnWidth * 1.5;

  static const _maxColumns = 3;

  /// Wide enough for [_maxColumns] columns and no more, matching
  /// `AutoMultiList`'s own `floor((width - outerPadding) / columnWidth)`.
  /// Derived rather than written out so it follows if either input changes.
  static final maxWidth =
      _maxColumns * columnWidth +
      (_maxColumns - 1) * _betweenPadding +
      MultiList.kOuterPadding.horizontal;

  static const _betweenPadding = 10.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AutoMultiList(
          columnWidth: columnWidth,
          betweenPadding: _betweenPadding,
          children: children,
        ),
      ),
    );
  }
}
