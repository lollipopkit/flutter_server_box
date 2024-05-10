import 'dart:async';

import 'package:flutter/material.dart';

final class AutoHide extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final AxisDirection direction;
  final double offset;

  const AutoHide({
    super.key,
    required this.child,
    required this.controller,
    required this.direction,
    this.offset = 55,
  });

  @override
  State<AutoHide> createState() => AutoHideState();
}

final class AutoHideState extends State<AutoHide> {
  bool _visible = true;
  bool _isScrolling = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrollListener);
    _setupTimer();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrollListener);
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void show() {
    debugPrint('show');
    if (_visible) return;
    setState(() {
      _visible = true;
    });
    _setupTimer();
  }

  void _setupTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isScrolling) return;
      if (!_visible) return;
      final canScroll =
          widget.controller.positions.any((e) => e.maxScrollExtent >= 0);
      if (!canScroll) return;

      setState(() {
        _visible = false;
      });
      _timer?.cancel();
      _timer = null;
    });
  }

  void _scrollListener() {
    if (_isScrolling) return;
    _isScrolling = true;

    if (!_visible) {
      setState(() {
        _visible = true;
      });
      _setupTimer();
    }

    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Durations.medium1,
      curve: Curves.easeInOutCubic,
      transform: _transform,
      child: widget.child,
    );
  }

  Matrix4? get _transform {
    switch (widget.direction) {
      case AxisDirection.down:
        return _visible
            ? Matrix4.identity()
            : Matrix4.translationValues(0, widget.offset, 0);
      case AxisDirection.up:
        return _visible
            ? Matrix4.identity()
            : Matrix4.translationValues(0, -widget.offset, 0);
      case AxisDirection.left:
        return _visible
            ? Matrix4.identity()
            : Matrix4.translationValues(-widget.offset, 0, 0);
      case AxisDirection.right:
        return _visible
            ? Matrix4.identity()
            : Matrix4.translationValues(widget.offset, 0, 0);
    }
  }
}
