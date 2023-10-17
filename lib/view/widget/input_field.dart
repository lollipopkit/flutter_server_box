import 'package:flutter/material.dart';

import 'cardx.dart';

class Input extends StatelessWidget {
  final TextEditingController? controller;
  final int maxLines;
  final int? minLines;
  final String? hint;
  final String? label;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final bool obscureText;
  final IconData? icon;
  final TextInputType? type;
  final FocusNode? node;
  final bool autoCorrect;
  final bool suggestiion;
  final String? errorText;
  final Widget? prefix;
  final bool autoFocus;

  const Input({
    super.key,
    this.controller,
    this.maxLines = 1,
    this.minLines,
    this.hint,
    this.label,
    this.onSubmitted,
    this.onChanged,
    this.obscureText = false,
    this.icon,
    this.type,
    this.node,
    this.autoCorrect = false,
    this.suggestiion = false,
    this.errorText,
    this.prefix,
    this.autoFocus = false,
  });
  @override
  Widget build(BuildContext context) {
    return CardX(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: TextField(
          maxLines: maxLines,
          minLines: minLines,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          keyboardType: type,
          focusNode: node,
          autofocus: autoFocus,
          autocorrect: autoCorrect,
          enableSuggestions: suggestiion,
          decoration: InputDecoration(
            label: label != null ? Text(label!) : null,
            hintText: hint,
            icon: icon != null ? Icon(icon) : null,
            border: InputBorder.none,
            errorText: errorText,
            prefix: prefix,
          ),
          controller: controller,
          obscureText: obscureText,
        ),
      ),
    );
  }
}
