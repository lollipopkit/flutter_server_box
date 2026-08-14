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
    return Center(
      child: Icon(
        icon,
        size: 56,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
