import 'package:flutter/material.dart';

import '../model/app/dynamic_color.dart';

var primaryColor = const Color(0xff8b2252);

abstract final class DynamicColors {
  static const content = DynamicColor(Colors.black87, Colors.white70);
  static const bg = DynamicColor(Colors.white, Colors.black);
  static const progress = DynamicColor(Colors.black12, Colors.white10);
}
