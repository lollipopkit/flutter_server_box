import 'package:flutter/material.dart';
import 'package:toolbox/data/res/color.dart';

InputDecoration buildDecoration(String label,
    {TextStyle? textStyle, IconData? icon}) {
  return InputDecoration(
      labelText: label,
      labelStyle: textStyle,
      icon: Icon(
        icon,
        color: primaryColor,
      ));
}
