import 'package:flutter/material.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

Widget buildInput(
  BuildContext context,
  TextEditingController controller, {
  int maxLines = 20,
  String? hint,
  Function(String)? onSubmitted,
  bool obscureText = false,
  IconData? icon,
}) {
  return RoundRectCard(
    TextField(
      maxLines: maxLines,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        icon: icon != null ? Icon(icon) : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7)
      ),
      controller: controller,
      obscureText: obscureText,
    ),
  );
}
