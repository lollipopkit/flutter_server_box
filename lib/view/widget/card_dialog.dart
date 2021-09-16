import 'package:flutter/material.dart';

class CardDialog extends StatelessWidget {
  const CardDialog(
      {Key? key, this.title, this.content, this.actions, this.padding})
      : super(key: key);

  final Widget? content;
  final List<Widget>? actions;
  final Widget? title;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: padding ?? const EdgeInsets.fromLTRB(24, 17, 24, 7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20.0)),
      ),
      title: title,
      content: content,
      actions: actions,
    );
  }
}
