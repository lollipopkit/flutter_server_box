import 'package:flutter/material.dart';

import 'cardx.dart';

class Input extends StatefulWidget {
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
  final void Function(bool)? onViewPwdTap;

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
    this.onViewPwdTap,
  });

  @override
  State<StatefulWidget> createState() => _InputState();
}

class _InputState extends State<Input> {
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return CardX(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          obscureText: _obscureText,
          decoration: InputDecoration(
            hintText: widget.hint,
            labelText: widget.label,
            errorText: widget.errorText,
            border: InputBorder.none,
            prefixIcon: widget.icon == null ? null : Icon(widget.icon),
            prefix: widget.prefix,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                      if (widget.onViewPwdTap != null) {
                        widget.onViewPwdTap?.call(_obscureText);
                      }
                    },
                  )
                : null,
          ),
          keyboardType: widget.type,
          focusNode: widget.node,
          autocorrect: widget.autoCorrect,
          enableSuggestions: widget.suggestiion,
          autofocus: widget.autoFocus,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
