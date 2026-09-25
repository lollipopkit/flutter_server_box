import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';

/// The segment of a [SegmentedTabs] labelled [label]: the same words may be
/// on screen elsewhere, a heading or a card's title.
Finder segment(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is SegmentedTabs),
  matching: find.text(label),
);
