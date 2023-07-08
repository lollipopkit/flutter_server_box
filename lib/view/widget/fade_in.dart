import 'package:flutter/material.dart';

/// 渐隐渐显实现
class FadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const FadeIn({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 477),
  }) : super(key: key);

  @override
  _MyFadeInState createState() => _MyFadeInState();
}

class _MyFadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller.forward();
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}
