import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/data/res/color.dart';

import '../../core/utils/ui.dart';

final _reg = RegExp(
    r"(https?|ftp|file)://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]*");

class UrlText extends StatelessWidget {
  final String text;
  final String? replace;
  final TextAlign? textAlign;
  final TextStyle style;

  const UrlText({
    Key? key,
    required this.text,
    this.replace,
    this.textAlign,
    this.style = const TextStyle(),
  }) : super(key: key);

  List<InlineSpan> _buildTextSpans(Color c) {
    final widgets = <InlineSpan>[];
    int start = 0;

    for (final match in _reg.allMatches(text)) {
      final group0 = match.group(0);
      if (group0 != null && group0.isNotEmpty) {
        if (start != match.start) {
          widgets.add(
            TextSpan(
              text: text.substring(start, match.start),
              style: style.copyWith(color: c),
            ),
          );
        }

        widgets.add(_LinkTextSpan(
          replace: replace,
          text: group0,
          style: style.copyWith(color: primaryColor),
        ));
        start = match.end;
      }
    }

    if (start < text.length) {
      widgets.add(
        TextSpan(
          text: text.substring(start),
          style: style.copyWith(color: c),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(
        children: _buildTextSpans(DynamicColors.content.resolve(context)),
      ),
    );
  }
}

class _LinkTextSpan extends TextSpan {
  _LinkTextSpan({TextStyle? style, required String text, String? replace})
      : super(
          style: style,
          text: replace ?? text,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              openUrl(text);
            },
        );
}
