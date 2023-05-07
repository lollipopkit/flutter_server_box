import 'package:flutter/material.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

Widget buildInput({
  TextEditingController? controller,
  int maxLines = 1,
  int? minLines,
  String? hint,
  String? label,
  Function(String)? onSubmitted,
  bool obscureText = false,
  IconData? icon,
  TextInputType? type,
  FocusNode? node,
  bool autoCorrect = true,
}) {
  return RoundRectCard(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: TextField(
        maxLines: maxLines,
        minLines: minLines,
        onSubmitted: onSubmitted,
        keyboardType: type,
        focusNode: node,
        autocorrect: autoCorrect,
        decoration: InputDecoration(
          label: label != null ? Text(label) : null,
          hintText: hint,
          icon: icon != null ? Icon(icon) : null,
          border: InputBorder.none,
        ),
        controller: controller,
        obscureText: obscureText,
      ),
    ),
  );
}
