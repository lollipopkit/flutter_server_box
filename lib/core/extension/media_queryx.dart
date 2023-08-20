import 'package:flutter/widgets.dart';

extension MideaQueryX on MediaQueryData {
  bool get useDoubleColumn => size.width > 639;
}
