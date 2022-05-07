import 'package:flutter/material.dart';
import 'package:toolbox/data/model/distribution.dart';

extension StringX on String {
  int get i => int.parse(this);

  Distribution get dist {
    final lower = toLowerCase();
    for (var dist in debianDistList) {
      if (lower.contains(dist)) {
        return Distribution.debian;
      }
    }
    for (var dist in rehlDistList) {
      if (lower.contains(dist)) {
        return Distribution.rehl;
      }
    }
    return Distribution.unknown;
  }

  Uri get uri {
    return Uri.parse(this);
  }

  Widget omitStartStr(
      {TextStyle? style, TextOverflow? overflow, int? maxLines}) {
    return LayoutBuilder(builder: (context, size) {
      bool exceeded = false;
      int len = 0;
      for (; !exceeded && len < length; len++) {
        // Build the textspan
        var span = TextSpan(
          text: 'A' * 7 + substring(length - len),
          style: style ?? Theme.of(context).textTheme.bodyText2,
        );

        // Use a textpainter to determine if it will exceed max lines
        var tp = TextPainter(
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
        (exceeded ? '...' : '') + substring(length - len),
        overflow: overflow ?? TextOverflow.fade,
        softWrap: false,
        maxLines: maxLines ?? 1,
        style: style,
      );
    });
  }
}
