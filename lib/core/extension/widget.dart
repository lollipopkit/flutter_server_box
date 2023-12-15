import 'package:flutter/material.dart';
import 'package:toolbox/core/utils/function.dart';

extension WidgetX on Widget {
  Widget padding(EdgeInsetsGeometry padding) {
    return Padding(padding: padding, child: this);
  }

  Widget expanded({int flex = 1}) {
    return Expanded(flex: flex, child: this);
  }

  Widget center() {
    return Center(child: this);
  }

  Widget tap({
    VoidCallback? onTap,
    bool disable = false,
    VoidCallback? onLongTap,
    VoidCallback? onDoubleTap,
  }) {
    if (disable) return this;

    return InkWell(
      onTap: () => Funcs.throttle(onTap),
      onLongPress: onLongTap,
      onDoubleTap: onDoubleTap,
      child: this,
    );
  }
}
