import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../constants.dart';
import '../utils/get_type_of.dart';
import '../utils/render_box_offset.dart';
import '../utils/render_box_layout.dart';

abstract class CustomLayoutDelegate<T> {
  const CustomLayoutDelegate();

  // childrenTable parameter is for a hack to render asynchronously for flutter_svg
  Size computeLayout(
    BoxConstraints constraints,
    Map<T, RenderBox> childrenTable, {
    bool dry,
  });

  double getIntrinsicSize({
    required Axis sizingDirection,
    required bool max,
    required double
        extent, // the extent in the direction that isn't the sizing direction
    required double Function(RenderBox child, double extent)
        childSize, // a method to find the size in the sizing direction);
    required Map<T, RenderBox> childrenTable,
  });

  double? computeDistanceToActualBaseline(
      TextBaseline baseline, Map<T, RenderBox> childrenTable);

  void additionalPaint(PaintingContext context, Offset offset) {}
}

class CustomLayoutParentData<T> extends ContainerBoxParentData<RenderBox> {
  /// An object representing the identity of this child.
  T? id;

  @override
  String toString() => '${super.toString()}; id=$id';
}

class CustomLayoutId<T> extends ParentDataWidget<CustomLayoutParentData<T>> {
  /// Marks a child with a layout identifier.
  ///
  /// Both the child and the id arguments must not be null.
  CustomLayoutId({
    Key? key,
    required this.id,
    required Widget child,
  })  : assert(id != null),
        super(key: key ?? ValueKey<T>(id), child: child);

  final T id;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is CustomLayoutParentData);
    final parentData = renderObject.parentData as CustomLayoutParentData;
    if (parentData.id != id) {
      parentData.id = id;
      final targetParent = renderObject.parent;
      if (targetParent is RenderObject) targetParent.markNeedsLayout();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<T>('id', id));
  }

  @override
  Type get debugTypicalAncestorWidgetClass => getTypeOf<CustomLayout<T>>();
}

class CustomLayout<T> extends MultiChildRenderObjectWidget {
  /// Creates a custom multi-child layout.
  ///
  /// The [delegate] argument must not be null.
  CustomLayout({
    Key? key,
    required this.delegate,
    required List<Widget> children,
  }) : super(key: key, children: children);

  /// The delegate that controls the layout of the children.
  final CustomLayoutDelegate<T> delegate;

  @override
  RenderCustomLayout<T> createRenderObject(BuildContext context) =>
      RenderCustomLayout<T>(delegate: delegate);

  @override
  void updateRenderObject(
      BuildContext context, RenderCustomLayout renderObject) {
    renderObject.delegate = delegate;
  }
}

class RenderCustomLayout<T> extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CustomLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CustomLayoutParentData> {
  RenderCustomLayout({
    List<RenderBox>? children,
    required CustomLayoutDelegate<T> delegate,
  }) : _delegate = delegate {
    addAll(children);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CustomLayoutParentData<T>) {
      child.parentData = CustomLayoutParentData<T>();
    }
  }

  /// The delegate that controls the layout of the children.
  CustomLayoutDelegate<T> get delegate => _delegate;
  CustomLayoutDelegate<T> _delegate;
  set delegate(CustomLayoutDelegate<T> newDelegate) {
    if (_delegate != newDelegate) {
      markNeedsLayout();
    }
    _delegate = newDelegate;
  }

  Map<T, RenderBox> get childrenTable {
    final res = <T, RenderBox>{};
    var child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as CustomLayoutParentData<T>;
      assert(() {
        if (childParentData.id == null) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Every child of a RenderCustomLayout must have an ID '
                'in its parent data.'),
            child!.describeForError('The following child has no ID'),
          ]);
        }
        if (res.containsKey(childParentData.id)) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
                'Every child of a RenderCustomLayout must have a unique ID.'),
            child!.describeForError(
                'The following child has a ID of ${childParentData.id}'),
            res[childParentData.id!]!
                .describeForError('While the following child has the same ID')
          ]);
        }
        return true;
      }());
      res[childParentData.id!] = child;
      child = childParentData.nextSibling;
    }
    return res;
  }

  @override
  double computeMinIntrinsicWidth(double height) => delegate.getIntrinsicSize(
      sizingDirection: Axis.horizontal,
      max: false,
      extent: height,
      childSize: (RenderBox child, double extent) =>
          child.getMinIntrinsicWidth(extent),
      childrenTable: childrenTable);

  @override
  double computeMaxIntrinsicWidth(double height) => delegate.getIntrinsicSize(
      sizingDirection: Axis.horizontal,
      max: true,
      extent: height,
      childSize: (RenderBox child, double extent) =>
          child.getMaxIntrinsicWidth(extent),
      childrenTable: childrenTable);

  @override
  double computeMinIntrinsicHeight(double width) => delegate.getIntrinsicSize(
      sizingDirection: Axis.vertical,
      max: false,
      extent: width,
      childSize: (RenderBox child, double extent) =>
          child.getMinIntrinsicHeight(extent),
      childrenTable: childrenTable);

  @override
  double computeMaxIntrinsicHeight(double width) => delegate.getIntrinsicSize(
      sizingDirection: Axis.vertical,
      max: true,
      extent: width,
      childSize: (RenderBox child, double extent) =>
          child.getMaxIntrinsicHeight(extent),
      childrenTable: childrenTable);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      delegate.computeDistanceToActualBaseline(baseline, childrenTable);

  @override
  void performLayout() {
    this.size = _computeLayout(constraints, dry: false);
  }

  Size computeDryLayout(BoxConstraints constraints) =>
      _computeLayout(constraints);

  Size _computeLayout(BoxConstraints constraints, {bool dry = true}) =>
      constraints.constrain(
        delegate.computeLayout(constraints, childrenTable, dry: dry),
      );

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    delegate.additionalPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class AxisConfiguration<T> {
  final double size;
  final Map<T, double> offsetTable;

  AxisConfiguration({
    required this.size,
    required this.offsetTable,
  });
}

abstract class IntrinsicLayoutDelegate<T> extends CustomLayoutDelegate<T> {
  const IntrinsicLayoutDelegate();

  AxisConfiguration<T> performHorizontalIntrinsicLayout({
    required Map<T, double> childrenWidths,
    bool isComputingIntrinsics = false,
  });

  AxisConfiguration<T> performVerticalIntrinsicLayout({
    required Map<T, double> childrenHeights,
    required Map<T, double> childrenBaselines,
    bool isComputingIntrinsics = false,
  });

  @override
  double getIntrinsicSize({
    required Axis sizingDirection,
    required bool max,
    required double extent,
    required double Function(RenderBox child, double extent) childSize,
    required Map<T, RenderBox> childrenTable,
  }) {
    if (sizingDirection == Axis.horizontal) {
      return performHorizontalIntrinsicLayout(
        childrenWidths: childrenTable.map(
            (key, value) => MapEntry(key, childSize(value, double.infinity))),
        isComputingIntrinsics: true,
      ).size;
    } else {
      final childrenHeights = childrenTable.map(
          (key, value) => MapEntry(key, childSize(value, double.infinity)));
      return performVerticalIntrinsicLayout(
        childrenHeights: childrenHeights,
        childrenBaselines: childrenHeights,
        isComputingIntrinsics: true,
      ).size;
    }
  }

  @override
  Size computeLayout(
    BoxConstraints constraints,
    Map<T, RenderBox> childrenTable, {
    bool dry = true,
  }) {
    final sizeMap = <T, Size>{};
    for (final childEntry in childrenTable.entries) {
      sizeMap[childEntry.key] =
          childEntry.value.getLayoutSize(infiniteConstraint, dry: dry);
    }

    final hconf = performHorizontalIntrinsicLayout(
        childrenWidths:
            sizeMap.map((key, value) => MapEntry(key, value.width)));
    final vconf = performVerticalIntrinsicLayout(
      childrenHeights: sizeMap.map((key, value) => MapEntry(key, value.height)),
      childrenBaselines: childrenTable.map((key, value) => MapEntry(
            key,
            dry
                ? 0
                : value.getDistanceToBaseline(TextBaseline.alphabetic,
                    onlyReal: true)!,
          )),
    );

    if (!dry) {
      childrenTable.forEach((id, child) => child.offset =
          Offset(hconf.offsetTable[id]!, vconf.offsetTable[id]!));
    }

    return Size(hconf.size, vconf.size);
  }
}
