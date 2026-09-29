import 'package:material_ui/material_ui.dart';

/// [text] with a [mark] after it — a `BetaTag` — or [text] alone.
///
/// One line, and the text ellipsises against the mark rather than pushing it
/// out: a long name in a narrow row, or a large text scale, keeps the mark in
/// view, since it is the part that says something.
class MarkedTitle extends StatelessWidget {
  const MarkedTitle(this.text, {super.key, this.mark, this.style});

  final String text;
  final Widget? mark;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    final mark = this.mark;
    if (mark == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Flexible(child: label), const SizedBox(width: 7), mark],
    );
  }
}
