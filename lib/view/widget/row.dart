import 'package:flutter/material.dart';

final class AvgWidthRow extends StatelessWidget {
  final List<Widget> children;
  final double? width;
  final double padding;

  const AvgWidthRow({
    super.key,
    required this.children,
    this.width,
    this.padding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final width =
        ((this.width ?? MediaQuery.of(context).size.width) - padding) /
            children.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: children.map((e) => SizedBox(width: width, child: e)).toList(),
    );
  }
}
