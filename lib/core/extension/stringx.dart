import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

extension StringX on String {
  int get i => int.parse(this);

  Uri get uri {
    return Uri.parse(this);
  }

  Widget omitStartStr({
    TextStyle? style,
    TextOverflow? overflow,
    int? maxLines,
  }) {
    return LayoutBuilder(builder: (context, size) {
      bool exceeded = false;
      int len = 0;
      for (; !exceeded && len < length; len++) {
        // Build the textspan
        var span = TextSpan(
          text: 'A' * 7 + substring(length - len),
          style: style ?? Theme.of(context).textTheme.bodyMedium,
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

  String get withLangExport => 'export LANG=en_US.UTF-8 && $this';

  Uint8List get uint8List => Uint8List.fromList(utf8.encode(this));
}
