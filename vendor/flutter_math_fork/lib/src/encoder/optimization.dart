import '../ast/syntax_tree.dart';

import 'matcher.dart';

class OptimizationEntry {
  final Matcher matcher;
  final void Function(GreenNode node) optimize;

  final int? _priority;
  int get priority => _priority ?? matcher.specificity;

  const OptimizationEntry({
    required this.matcher,
    required this.optimize,
    int? priority,
  }) : _priority = priority;
}
