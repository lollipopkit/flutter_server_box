import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'gesture_detector_builder.dart';
import 'overlay_manager.dart';

class SelectableMathSelectionGestureDetectorBuilder
    extends MathSelectionGestureDetectorBuilder {
  SelectableMathSelectionGestureDetectorBuilder({
    required SelectionOverlayManagerMixin delegate,
  }) : super(delegate: delegate);

  @override
  void onForcePressStart(ForcePressDetails details) {
    super.onForcePressStart(details);
    if (delegate.selectionEnabled && shouldShowSelectionToolbar) {
      delegate.showToolbar();
    }
  }

  @override
  void onForcePressEnd(ForcePressDetails details) {
    // Not required.
  }

  @override
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    if (delegate.selectionEnabled) {
      delegate.handleSelectionChanged(
        delegate.getWordsRangeInRange(
            from: details.globalPosition - details.offsetFromOrigin,
            to: details.globalPosition),
        SelectionChangedCause.longPress,
      );
    }
  }

  @override
  void onSingleTapUp(TapDragUpDetails details) {
    delegate.hide();
    if (delegate.selectionEnabled) {
      switch (Theme.of(delegate.context).platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          delegate.selectPositionAt(
            from: lastTapDownPosition!,
            cause: SelectionChangedCause.tap,
          );
          // Should select word edge here, but not supporting now
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
        case TargetPlatform.ohos:
          delegate.selectPositionAt(
            from: lastTapDownPosition!,
            cause: SelectionChangedCause.tap,
          );
          break;
      }
    }
    // if (_state.widget.onTap != null)
    //   _state.widget.onTap();
  }

  @override
  void onSingleLongTapStart(LongPressStartDetails details) {
    if (delegate.selectionEnabled) {
      delegate.selectWordAt(
        offset: details.globalPosition,
        cause: SelectionChangedCause.longPress,
      );

      Feedback.forLongPress(delegate.context);

      // renderEditable.selectWord(cause: SelectionChangedCause.longPress);
      // Feedback.forLongPress(_state.context);
    }
  }
}
