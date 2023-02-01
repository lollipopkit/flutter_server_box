import 'package:flutter/material.dart';

import 'primary_color.dart';

InputDecoration buildDecoration(String label,
    {TextStyle? textStyle, IconData? icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    labelStyle: textStyle,
    hintText: hint,
    icon: PrimaryColor(builder: (context, primaryColor) {
      return Icon(
        icon,
        color: primaryColor,
      );
    }),
  );
}
