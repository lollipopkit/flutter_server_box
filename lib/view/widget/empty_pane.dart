import 'package:flutter/material.dart';

/// The surface beside a rail, with nothing open on it.
///
/// An icon and no words. The rail next to it is a list of things to open, which
/// is the whole instruction; a sentence saying so would be telling the reader
/// what they are already looking at. It is faint because it marks an empty
/// place rather than occupying one.
class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Opaque, because in the snippet pane this is a route's page rather than
    // something drawn inside one: closing the editor pushes it over the editor,
    // and with nothing painted behind the icon the page being left showed
    // through for the length of the transition and then vanished at the end of
    // it. Elsewhere it sits in a scaffold's body and paints the colour that is
    // already there.
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: EmptyMark(icon: icon),
    );
  }
}

/// The same mark, in a box that is not the whole surface.
///
/// An empty directory has a row above it to leave by, so it cannot be a pane —
/// but it is the same nothing and says so the same way. Sharing the widget is
/// what keeps the two from drifting apart in size or in how faint they are.
class EmptyMark extends StatelessWidget {
  const EmptyMark({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        icon,
        size: 56,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
