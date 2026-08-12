import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// The card/form grid used by the pages that lay their content out in columns.
///
/// Left to itself on a wide desktop window a grid of these produced five or six
/// narrow columns, and reading one page meant crossing the whole screen. Edit
/// pages suffered most: a single form became five columns of unrelated fields.
/// Hence both a wider column and a ceiling on how many of them there can be.
class PageColumns extends StatelessWidget {
  const PageColumns({
    super.key,
    required this.children,
    this.controller,
    this.bottomInset = 0,
  });

  final List<Widget> children;

  /// The grid's scroll position, for a page with something floating over it
  /// that has to know when the content moves.
  final ScrollController? controller;

  /// Room below the last card, for whatever is floating there. Without it the
  /// bottom of the page can only be read by scrolling past its own end.
  final double bottomInset;

  /// Half again the default. A column now comfortably holds a chart with its
  /// axis labels, or a form field with its description.
  static const columnWidth = UIs.columnWidth * 1.5;

  static const _maxColumns = 3;

  /// Wide enough for [_maxColumns] and no more. Derived from the grid's own
  /// arithmetic rather than written out, so it follows if either input
  /// changes — a cap without the width just leaves emptier columns.
  static final maxWidth =
      _maxColumns * columnWidth +
      (_maxColumns - 1) * _spacing +
      _padding.horizontal;

  static const _spacing = 8.0;
  static const _padding = MasonryList.kPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: MasonryList(
          controller: controller,
          columnWidth: columnWidth,
          maxColumns: _maxColumns,
          spacing: _spacing,
          padding: _padding.copyWith(bottom: _padding.bottom + bottomInset),
          children: children,
        ),
      ),
    );
  }
}
