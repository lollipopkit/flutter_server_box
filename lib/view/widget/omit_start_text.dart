import 'package:flutter/material.dart';

class OmitStartText extends StatelessWidget {
  final String text;
  final int? maxLines;
  final TextStyle? style;
  final TextOverflow? overflow;

  const OmitStartText(
    this.text, {
    super.key,
    this.maxLines,
    this.style,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, size) {
      bool exceeded = false;
      int len = 0;
      for (; !exceeded && len < text.length; len++) {
        // Build the textspan
        final span = TextSpan(
          text: 'A' * 7 + text.substring(text.length - len),
          style: style ?? Theme.of(context).textTheme.bodyMedium,
        );

        // Use a textpainter to determine if it will exceed max lines
        final tp = TextPainter(
          maxLines: maxLines ?? 1,
          textDirection: TextDirection.ltr,
          text: span,
        );

        // trigger it to layout
        tp.layout(maxWidth: size.maxWidth);

        // whether the text overflowed or not
        exceeded = tp.didExceedMaxLines;
      }

      return Text(
        (exceeded ? '...' : '') + text.substring(text.length - len),
        overflow: overflow ?? TextOverflow.fade,
        softWrap: false,
        maxLines: maxLines ?? 1,
        style: style,
      );
    });
  }
}
