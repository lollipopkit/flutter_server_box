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
    return LayoutBuilder(
      builder: (context, size) {
        final textStyle = style ?? Theme.of(context).textTheme.bodyMedium;
        const prefix = '...';
        int lo = 0;
        int hi = text.length;
        while (lo < hi) {
          final mid = (lo + hi + 1) ~/ 2;
          final span = TextSpan(
            text: prefix + text.substring(text.length - mid),
            style: textStyle,
          );
          final tp = TextPainter(
            maxLines: maxLines ?? 1,
            textDirection: TextDirection.ltr,
            text: span,
          );
          tp.layout(maxWidth: size.maxWidth);
          final exceeded = tp.didExceedMaxLines;
          tp.dispose();
          if (exceeded) {
            hi = mid - 1;
          } else {
            lo = mid;
          }
        }

        return Text(
          (lo < text.length ? prefix : '') + text.substring(text.length - lo),
          overflow: overflow ?? TextOverflow.fade,
          softWrap: false,
          maxLines: maxLines ?? 1,
          style: style,
        );
      },
    );
  }
}
