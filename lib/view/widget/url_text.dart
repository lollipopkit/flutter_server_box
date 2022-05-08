import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';

const regUrl =
    r"(https?|ftp|file)://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]*";

class UrlText extends StatelessWidget {
  final String text;
  final String? replace;
  final TextAlign? textAlign;
  final TextStyle style;

  const UrlText(
      {Key? key,
      required this.text,
      this.replace,
      this.textAlign,
      this.style = const TextStyle()})
      : super(key: key);

  List<InlineSpan> _getTextSpans(bool isDarkMode) {
    List<InlineSpan> widgets = <InlineSpan>[];
    final reg = RegExp(regUrl);
    Iterable<Match> _matches = reg.allMatches(text);
    List<_ResultMatch> resultMatches = <_ResultMatch>[];
    int start = 0;

    for (Match match in _matches) {
      final group0 = match.group(0);
      if (group0 != null && group0.isNotEmpty) {
        if (start != match.start) {
          _ResultMatch result1 = _ResultMatch();
          result1.isUrl = false;
          result1.text = text.substring(start, match.start);
          resultMatches.add(result1);
        }

        _ResultMatch result2 = _ResultMatch();
        result2.isUrl = true;
        result2.text = match.group(0)!;
        resultMatches.add(result2);
        start = match.end;
      }
    }

    if (start < text.length) {
      _ResultMatch result1 = _ResultMatch();
      result1.isUrl = false;
      result1.text = text.substring(start);
      resultMatches.add(result1);
    }

    for (var result in resultMatches) {
      if (result.isUrl) {
        widgets.add(_LinkTextSpan(
            replace: replace ?? result.text,
            text: result.text,
            style: style.copyWith(color: Colors.blue)));
      } else {
        widgets.add(TextSpan(
            text: result.text,
            style: style.copyWith(
              color: isDarkMode ? Colors.white : Colors.black,
            )));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(children: _getTextSpans(isDarkMode(context))),
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
              });
}

class _ResultMatch {
  late bool isUrl;
  late String text;
}
