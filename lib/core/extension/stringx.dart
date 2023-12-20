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

  /// Upper the first letter.
  String get upperFirst {
    if (isEmpty) {
      return this;
    }
    final runes = codeUnits;
    if (runes[0] >= 97 && runes[0] <= 122) {
      final origin = String.fromCharCode(runes[0]);
      final upper = origin.toUpperCase();
      return replaceFirst(origin, upper);
    }
    return this;
  }
}
