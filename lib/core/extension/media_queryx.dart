import 'package:flutter/widgets.dart';

extension MideaQueryX on MediaQueryData {
  bool get isLarge => size.aspectRatio > 0.87 && size.width > 600;
}
