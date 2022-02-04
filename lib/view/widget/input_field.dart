import 'package:flutter/material.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

Widget buildInput(BuildContext context, TextEditingController controller,
    {int maxLines = 20, String? hint}) {
  return RoundRectCard(
    TextField(
      maxLines: maxLines,
      decoration: InputDecoration(
          fillColor: Theme.of(context).cardColor,
          hintText: hint,
          filled: true,
          border: InputBorder.none),
      controller: controller,
    ),
  );
}
