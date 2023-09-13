import 'package:flutter/material.dart';
import 'package:toolbox/data/res/ui.dart';

class TwoLineText extends StatelessWidget {
  const TwoLineText({Key? key, required this.up, required this.down})
      : super(key: key);
  final String up;
  final String down;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          up,
          style: UIs.textSize15,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          down,
          style: UIs.textSize11,
          overflow: TextOverflow.ellipsis,
        )
      ],
    );
  }
}
