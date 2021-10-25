import 'package:flutter/material.dart';

class RoundRectCard extends StatelessWidget {
  const RoundRectCard(this.child, {Key? key}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: child,
      ),
      margin: const EdgeInsets.symmetric(vertical: 7),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(17))),
    );
  }
}
