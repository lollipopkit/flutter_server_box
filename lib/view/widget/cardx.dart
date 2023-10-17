import 'package:flutter/material.dart';

class CardX extends StatelessWidget {
  const CardX(this.child, {Key? key, this.color}) : super(key: key);

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: key,
      clipBehavior: Clip.antiAlias,
      color: color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(17)),
      ),
      child: child,
    );
  }
}
