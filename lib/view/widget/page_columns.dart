import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// A readable, ordered grid for forms and card-based settings pages.
///
/// The default adaptive list can create many narrow columns on a wide desktop
/// window. This grid uses wider columns, caps the layout at three columns, and
/// keeps children in reading order across rows.
class PageColumns extends StatelessWidget {
  const PageColumns({super.key, required this.children});

  final List<Widget> children;

  static const columnWidth = UIs.columnWidth * 1.5;
  static const _maxColumns = 3;
  static const _spacing = 10.0;
  static const _padding = MultiList.kOuterPadding;

  static final maxWidth =
      _maxColumns * columnWidth +
      (_maxColumns - 1) * _spacing +
      _padding.horizontal;

  @visibleForTesting
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
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (_, constraints) {
              final columns = columnsFor(constraints.maxWidth);
              return SingleChildScrollView(
                padding: _padding,
                child: columns == 1
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: _spacing,
                        children: children,
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: _spacing,
                        children: [
                          for (var column = 0; column < columns; column++)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: _spacing,
                                children: [
                                  for (
                                    var index = column;
                                    index < children.length;
                                    index += columns
                                  )
                                    children[index],
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
