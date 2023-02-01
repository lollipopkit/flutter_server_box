import 'package:flutter/material.dart';

import '../../data/res/menu.dart';
import '../../generated/l10n.dart';

class DropdownBtnItem {
  final String text;
  final IconData icon;

  const DropdownBtnItem({
    required this.text,
    required this.icon,
  });

  Widget build(S s) => Row(
        children: [
          Icon(icon),
          const SizedBox(
            width: 10,
          ),
          Text(
            getDropdownBtnText(s, text),
          ),
        ],
      );
}
