import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/res/color.dart';

final class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown({
    super.key,
    required this.data,
    this.styleSheet,
  });

  final String data;
  final MarkdownStyleSheet? styleSheet;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      onTapLink: (text, href, title) {
        if (href != null && href.isNotEmpty) {
          openUrl(href);
          return;
        }
        context.showSnackBar(l10n.failed);
      },
      styleSheet: styleSheet?.copyWith(
            a: TextStyle(color: primaryColor),
          ) ??
          MarkdownStyleSheet(
            a: TextStyle(color: primaryColor),
          ),
    );
  }
}
