import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/motion.dart';

Widget reorderProxyDecorator(Widget child, int _, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (BuildContext context, Widget? child) {
      final animValue = Curves.easeInOut.transform(animation.value);
      final elevation = lerpDouble(1, 6, animValue)!;
      // Lifted by the shadow alone where the device has asked for less
      // movement.
      final scale = context.reduceMotion
          ? 1.0
          : lerpDouble(1, 1.02, animValue)!;
      return Transform.scale(
        scale: scale,
        child: Card(elevation: elevation, child: child),
      );
    },
    child: child,
  );
}
