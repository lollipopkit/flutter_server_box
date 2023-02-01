import 'package:flutter/material.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/menu.dart';
import 'package:toolbox/generated/l10n.dart';

class DropdownBtnItem {
  final String text;
  final IconData icon;

  const DropdownBtnItem({
    required this.text,
    required this.icon,
  });

  Widget build(S s) => Row(
        children: [
          PrimaryColor(builder: (context, primaryColor) {
            return Icon(
              icon,
              color: primaryColor,
            );
          }),
          const SizedBox(
            width: 10,
          ),
          Text(
            getDropdownBtnText(s, text),
          ),
        ],
      );
}
