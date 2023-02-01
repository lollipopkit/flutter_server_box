import 'package:flutter/material.dart';

import '../../data/res/menu.dart';
import '../../generated/l10n.dart';
import 'primary_color.dart';

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
