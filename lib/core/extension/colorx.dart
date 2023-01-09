import 'package:flutter/material.dart';

const Set<MaterialState> interactiveStates = <MaterialState>{
  MaterialState.pressed,
  MaterialState.hovered,
  MaterialState.focused,
  MaterialState.selected
};

extension ColorX on Color {
  bool get isBrightColor {
    return getBrightnessFromColor == Brightness.light;
  }

  Brightness get getBrightnessFromColor {
    return ThemeData.estimateBrightnessForColor(this);
  }

  MaterialStateProperty<Color?> get materialStateColor {
    return MaterialStateProperty.resolveWith((states) {
      if (states.any(interactiveStates.contains)) {
        return this;
      }
      return null;
    });
  }
}
