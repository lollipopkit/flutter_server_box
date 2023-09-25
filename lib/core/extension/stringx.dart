import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

extension StringX on String {
  /// Format: `#8b2252` or `8b2252`
  Color? get hexToColor {
    final hexCode = replaceAll('#', '');
    final val = int.tryParse('FF$hexCode', radix: 16);
    if (val == null) {
      return null;
    }
    return Color(val);
  }

  Uint8List get uint8List => Uint8List.fromList(utf8.encode(this));
}
