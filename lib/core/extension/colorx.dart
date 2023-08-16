import 'package:flutter/material.dart';

const _interactiveStates = <MaterialState>{
  MaterialState.pressed,
  MaterialState.hovered,
  MaterialState.focused,
  MaterialState.selected
};

extension ColorX on Color {
  String get toHex {
    final redStr = red.toRadixString(16).padLeft(2, '0');
    final greenStr = green.toRadixString(16).padLeft(2, '0');
    final blueStr = blue.toRadixString(16).padLeft(2, '0');
    return '#$redStr$greenStr$blueStr';
  }

  bool get isBrightColor {
    return getBrightnessFromColor == Brightness.light;
  }

  Brightness get getBrightnessFromColor {
    return ThemeData.estimateBrightnessForColor(this);
  }

  MaterialStateProperty<Color?> get materialStateColor {
    return MaterialStateProperty.resolveWith((states) {
      if (states.any(_interactiveStates.contains)) {
        return this;
      }
      return null;
    });
  }

  MaterialColor get materialColor => MaterialColor(
        value,
        {
          50: withOpacity(0.05),
          100: withOpacity(0.1),
          200: withOpacity(0.2),
          300: withOpacity(0.3),
          400: withOpacity(0.4),
          500: withOpacity(0.5),
          600: withOpacity(0.6),
          700: withOpacity(0.7),
          800: withOpacity(0.8),
          900: withOpacity(0.9),
        },
      );
}
