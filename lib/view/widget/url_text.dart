import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/data/res/color.dart';

import '../../core/utils/ui.dart';

final _reg = RegExp(
    r"(https?|ftp|file)://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]*");

const _textStyle = TextStyle();

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
    this.style = _textStyle,
  }) : super(key: key);

  List<InlineSpan> getTextSpans(Color c) {
    final widgets = <InlineSpan>[];
    Iterable<Match> matches = _reg.allMatches(text);
    List<_ResultMatch> resultMatches = <_ResultMatch>[];
    int start = 0;

    for (Match match in matches) {
      final group0 = match.group(0);
      if (group0 != null && group0.isNotEmpty) {
        if (start != match.start) {
          _ResultMatch result1 = _ResultMatch(
            false,
            text.substring(start, match.start),
          );
          resultMatches.add(result1);
        }

        _ResultMatch result2 = _ResultMatch(
          true,
          match.group(0)!,
        );
        resultMatches.add(result2);
        start = match.end;
      }
    }

    if (start < text.length) {
      _ResultMatch result1 = _ResultMatch(
        false,
        text.substring(start),
      );
      resultMatches.add(result1);
    }

    for (var result in resultMatches) {
      if (result.isUrl) {
        widgets.add(
          _LinkTextSpan(
            replace: replace ?? result.text,
            text: result.text,
            style: style.copyWith(color: primaryColor),
          ),
        );
      } else {
        widgets.add(
          TextSpan(
            text: result.text,
            style: style.copyWith(
              color: c,
            ),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(children: getTextSpans(contentColor.resolve(context))),
    );
  }
}

class _LinkTextSpan extends TextSpan {
  _LinkTextSpan({TextStyle? style, required String text, String? replace})
      : super(
          style: style,
          text: replace,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              openUrl(text);
            },
        );
}

class _ResultMatch {
  final bool isUrl;
  final String text;

  _ResultMatch(this.isUrl, this.text);
}
