import 'package:flutter/material.dart';

import '../model/app/dynamic_color.dart';

late Color primaryColor;

class DynamicColors {
  const DynamicColors._();

  static const content = DynamicColor(Colors.black87, Colors.white70);
  static const bg = DynamicColor(Colors.white, Colors.black);
  static const progress = DynamicColor(Colors.black12, Colors.white10);
}
