import 'package:flutter/material.dart';

abstract final class Funcs {
  static const int _defaultDurationTime = 377;
  static const String _defaultThrottleId = 'default';
  static final Map<String, int> startTimeMap = <String, int>{
    _defaultThrottleId: 0
  };

  static void throttle(
    VoidCallback? func, {
    String id = _defaultThrottleId,
    int duration = _defaultDurationTime,
    Function? continueClick,
  }) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - (startTimeMap[id] ?? 0) > duration) {
      func?.call();
      startTimeMap[id] = DateTime.now().millisecondsSinceEpoch;
    } else {
      continueClick?.call();
    }
  }
}
