import 'package:flutter/material.dart';

class RebuildWidget extends StatefulWidget {
  const RebuildWidget({super.key, required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RebuildWidgetState>()?.restartApp();
  }

  @override
  _RebuildWidgetState createState() => _RebuildWidgetState();
}

class _RebuildWidgetState extends State<RebuildWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}
