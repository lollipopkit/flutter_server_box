import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ResetBaseline extends SingleChildRenderObjectWidget {
  final double height;
  const ResetBaseline({
    Key? key,
    required this.height,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  RenderResetBaseline createRenderObject(BuildContext context) =>
      RenderResetBaseline(height: height);

  @override
  void updateRenderObject(
          BuildContext context, RenderResetBaseline renderObject) =>
      renderObject..height = height;
}

class RenderResetBaseline extends RenderProxyBox {
  RenderResetBaseline({required double height, RenderBox? child})
      : _height = height,
        super(child);

  double get height => _height;
  double _height;
  set height(double value) {
    if (_height != value) {
      _height = value;
      markNeedsLayout();
    }
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) => height;
}
