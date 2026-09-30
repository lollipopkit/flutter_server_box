/// How the Agent shows a command: wherever one is about to be approved.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';

/// How tall a command preview may be, given the height it is shown in.
///
/// A share of the viewport rather than a constant, so a long command does not
/// push the buttons that approve it off a phone screen, and does not waste a
/// desktop window's height either.
double askAiCommandPreviewMaxHeightFor(double viewportHeight) {
  return (viewportHeight * 0.3).clamp(120.0, 240.0);
}

/// Wraps [command] in a fenced code block tagged [language].
///
/// The fence is as long as the command makes it need to be. A backtick is
/// ordinary shell — `` `date` `` substitutes — and a three-tick fence would
/// close inside one, spilling the rest of the command out of the block and
/// through the inline parser.
@visibleForTesting
String fenceAgentCommand(String command, {required String language}) {
  var longestRun = 0;
  var run = 0;
  for (var index = 0; index < command.length; index++) {
    if (command.codeUnitAt(index) == 0x60) {
      run++;
      if (run > longestRun) longestRun = run;
    } else {
      run = 0;
    }
  }
  final fence = '`' * (longestRun >= 3 ? longestRun + 1 : 3);
  return '$fence$language\n$command\n$fence';
}

/// A command, shown where it is about to be approved or declined.
///
/// The height cap is the point of the widget. A text block in a [Column] draws
/// past its constraints rather than clipping, and neither `AlertDialog` nor a
/// card scrolls its content for you — so a long enough command was drawn over
/// the labels of the very buttons that decide it (#1462). Every surface that
/// shows a proposal uses this, because each of them had grown its own answer
/// to the same question and two of them had no answer at all.
///
/// The command is rendered as a fenced code block, which is also what the
/// assistant's own messages go through, so a command reads the same wherever
/// it appears. The block carries no surface of its own: the caller draws one
/// where there is a card, and a dialog has none.
class AgentCommandPreview extends StatefulWidget {
  const AgentCommandPreview({
    super.key,
    required this.text,
    this.language = 'shell',
    this.style,
  });

  final String text;

  /// What the block is tagged as.
  ///
  /// `shell` wherever the text is a command, which is most of them. The two
  /// that are not — a path, and the contents a `write_file` would write — say
  /// so rather than claiming a syntax they do not have.
  final String language;

  /// Null is monospace, which is what a command wants everywhere but the one
  /// tool call that is not a command.
  final TextStyle? style;

  @override
  State<AgentCommandPreview> createState() => _AgentCommandPreviewState();
}

class _AgentCommandPreviewState extends State<AgentCommandPreview> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: askAiCommandPreviewMaxHeightFor(
          MediaQuery.sizeOf(context).height,
        ),
      ),
      child: Scrollbar(
        controller: _controller,
        // The vertical half. A code block scrolls itself sideways rather than
        // wrapping, so a long single-line command is reachable without this
        // one; a command written as a script is not.
        child: SingleChildScrollView(
          controller: _controller,
          child: SimpleMarkdown(
            data: fenceAgentCommand(widget.text, language: widget.language),
            // A command is read to be checked, and checking it includes
            // copying it somewhere else. The default here is not selectable.
            selectable: true,
            // Merged over `MarkdownStyleSheet.fromTheme` by `MarkdownBody`.
            styleSheet: MarkdownStyleSheet(
              code: widget.style ?? const TextStyle(fontFamily: 'monospace'),
              codeblockDecoration: const BoxDecoration(),
              codeblockPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
