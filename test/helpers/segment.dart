import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The segment of a [SegmentedTabs] labelled [label]: by its text, or — in a
/// row too narrow for its labels, icons only — by its tooltip. Within the
/// control, since the same words may be on screen elsewhere.
Finder segment(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is SegmentedTabs),
  matching: find.byWidgetPredicate(
    (w) => (w is Text && w.data == label) || (w is Tooltip && w.message == label),
  ),
);
