import 'dart:ui';

import 'package:flutter/material.dart';

Widget reorderProxyDecorator(Widget child, int _, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (BuildContext context, Widget? child) {
      final animValue = Curves.easeInOut.transform(animation.value);
      final elevation = lerpDouble(1, 6, animValue)!;
      final scale = lerpDouble(1, 1.02, animValue)!;
      return Transform.scale(
        scale: scale,
        child: Card(elevation: elevation, child: child),
      );
    },
    child: child,
  );
}
