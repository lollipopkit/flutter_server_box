import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

final class AutoHideFab extends StatefulWidget {
  final Widget child;
  final ScrollController controller;

  const AutoHideFab({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<AutoHideFab> createState() => _AutoHideFabState();
}

final class _AutoHideFabState extends State<AutoHideFab> {
  bool _visible = true;
  bool _isScrolling = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrollListener);
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _setupTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isScrolling) return;
      if (!_visible) return;
      if (widget.controller.position.maxScrollExtent <= 0) return;
      setState(() {
        _visible = false;
      });
    });
  }

  void _scrollListener() {
    if (_isScrolling) return;
    _isScrolling = true;
    if (widget.controller.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_visible) {
        setState(() {
          _visible = false;
        });
        _timer?.cancel();
        _timer = null;
      }
    } else {
      if (!_visible) {
        setState(() {
          _visible = true;
        });
        _setupTimer();
      }
    }
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Durations.medium1,
      curve: Curves.easeInOutCubic,
      transform: Matrix4.translationValues(_visible ? 0.0 : 55, 0.0, 0.0),
      child: widget.child,
    );
  }
}
