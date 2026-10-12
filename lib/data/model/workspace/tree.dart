import 'dart:ui' show Rect;

/// Which way a split divides its space: [row] puts its halves side by side,
/// [col] one over the other.
///
/// Stored by name, like every enum here.
enum WsAxis { row, col }

/// One edge of a pane, and the middle: where a tab dropped on it goes.
enum WsDropZone {
  left,
  right,
  top,
  bottom,
  center;

  /// The split a drop on this edge makes; null for [center], which merges.
  WsAxis? get axis => switch (this) {
    left || right => WsAxis.row,
    top || bottom => WsAxis.col,
    center => null,
  };

  /// Whether the dropped tab's new pane goes before the one it was dropped on.
  bool get before => this == left || this == top;
}

/// A workspace's layout: panes at the leaves, splits between them.
///
/// A binary tree rather than a grid of columns, because "split right" is
/// asked of *one* pane: the two halves it makes share that pane's space and
/// nothing else, which is a node replacing a leaf. A grid would have to grow a
/// whole column for it, and a pane split right then down then right again has
/// no grid it fits.
///
/// Generic in the leaf, so a template — the same shape holding the views each
/// pane opens with — is this tree too rather than a second one.
sealed class WsNode<T> {
  const WsNode();

  Map<String, dynamic> toJson(Object? Function(T leaf) leafToJson);

  /// Null for anything this build cannot read, so one malformed record drops
  /// the layout it is in rather than throwing out of a restore.
  static WsNode<T>? fromJson<T>(Object? json, T? Function(Object? raw) leaf) {
    if (json is! Map) return null;
    final split = json['split'];
    if (split == null) {
      final value = leaf(json['leaf']);
      return value == null ? null : WsLeaf(value);
    }
    final axis = WsAxis.values.asNameMap()[split];
    final ratio = json['ratio'];
    final a = fromJson(json['a'], leaf);
    final b = fromJson(json['b'], leaf);
    if (axis == null || ratio is! num) {
      // A split whose own fields are unreadable still has children worth
      // keeping: the layout loses one division, not the panes in it.
      return a ?? b;
    }
    if (a == null) return b;
    if (b == null) return a;
    return WsSplit(axis, WsSplit.clampRatio(ratio.toDouble()), a, b);
  }
}

final class WsLeaf<T> extends WsNode<T> {
  const WsLeaf(this.value);

  final T value;

  @override
  Map<String, dynamic> toJson(Object? Function(T leaf) leafToJson) => {
    'leaf': leafToJson(value),
  };
}

final class WsSplit<T> extends WsNode<T> {
  const WsSplit(this.axis, this.ratio, this.a, this.b);

  final WsAxis axis;

  /// [a]'s share of the space, the rest being [b]'s.
  final double ratio;

  final WsNode<T> a;
  final WsNode<T> b;

  /// How far a seam can be dragged. A pane narrower than this is a strip
  /// nobody can read anything in, and one dragged to nothing could not be
  /// grabbed again.
  static const minRatio = 0.15;
  static const maxRatio = 0.85;

  static double clampRatio(double r) =>
      r.isNaN ? 0.5 : r.clamp(minRatio, maxRatio);

  WsSplit<T> copyWith({double? ratio, WsNode<T>? a, WsNode<T>? b}) =>
      WsSplit(axis, ratio ?? this.ratio, a ?? this.a, b ?? this.b);

  @override
  Map<String, dynamic> toJson(Object? Function(T leaf) leafToJson) => {
    'split': axis.name,
    'ratio': ratio,
    'a': a.toJson(leafToJson),
    'b': b.toJson(leafToJson),
  };
}

/// Which child to take at each split on the way down to one node: `false` is
/// [WsSplit.a], `true` is [WsSplit.b].
typedef WsPath = List<bool>;

/// A pane's place on screen.
typedef WsPaneRect = ({String id, Rect rect});

/// A seam between two halves of a split: where it is, and what dragging it
/// changes.
typedef WsSeam = ({
  /// The split it belongs to, from the root; empty for the root itself.
  WsPath path,
  WsAxis axis,

  /// Its hit area, wider than the line it draws.
  Rect rect,

  /// The length the ratio is a fraction of.
  double extent,
  double ratio,
});

extension WsNodeX<T> on WsNode<T> {
  /// The leaves, in reading order: left before right, top before bottom.
  List<T> get leaves {
    final out = <T>[];
    void walk(WsNode<T> n) {
      switch (n) {
        case WsLeaf(:final value):
          out.add(value);
        case WsSplit(:final a, :final b):
          walk(a);
          walk(b);
      }
    }

    walk(this);
    return out;
  }

  /// This tree with each leaf mapped through [f].
  WsNode<R> map<R>(R Function(T leaf) f) => switch (this) {
    WsLeaf(:final value) => WsLeaf(f(value)),
    WsSplit(:final axis, :final ratio, :final a, :final b) => WsSplit(
      axis,
      ratio,
      a.map(f),
      b.map(f),
    ),
  };

  /// [target] replaced by [replacement]; the tree unchanged without it.
  WsNode<T> replaceLeaf(T target, WsNode<T> replacement) => switch (this) {
    WsLeaf(:final value) => value == target ? replacement : this,
    final WsSplit<T> s => s.copyWith(
      a: s.a.replaceLeaf(target, replacement),
      b: s.b.replaceLeaf(target, replacement),
    ),
  };

  /// Every leaf after the first of its value gone, its sibling taking its
  /// space; the tree itself when there are none. A leaf is a pane, and one
  /// pane cannot be in two places.
  WsNode<T> withoutRepeats() {
    final seen = <T>{};
    WsNode<T>? walk(WsNode<T> n) {
      switch (n) {
        case WsLeaf(:final value):
          return seen.add(value) ? n : null;
        case final WsSplit<T> s:
          final a = walk(s.a);
          final b = walk(s.b);
          if (a == null) return b;
          if (b == null) return a;
          return identical(a, s.a) && identical(b, s.b)
              ? s
              : s.copyWith(a: a, b: b);
      }
    }

    // The first leaf always survives, so the walk never comes back empty.
    return walk(this)!;
  }

  /// [target] gone, its sibling taking the space they shared. Null when
  /// [target] was all there was.
  WsNode<T>? removeLeaf(T target) {
    switch (this) {
      case WsLeaf(:final value):
        return value == target ? null : this;
      case final WsSplit<T> s:
        final a = s.a.removeLeaf(target);
        final b = s.b.removeLeaf(target);
        if (a == null) return b;
        if (b == null) return a;
        return s.copyWith(a: a, b: b);
    }
  }

  /// [target] split along [axis], [leaf] on the side [before] says, the two
  /// halves even.
  WsNode<T> splitLeaf(
    T target,
    WsAxis axis,
    T leaf, {
    bool before = false,
  }) {
    final old = WsLeaf<T>(target);
    final added = WsLeaf<T>(leaf);
    return replaceLeaf(
      target,
      WsSplit(axis, 0.5, before ? added : old, before ? old : added),
    );
  }

  /// The split at [path] given [ratio], clamped; the tree unchanged where the
  /// path leads to no split.
  WsNode<T> withRatio(WsPath path, double ratio, [int depth = 0]) {
    final self = this;
    if (self is! WsSplit<T>) return self;
    if (depth == path.length) {
      return self.copyWith(ratio: WsSplit.clampRatio(ratio));
    }
    return path[depth]
        ? self.copyWith(b: self.b.withRatio(path, ratio, depth + 1))
        : self.copyWith(a: self.a.withRatio(path, ratio, depth + 1));
  }

  /// Every pane's rectangle in [area], and every seam between them.
  ///
  /// [gap] logical pixels go to each seam, so neighbouring panes never
  /// overlap: one for a hairline drawn between them, more for panes drawn as
  /// tiles of their own.
  ({List<WsPaneRect> panes, List<WsSeam> seams}) layout(
    Rect area, {
    required String Function(T leaf) idOf,
    double seamHitWidth = 13,
    double gap = 1,
  }) {
    final panes = <WsPaneRect>[];
    final seams = <WsSeam>[];
    void lay(WsNode<T> n, Rect r, WsPath path) {
      switch (n) {
        case WsLeaf(:final value):
          panes.add((id: idOf(value), rect: r));
        case WsSplit(:final axis, :final ratio, :final a, :final b):
          final row = axis == WsAxis.row;
          final extent = row ? r.width : r.height;
          // Rounded so a pane edge lands on a pixel and text in it is crisp.
          final first = ((extent - gap) * ratio).roundToDouble().clamp(
            0.0,
            (extent - gap).clamp(0.0, double.infinity),
          );
          final half = seamHitWidth / 2;
          // Before the children, so seams come out outermost first.
          seams.add((
            path: path,
            axis: axis,
            rect: row
                ? Rect.fromLTWH(
                    r.left + first + gap / 2 - half,
                    r.top,
                    seamHitWidth,
                    r.height,
                  )
                : Rect.fromLTWH(
                    r.left,
                    r.top + first + gap / 2 - half,
                    r.width,
                    seamHitWidth,
                  ),
            extent: extent,
            ratio: ratio,
          ));
          final rest = (extent - first - gap).clamp(0.0, double.infinity);
          if (row) {
            lay(a, Rect.fromLTWH(r.left, r.top, first, r.height), [
              ...path,
              false,
            ]);
            lay(b, Rect.fromLTWH(r.left + first + gap, r.top, rest, r.height), [
              ...path,
              true,
            ]);
          } else {
            lay(a, Rect.fromLTWH(r.left, r.top, r.width, first), [
              ...path,
              false,
            ]);
            lay(b, Rect.fromLTWH(r.left, r.top + first + gap, r.width, rest), [
              ...path,
              true,
            ]);
          }
      }
    }

    lay(this, area, const []);
    return (panes: panes, seams: seams);
  }
}

/// Which way the keyboard moves focus between panes.
enum WsDirection { left, right, up, down }

/// The pane next to [from] in [direction], by where the panes are on screen
/// rather than where they are in the tree: "the one to the left" is what is
/// to the left, whichever split put it there.
///
/// Of the panes wholly on that side, the one whose centre is nearest — so from
/// the bottom half of a column, left lands on what is beside the bottom half.
String? neighbourPane(
  List<WsPaneRect> panes,
  String from,
  WsDirection direction,
) {
  final origin = panes.where((p) => p.id == from).firstOrNull?.rect;
  if (origin == null) return null;
  final c = origin.center;
  String? best;
  var bestDistance = double.infinity;
  for (final p in panes) {
    if (p.id == from) continue;
    final r = p.rect;
    // A pixel of slack: the seam between two neighbours is one wide.
    final onSide = switch (direction) {
      WsDirection.left => r.right <= origin.left + 1,
      WsDirection.right => r.left >= origin.right - 1,
      WsDirection.up => r.bottom <= origin.top + 1,
      WsDirection.down => r.top >= origin.bottom - 1,
    };
    if (!onSide) continue;
    final d = (r.center.dx - c.dx).abs() + (r.center.dy - c.dy).abs();
    if (d < bestDistance) {
      bestDistance = d;
      best = p.id;
    }
  }
  return best;
}
