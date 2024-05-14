import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

class TwoLineText extends StatelessWidget {
  const TwoLineText({super.key, required this.up, required this.down});
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
          style: UIs.text15,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          down,
          style: UIs.text11,
          overflow: TextOverflow.ellipsis,
        )
      ],
    );
  }
}
