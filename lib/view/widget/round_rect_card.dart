import 'package:flutter/material.dart';

class RoundRectCard extends StatelessWidget {
  const RoundRectCard(this.child, {Key? key}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(17))),
      child: child,
    );
  }
}
