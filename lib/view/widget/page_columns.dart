import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// The card/form grid used by the pages that lay their content out in columns.
///
/// Left to itself on a wide desktop window a grid of these produced five or six
/// narrow columns, and reading one page meant crossing the whole screen. Edit
/// pages suffered most: a single form became five columns of unrelated fields.
/// Hence both a wider column and a ceiling on how many of them there can be.
///
/// Children are placed in the order they are given — the first in the first
/// column, the second in the second, and so on across and down. Not packed by
/// height like the home grid: these pages are forms, and a form whose first
/// field lands at the top of the *second* column because that column happened
/// to be shorter is a form nobody can read in the order it was written.
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

  static const columnWidth = UIs.pageColumnWidth;

  static const _maxColumns = 3;

  /// Wide enough for [_maxColumns] and no more. Derived from the grid's own
  /// arithmetic rather than written out, so it follows if either input
  /// changes — a cap without the width just leaves emptier columns.
  static final maxWidth =
      _maxColumns * columnWidth +
      (_maxColumns - 1) * _spacing +
      _padding.horizontal;

  // Both taken from the grid rather than restated. `_spacing` was written out
  // as its own 8 and would have gone on saying 8 after the grid stopped, which
  // is the disagreement the comment below is there to prevent.
  static const _spacing = MasonryList.kSpacing;
  static const _padding = MasonryList.kPadding;

  /// How many columns [width] holds. The same arithmetic [MasonryList] uses,
  /// so a page that switches between the two does not change width.
  static int columnsFor(double width) {
    final available = width - _padding.horizontal;
    if (available <= 0) return 1;
    return ((available + _spacing) / (columnWidth + _spacing)).floor().clamp(
      1,
      _maxColumns,
    );
  }

  @override
  Widget build(BuildContext context) {
    // `SizedBox.expand` rather than letting the scroll view size itself: a
    // `SingleChildScrollView` under the loose constraints a `Center` passes
    // down takes the height of its content, so a page with less than a
    // screenful of cards ended up centred vertically, floating with empty
    // space above it. Told to fill, it starts at the top and scrolls only
    // when there is more than fits.
    //
    // Requires a bounded height, which every caller has — this is a page
    // body, and the grid it replaced needed one too.
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (_, cons) {
              final columns = columnsFor(cons.maxWidth);
              return SingleChildScrollView(
                controller: controller,
                padding: _padding.copyWith(
                  bottom: _padding.bottom + bottomInset,
                ),
                child: columns == 1
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: _spacing,
                        children: children,
                      )
                    : Row(
                        // Columns are as tall as what is in them, and a short
                        // one beside a long one should stop rather than
                        // stretch.
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: _spacing,
                        children: [
                          for (var col = 0; col < columns; col++)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: _spacing,
                                children: [
                                  for (
                                    var i = col;
                                    i < children.length;
                                    i += columns
                                  )
                                    children[i],
                                ],
                              ),
                            ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
