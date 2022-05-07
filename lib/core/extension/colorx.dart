import 'package:flutter/material.dart';

extension ColorX on Color {
  bool get isBrightColor {
    return getBrightnessFromColor == Brightness.light;
  }

  Brightness get getBrightnessFromColor {
    return ThemeData.estimateBrightnessForColor(this);
  }
}
