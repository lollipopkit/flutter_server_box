import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import '../render/layout/line.dart';
import '../render/layout/line_editable.dart';
import '../utils/iterable_extensions.dart';
import '../utils/num_extension.dart';
import '../utils/wrapper.dart';
import '../widgets/controller.dart';
import '../widgets/mode.dart';
import '../widgets/selectable.dart';
import 'nodes/space.dart';
import 'nodes/sqrt.dart';
import 'options.dart';
import 'spacing.dart';
import 'types.dart';

/// Roslyn's Red-Green Tree
///
/// [Description of Roslyn's Red-Green Tree](https://docs.microsoft.com/en-us/archive/blogs/ericlippert/persistence-facades-and-roslyns-red-green-trees)
class SyntaxTree {
  /// Root of the green tree
  final EquationRowNode greenRoot;

  SyntaxTree({
    required this.greenRoot,
  });

  /// Root of the red tree
  late final SyntaxNode root = SyntaxNode(
    parent: null,
    value: greenRoot,
    pos: -1, // Important
  );

  /// Replace node at [pos] with [newNode]
  SyntaxTree replaceNode(SyntaxNode pos, GreenNode newNode) {
    if (identical(pos.value, newNode)) {
      return this;
    }
    if (identical(pos, root)) {
      return SyntaxTree(greenRoot: newNode.wrapWithEquationRow());
    }
    final posParent = pos.parent;
    if (posParent == null) {
      throw ArgumentError(
          'The replaced node is not the root of this tree but has no parent');
    }
    return replaceNode(
        posParent,
        posParent.value.updateChildren(posParent.children
            .map((child) => identical(child, pos) ? newNode : child?.value)
            .toList(growable: false)));
  }

  List<SyntaxNode> findNodesAtPosition(int position) {
    var curr = root;
    final res = <SyntaxNode>[];
    while (true) {
      res.add(curr);
      final next = curr.children.firstWhereOrNull((child) => child == null
          ? false
          : child.range.start <= position && child.range.end >= position);
      if (next == null) break;
      curr = next;
    }
    return res;
  }

  EquationRowNode findNodeManagesPosition(int position) {
    var curr = root;
    var lastEqRow = root.value as EquationRowNode;
    while (true) {
      final next = curr.children.firstWhereOrNull(
        (child) => child == null
            ? false
            : child.range.start <= position && child.range.end >= position,
      );
      if (next == null) break;
      if (next.value is EquationRowNode) {
        lastEqRow = next.value as EquationRowNode;
      }
      curr = next;
    }
    // assert(curr.value is EquationRowNode);
    return lastEqRow;
  }

  EquationRowNode findLowestCommonRowNode(int position1, int position2) {
    final redNodes1 = findNodesAtPosition(position1);
    final redNodes2 = findNodesAtPosition(position2);
    for (var index = math.min(redNodes1.length, redNodes2.length) - 1;
        index >= 0;
        index--) {
      final node1 = redNodes1[index].value;
      final node2 = redNodes2[index].value;
      if (node1 == node2 && node1 is EquationRowNode) {
        return node1;
      }
    }
    return greenRoot;
  }

  List<GreenNode> findSelectedNodes(int position1, int position2) {
    final rowNode = findLowestCommonRowNode(position1, position2);

    final localPos1 = position1 - rowNode.pos;
    final localPos2 = position2 - rowNode.pos;
    return rowNode.clipChildrenBetween(localPos1, localPos2).children;
  }

  // Build widget tree
  Widget buildWidget(MathOptions options) => root.buildWidget(options).widget;
}

/// Red Node. Immutable facade for math nodes.
///
/// [Description of Roslyn's Red-Green Tree](https://docs.microsoft.com/en-us/archive/blogs/ericlippert/persistence-facades-and-roslyns-red-green-trees).
///
/// [SyntaxNode] is an immutable facade over [GreenNode]. It stores absolute
/// information and context parameters of an abstract syntax node which cannot
/// be stored inside [GreenNode]. Every node of the red tree is evaluated
/// top-down on demand.
class SyntaxNode {
  final SyntaxNode? parent;
  final GreenNode value;
  final int pos;
  SyntaxNode({
    required this.parent,
    required this.value,
    required this.pos,
  });

  /// Lazily evaluated children of current [SyntaxNode]
  late final List<SyntaxNode?> children = List.generate(
      value.children.length,
      (index) => value.children[index] != null
          ? SyntaxNode(
              parent: this,
              value: value.children[index]!,
              pos: this.pos + value.childPositions[index],
            )
          : null,
      growable: false);

  /// [GreenNode.getRange]
  late final TextRange range = value.getRange(pos);

  /// [GreenNode.editingWidth]
  int get width => value.editingWidth;

  /// [GreenNode.capturedCursor]
  int get capturedCursor => value.capturedCursor;

  /// This is where the actual widget building process happens.
  ///
  /// This method tries to reduce widget rebuilds. Rebuild bypass is determined
  /// by the following process:
  /// - If oldOptions == newOptions, bypass
  /// - If [GreenNode.shouldRebuildWidget], force rebuild
  /// - Call [buildWidget] on [children]. If the results are identical to the
  /// results returned by [buildWidget] called last time, then bypass.
  BuildResult buildWidget(MathOptions options) {
    if (value is PositionDependentMixin) {
      (value as PositionDependentMixin).updatePos(pos);
    }

    if (value._oldOptions != null && options == value._oldOptions) {
      return value._oldBuildResult!;
    }
    final childOptions = value.computeChildOptions(options);

    final newChildBuildResults = _buildChildWidgets(childOptions);

    final bypassRebuild = value._oldOptions != null &&
        !value.shouldRebuildWidget(value._oldOptions!, options) &&
        listEquals(newChildBuildResults, value._oldChildBuildResults);

    value._oldOptions = options;
    value._oldChildBuildResults = newChildBuildResults;
    return bypassRebuild
        ? value._oldBuildResult!
        : (value._oldBuildResult =
            value.buildWidget(options, newChildBuildResults));
  }

  List<BuildResult?> _buildChildWidgets(List<MathOptions> childOptions) {
    assert(children.length == childOptions.length);
    if (children.isEmpty) return const [];
    return List.generate(children.length,
        (index) => children[index]?.buildWidget(childOptions[index]),
        growable: false);
  }
}

/// Node of Roslyn's Green Tree. Base class of any math nodes.
///
/// [Description of Roslyn's Red-Green Tree](https://docs.microsoft.com/en-us/archive/blogs/ericlippert/persistence-facades-and-roslyns-red-green-trees).
///
/// [GreenNode] stores any context-free information of a node and is
/// constructed bottom-up. It needs to indicate or store:
/// - Necessary parameters for this math node.
/// - Layout algorithm for this math node, if renderable.
/// - Strutural information of the tree ([children])
/// - Context-free properties for other purposes. ([editingWidth], etc.)
///
/// Due to their context-free property, [GreenNode] can be canonicalized and
/// deduplicated.
abstract class GreenNode {
  /// Children of this node.
  ///
  /// [children] stores structural information of the Red-Green Tree.
  /// Used for green tree updates. The order of children should strictly
  /// adheres to the cursor-visiting order in editing mode, in order to get a
  /// correct cursor range in the editing mode. E.g., for [SqrtNode], when
  /// moving cursor from left to right, the cursor first enters index, then
  /// base, so it should return [index, base].
  ///
  /// Please ensure [children] works in the same order as [updateChildren],
  /// [computeChildOptions], and [buildWidget].
  List<GreenNode?> get children;

  /// Return a copy of this node with new children.
  ///
  /// Subclasses should override this method. This method provides a general
  /// interface to perform structural updates for the green tree (node
  /// replacement, insertion, etc).
  ///
  /// Please ensure [children] works in the same order as [updateChildren],
  /// [computeChildOptions], and [buildWidget].
  GreenNode updateChildren(covariant List<GreenNode?> newChildren);

  /// Calculate the options passed to children when given [options] from parent
  ///
  /// Subclasses should override this method. This method provides a general
  /// description of the context & style modification introduced by this node.
  ///
  /// Please ensure [children] works in the same order as [updateChildren],
  /// [computeChildOptions], and [buildWidget].
  List<MathOptions> computeChildOptions(MathOptions options);

  /// Compose Flutter widget with child widgets already built
  ///
  /// Subclasses should override this method. This method provides a general
  /// description of the layout of this math node. The child nodes are built in
  /// prior. This method is only responsible for the placement of those child
  /// widgets accroding to the layout & other interactions.
  ///
  /// Please ensure [children] works in the same order as [updateChildren],
  /// [computeChildOptions], and [buildWidget].
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults);

  /// Whether the specific [MathOptions] parameters that this node directly
  /// depends upon have changed.
  ///
  /// Subclasses should override this method. This method is used to determine
  /// whether certain widget rebuilds can be bypassed even when the
  /// [MathOptions] have changed.
  ///
  /// Rebuild bypass is determined by the following process:
  /// - If [oldOptions] == [newOptions], bypass
  /// - If [shouldRebuildWidget], force rebuild
  /// - Call [buildWidget] on [children]. If the results are identical to the
  /// the results returned by [buildWidget] called last time, then bypass.
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions);

  /// Minimum number of "right" keystrokes needed to move the cursor pass
  /// through this node (from the rightmost of the previous node, to the
  /// leftmost of the next node)
  ///
  /// Used only for editing functionalities.
  ///
  /// [editingWidth] stores intrinsic width in the editing mode.
  ///
  /// Please calculate (and cache) the width based on [children]'s widths.
  /// Note that it should strictly simulate the movement of the curosr.
  int get editingWidth;

  /// Number of cursor positions that can be captured within this node.
  ///
  /// By definition, [capturedCursor] = [editingWidth] - 1.
  /// By definition, [TextRange.end] - [TextRange.start] = capturedCursor - 1.
  int get capturedCursor => editingWidth - 1;

  /// [TextRange]
  TextRange getRange(int pos) =>
      TextRange(start: pos + 1, end: pos + capturedCursor);

  /// Position of child nodes.
  ///
  /// Used only for editing functionalities.
  ///
  /// This method stores the layout strucuture for cursor in the editing mode.
  /// You should return positions of children assume this current node is placed
  /// at the starting position. It should be no shorter than [children]. It's
  /// entirely optional to add extra hinting elements.
  List<int> get childPositions;

  /// [AtomType] observed from the left side.
  AtomType get leftType;

  /// [AtomType] observed from the right side.
  AtomType get rightType;

  MathOptions? _oldOptions;
  BuildResult? _oldBuildResult;
  List<BuildResult?>? _oldChildBuildResults;

  Map<String, Object?> toJson() => {
        'type': runtimeType.toString(),
      };
}

/// [GreenNode] that can have children
abstract class ParentableNode<T extends GreenNode?> extends GreenNode {
  @override
  List<T> get children;

  @override
  late final int editingWidth = computeWidth();

  /// Compute width from children. Abstract.
  int computeWidth();

  @override
  late final List<int> childPositions = computeChildPositions();

  /// Compute children positions. Abstract.
  List<int> computeChildPositions();

  @override
  ParentableNode<T> updateChildren(covariant List<T?> newChildren);
}

mixin PositionDependentMixin<T extends GreenNode> on ParentableNode<T> {
  var range = const TextRange(start: 0, end: -1);

  int get pos => range.start - 1;

  void updatePos(int pos) {
    range = getRange(pos);
  }
}

/// [SlotableNode] is those composite node that has editable [EquationRowNode]
/// as children and lay them out into certain slots.
///
/// [SlotableNode] is the most commonly-used node. They share cursor logic and
/// editing logic.
///
/// Depending on node type, some [SlotableNode] can have nulls inside their
/// children list. When null is allowed, it usually means that node will have
/// different layout slot logic depending on non-null children number.
abstract class SlotableNode<T extends EquationRowNode?>
    extends ParentableNode<T> {
  @override
  late final List<T> children = computeChildren();

  /// Compute children. Abstract.
  ///
  /// Used to cache children list
  List<T> computeChildren();

  @override
  int computeWidth() =>
      children.map((child) => child?.capturedCursor ?? 0).sum + 1;

  @override
  List<int> computeChildPositions() {
    var curPos = 0;
    final result = <int>[];
    for (final child in children) {
      result.add(curPos);
      curPos += child?.capturedCursor ?? 0;
    }
    return result;
  }
}

/// [TransparentNode] refers to those node who have zero rendering content
/// iteself, and are expected to be unwrapped for its children during rendering.
///
/// [TransparentNode]s are only allowed to appear directly under
/// [EquationRowNode]s and other [TransparentNode]s. And those nodes have to
/// explicitly unwrap transparent nodes during building stage.
abstract class TransparentNode extends ParentableNode<GreenNode>
    with _ClipChildrenMixin {
  @override
  int computeWidth() => children.map((child) => child.editingWidth).sum;

  @override
  List<int> computeChildPositions() {
    var curPos = 0;
    return List.generate(children.length + 1, (index) {
      if (index == 0) return curPos;
      return curPos += children[index - 1].editingWidth;
    }, growable: false);
  }

  @override
  BuildResult buildWidget(
          MathOptions options, List<BuildResult?> childBuildResults) =>
      BuildResult(
        widget: const Text('This widget should not appear. '
            'It means one of FlutterMath\'s AST nodes '
            'forgot to handle the case for TransparentNodes'),
        options: options,
        results: childBuildResults
            .expand((result) => result!.results ?? [result])
            .toList(growable: false),
      );

  /// Children list when fully expand any underlying [TransparentNode]
  late final List<GreenNode> flattenedChildList = children
      .expand((child) =>
          child is TransparentNode ? child.flattenedChildList : [child])
      .toList(growable: false);

  @override
  late final AtomType leftType = children[0].leftType;

  @override
  late final AtomType rightType = children.last.rightType;
}

/// A row of unrelated [GreenNode]s.
///
/// [EquationRowNode] provides cursor-reachability and editability. It
/// represents a collection of nodes that you can freely edit and navigate.
class EquationRowNode extends ParentableNode<GreenNode>
    with PositionDependentMixin, _ClipChildrenMixin {
  /// If non-null, the leftmost and rightmost [AtomType] will be overriden.
  final AtomType? overrideType;

  @override
  final List<GreenNode> children;

  GlobalKey? _key;
  GlobalKey? get key => _key;

  @override
  int computeWidth() => children.map((child) => child.editingWidth).sum + 2;

  @override
  List<int> computeChildPositions() {
    var curPos = 1;
    return List.generate(children.length + 1, (index) {
      if (index == 0) return curPos;
      return curPos += children[index - 1].editingWidth;
    }, growable: false);
  }

  EquationRowNode({
    required this.children,
    this.overrideType,
  });

  factory EquationRowNode.empty() => EquationRowNode(children: []);

  /// Children list when fully expanded any underlying [TransparentNode].
  late final List<GreenNode> flattenedChildList = children
      .expand((child) =>
          child is TransparentNode ? child.flattenedChildList : [child])
      .toList(growable: false);

  /// Children positions when fully expanded underlying [TransparentNode], but
  /// appended an extra position entry for the end.
  late final List<int> caretPositions = computeCaretPositions();
  List<int> computeCaretPositions() {
    var curPos = 1;
    return List.generate(flattenedChildList.length + 1, (index) {
      if (index == 0) return curPos;
      return curPos += flattenedChildList[index - 1].editingWidth;
    }, growable: false);
  }

  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    final flattenedBuildResults = childBuildResults
        .expand((result) => result!.results ?? [result])
        .toList(growable: false);
    final flattenedChildOptions =
        flattenedBuildResults.map((e) => e.options).toList(growable: false);
    // assert(flattenedChildList.length == actualChildWidgets.length);

    // We need to calculate spacings between nodes
    // There are several caveats to consider
    // - bin can only be bin, if it satisfies some conditions. Otherwise it will
    //   be seen as an ord
    // - There could aligners and spacers. We need to calculate the spacing
    //   after filtering them out, hence the [traverseNonSpaceNodes]
    final childSpacingConfs = List.generate(
      flattenedChildList.length,
      (index) {
        final e = flattenedChildList[index];
        return _NodeSpacingConf(
            e.leftType, e.rightType, flattenedChildOptions[index], 0.0);
      },
      growable: false,
    );
    _traverseNonSpaceNodes(childSpacingConfs, (prev, curr) {
      if (prev?.rightType == AtomType.bin &&
          const {
            AtomType.rel,
            AtomType.close,
            AtomType.punct,
            null,
          }.contains(curr?.leftType)) {
        prev!.rightType = AtomType.ord;
        if (prev.leftType == AtomType.bin) {
          prev.leftType = AtomType.ord;
        }
      } else if (curr?.leftType == AtomType.bin &&
          const {
            AtomType.bin,
            AtomType.open,
            AtomType.rel,
            AtomType.op,
            AtomType.punct,
            null
          }.contains(prev?.rightType)) {
        curr!.leftType = AtomType.ord;
        if (curr.rightType == AtomType.bin) {
          curr.rightType = AtomType.ord;
        }
      }
    });

    _traverseNonSpaceNodes(childSpacingConfs, (prev, curr) {
      if (prev != null && curr != null) {
        prev.spacingAfter = getSpacingSize(
          prev.rightType,
          curr.leftType,
          curr.options.style,
        ).toLpUnder(curr.options);
      }
    });

    _key = GlobalKey();

    final lineChildren = List.generate(
      flattenedBuildResults.length,
      (index) => LineElement(
        child: flattenedBuildResults[index].widget,
        canBreakBefore: false, // TODO
        alignerOrSpacer: flattenedChildList[index] is SpaceNode &&
            (flattenedChildList[index] as SpaceNode).alignerOrSpacer,
        trailingMargin: childSpacingConfs[index].spacingAfter,
      ),
      growable: false,
    );

    final widget = Consumer<FlutterMathMode>(builder: (context, mode, child) {
      if (mode == FlutterMathMode.view) {
        return Line(
          key: _key!,
          children: lineChildren,
        );
      }
      // Each EquationRow will filter out unrelated selection changes (changes
      // happen entirely outside the range of this EquationRow)
      return ProxyProvider<MathController, TextSelection>(
        create: (_) => const TextSelection.collapsed(offset: -1),
        update: (context, controller, _) {
          final selection = controller.selection;
          return selection.copyWith(
            baseOffset:
                selection.baseOffset.clampInt(range.start - 1, range.end + 1),
            extentOffset:
                selection.extentOffset.clampInt(range.start - 1, range.end + 1),
          );
        },
        // Selector translates global cursor position to local caret index
        // Will only update Line when selection range actually changes
        child: Selector2<TextSelection, Tuple2<LayerLink, LayerLink>,
            Tuple3<TextSelection, LayerLink?, LayerLink?>>(
          selector: (context, selection, handleLayerLinks) {
            final start = selection.start - this.pos;
            final end = selection.end - this.pos;

            final caretStart = caretPositions.slotFor(start).ceil();
            final caretEnd = caretPositions.slotFor(end).floor();

            final caretSelection = caretStart <= caretEnd
                ? selection.baseOffset <= selection.extentOffset
                    ? TextSelection(
                        baseOffset: caretStart, extentOffset: caretEnd)
                    : TextSelection(
                        baseOffset: caretEnd, extentOffset: caretStart)
                : const TextSelection.collapsed(offset: -1);

            final startHandleLayerLink =
                caretPositions.contains(start) ? handleLayerLinks.item1 : null;
            final endHandleLayerLink =
                caretPositions.contains(end) ? handleLayerLinks.item2 : null;
            return Tuple3(
              caretSelection,
              startHandleLayerLink,
              endHandleLayerLink,
            );
          },
          builder: (context, conf, _) {
            final value = Provider.of<SelectionStyle>(context);
            return EditableLine(
              key: _key,
              children: lineChildren,
              devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
              node: this,
              preferredLineHeight: options.fontSize,
              cursorBlinkOpacityController:
                  Provider.of<Wrapper<AnimationController>>(context).value,
              selection: conf.item1,
              startHandleLayerLink: conf.item2,
              endHandleLayerLink: conf.item3,
              cursorColor: value.cursorColor,
              cursorOffset: value.cursorOffset,
              cursorRadius: value.cursorRadius,
              cursorWidth: value.cursorWidth,
              cursorHeight: value.cursorHeight,
              hintingColor: value.hintingColor,
              paintCursorAboveText: value.paintCursorAboveText,
              selectionColor: value.selectionColor,
              showCursor: value.showCursor,
            );
          },
        ),
      );
    });

    return BuildResult(
      options: options,
      italic: flattenedBuildResults.lastOrNull?.italic ?? 0.0,
      skew: flattenedBuildResults.length == 1
          ? flattenedBuildResults.first.italic
          : 0.0,
      widget: widget,
    );
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      List.filled(children.length, options, growable: false);

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  EquationRowNode updateChildren(List<GreenNode> newChildren) =>
      copyWith(children: newChildren);

  @override
  AtomType get leftType => overrideType ?? AtomType.ord;

  @override
  AtomType get rightType => overrideType ?? AtomType.ord;

  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'children': children.map((child) => child.toJson()).toList(),
      if (overrideType != null) 'overrideType': overrideType,
    });

  /// Utility method.
  EquationRowNode copyWith({
    AtomType? overrideType,
    List<GreenNode>? children,
  }) =>
      EquationRowNode(
        overrideType: overrideType ?? this.overrideType,
        children: children ?? this.children,
      );
}

mixin _ClipChildrenMixin on ParentableNode<GreenNode> {
  ParentableNode<GreenNode> clipChildrenBetween(int pos1, int pos2) {
    final childIndex1 = childPositions.slotFor(pos1);
    final childIndex2 = childPositions.slotFor(pos2);
    final childIndex1Floor = childIndex1.floor();
    final childIndex1Ceil = childIndex1.ceil();
    final childIndex2Floor = childIndex2.floor();
    final childIndex2Ceil = childIndex2.ceil();
    GreenNode? head;
    GreenNode? tail;
    if (childIndex1Floor != childIndex1 &&
        childIndex1Floor >= 0 &&
        childIndex1Floor <= children.length - 1) {
      final child = children[childIndex1Floor];
      if (child is TransparentNode) {
        head = child.clipChildrenBetween(
            pos1 - childPositions[childIndex1Floor],
            pos2 - childPositions[childIndex1Floor]);
      } else {
        head = child;
      }
    }
    if (childIndex2Ceil != childIndex2 &&
        childIndex2Floor >= 0 &&
        childIndex2Floor <= children.length - 1) {
      final child = children[childIndex2Floor];
      if (child is TransparentNode) {
        tail = child.clipChildrenBetween(
            pos1 - childPositions[childIndex2Floor],
            pos2 - childPositions[childIndex2Floor]);
      } else {
        tail = child;
      }
    }
    return this.updateChildren(<GreenNode>[
      if (head != null) head,
      for (var i = childIndex1Ceil; i < childIndex2Floor; i++) children[i],
      if (tail != null) tail,
    ]);
  }
}

extension GreenNodeWrappingExt on GreenNode {
  /// Wrap a node in [EquationRowNode]
  ///
  /// If this node is already [EquationRowNode], then it won't be wrapped
  EquationRowNode wrapWithEquationRow() {
    if (this is EquationRowNode) {
      return this as EquationRowNode;
    }
    return EquationRowNode(children: [this]);
  }

  /// If this node is [EquationRowNode], its children will be returned. If not,
  /// itself will be returned in a list.
  List<GreenNode> expandEquationRow() {
    if (this is EquationRowNode) {
      return (this as EquationRowNode).children;
    }
    return [this];
  }

  /// Return the only child of [EquationRowNode]
  ///
  /// If the [EquationRowNode] has more than one child, an error will be thrown.
  GreenNode unwrapEquationRow() {
    if (this is EquationRowNode) {
      if (this.children.length == 1) {
        return (this as EquationRowNode).children[0];
      }
      throw ArgumentError(
          'Unwrap equation row failed due to multiple children inside');
    }
    return this;
  }
}

extension GreenNodeListWrappingExt on List<GreenNode> {
  /// Wrap list of [GreenNode] in an [EquationRowNode]
  ///
  /// If the list only contain one [EquationRowNode], then this note will be
  /// returned.
  EquationRowNode wrapWithEquationRow() {
    if (this.length == 1 && this[0] is EquationRowNode) {
      return this[0] as EquationRowNode;
    }
    return EquationRowNode(children: this);
  }
}

/// [GreenNode] that doesn't have any children
abstract class LeafNode extends GreenNode {
  /// [Mode] that this node acquires during parse.
  Mode get mode;

  @override
  List<GreenNode> get children => const [];

  @override
  LeafNode updateChildren(List<GreenNode> newChildren) {
    assert(newChildren.isEmpty);
    return this;
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) => const [];

  @override
  List<int> get childPositions => const [];

  @override
  int get editingWidth => 1;
}

/// Type of atoms. See TeXBook Chap.17
///
/// These following types will be determined by their repective [GreenNode] type
/// - over
/// - under
/// - acc
/// - rad
/// - vcent
enum AtomType {
  ord,
  op,
  bin,
  rel,
  open,
  close,
  punct,
  inner,

  spacing, // symbols

}

/// Only for improvisional use during parsing. Do not use.
class TemporaryNode extends LeafNode {
  @override
  Mode get mode => Mode.math;

  @override
  BuildResult buildWidget(
          MathOptions options, List<BuildResult?> childBuildResults) =>
      throw UnsupportedError('Temporary node $runtimeType encountered.');

  @override
  AtomType get leftType =>
      throw UnsupportedError('Temporary node $runtimeType encountered.');

  @override
  AtomType get rightType =>
      throw UnsupportedError('Temporary node $runtimeType encountered.');

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      throw UnsupportedError('Temporary node $runtimeType encountered.');

  @override
  int get editingWidth =>
      throw UnsupportedError('Temporary node $runtimeType encountered.');
}

class BuildResult {
  final Widget widget;
  final MathOptions options;
  final double italic;
  final double skew;
  final List<BuildResult>? results;
  const BuildResult({
    required this.widget,
    required this.options,
    this.italic = 0.0,
    this.skew = 0.0,
    this.results,
  });
}

void _traverseNonSpaceNodes(
  List<_NodeSpacingConf> childTypeList,
  void Function(_NodeSpacingConf? prev, _NodeSpacingConf? curr) callback,
) {
  _NodeSpacingConf? prev;
  // Tuple2<AtomType, AtomType> curr;
  for (final child in childTypeList) {
    if (child.leftType == AtomType.spacing ||
        child.rightType == AtomType.spacing) {
      continue;
    }
    callback(prev, child);
    prev = child;
  }
  if (prev != null) {
    callback(prev, null);
  }
}

class _NodeSpacingConf {
  AtomType leftType;
  AtomType rightType;
  MathOptions options;
  double spacingAfter;
  _NodeSpacingConf(
    this.leftType,
    this.rightType,
    this.options,
    this.spacingAfter,
  );
}
