import 'package:flutter/material.dart';

import 'round_rect_card.dart';

class Input extends StatelessWidget {
  final TextEditingController? controller;
  final int maxLines;
  final int? minLines;
  final String? hint;
  final String? label;
  final Function(String)? onSubmitted;
  final bool obscureText;
  final IconData? icon;
  final TextInputType? type;
  final FocusNode? node;
  final bool autoCorrect;
  final bool suggestiion;

  const Input({
    super.key,
    this.controller,
    this.maxLines = 1,
    this.minLines,
    this.hint,
    this.label,
    this.onSubmitted,
    this.obscureText = false,
    this.icon,
    this.type,
    this.node,
    this.autoCorrect = false,
    this.suggestiion = false,
  });
  @override
  Widget build(BuildContext context) {
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
          enableSuggestions: suggestiion,
          decoration: InputDecoration(
            label: label != null ? Text(label!) : null,
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
}
