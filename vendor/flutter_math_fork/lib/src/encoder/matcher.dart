import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../ast/syntax_tree.dart';

abstract class Matcher {
  const Matcher();

  int get specificity;
  bool match(GreenNode? node);

  Matcher or(Matcher other) => OrMatcher(this, other);
}

class OrMatcher extends Matcher {
  final Matcher matcher1;
  final Matcher matcher2;

  const OrMatcher(this.matcher1, this.matcher2);

  @override
  bool match(GreenNode? node) => matcher1.match(node) || matcher2.match(node);

  @override
  int get specificity => math.min(matcher1.specificity, matcher2.specificity);
}

class NullMatcher extends Matcher {
  const NullMatcher();
  @override
  int get specificity => 100;
  @override
  bool match(GreenNode? node) => node == null;
}

const isNull = NullMatcher();

class NodeMatcher<T extends GreenNode> extends Matcher {
  final bool Function(T node)? matchSelf;
  final int selfSpecificity;
  final Matcher? child;
  final List<Matcher>? children;
  final Matcher? firstChild;
  final Matcher? lastChild;
  final Matcher? everyChild;
  final Matcher? anyChild;

  const NodeMatcher({
    this.matchSelf,
    this.selfSpecificity = 100,
    this.child,
    this.children,
    this.firstChild,
    this.lastChild,
    this.everyChild,
    this.anyChild,
  });

  @override
  int get specificity =>
      100 +
      (matchSelf != null ? selfSpecificity : 0) +
      [
        (child?.specificity ?? 0),
        (children?.map((child) => child.specificity).sum ?? 0),
        (lastChild?.specificity ?? 0),
        (everyChild?.specificity ?? 0) * 3,
        (anyChild?.specificity ?? 0),
      ].max;

  bool match(GreenNode? node) {
    if (node is! T) return false;
    if (matchSelf != null && matchSelf!(node) == false) return false;
    if (child != null) {
      if (node.children.length != 1) return false;
      if (!child!.match(node.children.first)) return false;
    }
    if (children != null) {
      if (children!.length != node.children.length) return false;
      for (var index = 0; index < node.children.length; index++) {
        if (!children![index].match(node.children[index])) return false;
      }
    }
    if (firstChild != null) {
      if (node.children.isEmpty) return false;
      if (!firstChild!.match(node.children.first)) return false;
    }
    if (lastChild != null) {
      if (node.children.isEmpty) return false;
      if (!lastChild!.match(node.children.last)) return false;
    }
    if (everyChild != null && !node.children.every(everyChild!.match)) {
      return false;
    }
    if (anyChild != null && !node.children.any(anyChild!.match)) return false;

    return true;
  }
}

NodeMatcher<T> isA<T extends GreenNode>({
  bool Function(T node)? matchSelf,
  int selfSpecificity = 100,
  Matcher? child,
  List<Matcher>? children,
  Matcher? firstChild,
  Matcher? lastChild,
  Matcher? everyChild,
  Matcher? anyChild,
}) =>
    NodeMatcher<T>(
      matchSelf: matchSelf,
      selfSpecificity: selfSpecificity,
      child: child,
      children: children,
      firstChild: firstChild,
      lastChild: lastChild,
      everyChild: everyChild,
      anyChild: anyChild,
    );
