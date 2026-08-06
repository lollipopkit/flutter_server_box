import 'dart:async';

import 'package:flutter/material.dart';

import '../controller.dart';
import 'selection_manager.dart';

/// Helper class that keeps state relevant to the editing cursor.
mixin CursorTimerManagerMixin<T extends StatefulWidget>
    on SelectionManagerMixin<T> implements TickerProvider {
  static const _kCursorBlinkHalfPeriod = Duration(milliseconds: 500);

  static const _fadeDuration = Duration(milliseconds: 250);

  static const _kCursorBlinkWaitForStart = Duration(milliseconds: 150);

  bool get showCursor;

  bool get cursorOpacityAnimates;

  bool get hasFocus;

  FocusNode get focusNode;

  Timer? _cursorTimer;
  // final ValueNotifier<bool> _showCursor = ValueNotifier<bool>(false);

  late AnimationController cursorBlinkOpacityController;

  bool _targetCursorVisibility = false;

  late MathController _oldController;

  late FocusNode _oldFocusNode;

  @override
  void initState() {
    cursorBlinkOpacityController =
        AnimationController(vsync: this, duration: _fadeDuration);
    super.initState();
    _oldController = controller
      ..addListener(_startOrStopOrResetCursorTimerIfNeeded);

    _oldFocusNode = focusNode
      ..addListener(_startOrStopOrResetCursorTimerIfNeeded);
  }

  @override
  void didUpdateWidget(covariant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller != _oldController) {
      _oldController.removeListener(_startOrStopOrResetCursorTimerIfNeeded);
      _oldController = controller
        ..addListener(_startOrStopOrResetCursorTimerIfNeeded);
    }
    if (focusNode != _oldFocusNode) {
      _oldFocusNode.removeListener(_startOrStopOrResetCursorTimerIfNeeded);
      _oldFocusNode = focusNode
        ..addListener(_startOrStopOrResetCursorTimerIfNeeded);
    }
    _startOrStopOrResetCursorTimerIfNeeded();
  }

  @override
  void dispose() {
    _stopCursorTimer();
    _oldController.removeListener(_startOrStopOrResetCursorTimerIfNeeded);
    _oldFocusNode.removeListener(_startOrStopOrResetCursorTimerIfNeeded);
    super.dispose();
  }

  // ValueNotifier<bool> get value => _showCursor;

  void _cursorTick(Timer timer) {
    _targetCursorVisibility = !_targetCursorVisibility;
    final targetOpacity = _targetCursorVisibility ? 1.0 : 0.0;
    if (cursorOpacityAnimates) {
      // If we want to show the cursor, we will animate the opacity to the value
      // of 1.0, and likewise if we want to make it disappear, to 0.0. An easing
      // curve is used for the animation to mimic the aesthetics of the native
      // iOS cursor.
      //
      // These values and curves have been obtained through eyeballing, so are
      // likely not exactly the same as the values for native iOS.
      cursorBlinkOpacityController.animateTo(targetOpacity,
          curve: Curves.easeOut);
    } else {
      cursorBlinkOpacityController.value = targetOpacity;
    }
  }

  void _cursorWaitForStart(Timer timer) {
    assert(_kCursorBlinkHalfPeriod > _fadeDuration);
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
  }

  void _startCursorTimer() {
    _targetCursorVisibility = true;
    cursorBlinkOpacityController.value = 1.0;
    if (EditableText.debugDeterministicCursor) return;
    if (cursorOpacityAnimates) {
      _cursorTimer =
          Timer.periodic(_kCursorBlinkWaitForStart, _cursorWaitForStart);
    } else {
      _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
    }
  }

  void _stopCursorTimer() {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    _targetCursorVisibility = false;
    cursorBlinkOpacityController.value = 0.0;
    if (EditableText.debugDeterministicCursor) return;
    if (cursorOpacityAnimates) {
      cursorBlinkOpacityController.stop();
      cursorBlinkOpacityController.value = 0.0;
    }
  }

  void _startOrStopOrResetCursorTimerIfNeeded() {
    if (showCursor != true) {
      _stopCursorTimer();
      return;
    }
    if (hasFocus && controller.selection.isCollapsed) {
      if (_cursorTimer == null) {
        _startCursorTimer();
      } else {
        _stopCursorTimer();
        _startCursorTimer();
      }
    } else if (_cursorTimer != null &&
        (!hasFocus || !controller.selection.isCollapsed)) {
      _stopCursorTimer();
    }
  }

  /// Whether the blinking cursor is actually visible at this precise moment
  /// (it's hidden half the time, since it blinks).
  @visibleForTesting
  bool get cursorCurrentlyVisible => cursorBlinkOpacityController.value > 0;

  /// The cursor blink interval (the amount of time the cursor is in the "on"
  /// state or the "off" state). A complete cursor blink period is twice this
  /// value (half on, half off).
  @visibleForTesting
  Duration get cursorBlinkInterval => _kCursorBlinkHalfPeriod;
}
