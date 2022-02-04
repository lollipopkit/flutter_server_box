import 'package:flutter/material.dart';

class RoundRectCard extends StatelessWidget {
  const RoundRectCard(this.child, {Key? key}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: child,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(17))),
    );
  }
}
