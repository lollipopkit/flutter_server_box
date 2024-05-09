import 'package:flutter/material.dart';
import 'package:toolbox/data/res/ui.dart';

final class IconTextBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  final Orientation orientation;

  const IconTextBtn({
    super.key,
    required this.text,
    required this.icon,
    this.onPressed,
    this.orientation = Orientation.portrait,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: text,
      icon: orientation == Orientation.landscape ? Row(
        children: [
          Icon(icon),
          UIs.width7,
          Text(text, style: UIs.text13Grey),
        ],
      ) : Column(
        children: [
          Icon(icon),
          UIs.height7,
          Text(text, style: UIs.text13Grey),
        ],
      )
    );
  }
}
