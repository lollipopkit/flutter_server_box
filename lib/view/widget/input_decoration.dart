import 'package:flutter/material.dart';

import '../../data/res/color.dart';

InputDecoration buildDecoration(String label,
    {TextStyle? textStyle, IconData? icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    labelStyle: textStyle,
    hintText: hint,
    icon: Icon(
      icon,
      color: primaryColor,
    ),
  );
}
