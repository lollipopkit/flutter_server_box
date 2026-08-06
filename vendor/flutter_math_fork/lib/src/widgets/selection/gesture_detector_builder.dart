import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'overlay_manager.dart';

abstract class MathSelectionGestureDetectorBuilderDelegate {
  bool get forcePressEnabled;

  bool get selectionEnabled;
}

class MathSelectionGestureDetectorBuilder {
  MathSelectionGestureDetectorBuilder({
    required this.delegate,
  });
  final SelectionOverlayManagerMixin delegate;

  /// Whether to show the selection toolbar.
  ///
  /// It is based on the signal source when a [onTapDown] is called. This getter
  /// will return true if current [onTapDown] event is triggered by a touch or
  /// a stylus.
  bool get shouldShowSelectionToolbar => _shouldShowSelectionToolbar;
  bool _shouldShowSelectionToolbar = true;

  @protected
  Offset? lastTapDownPosition;

  /// Handler for [TextSelectionGestureDetector.onTapDown].
  @protected
  void onTapDown(TapDragDownDetails details) {
    lastTapDownPosition = details.globalPosition;
    // The selection overlay should only be shown when the user is interacting
    // through a touch screen (via either a finger or a stylus). A mouse
    // shouldn't trigger the selection overlay.
    // For backwards-compatibility, we treat a null kind the same as touch.
    final kind = details.kind;
    _shouldShowSelectionToolbar = kind == null ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus;
  }

  /// Handler for [TextSelectionGestureDetector.onForcePressStart].
  ///
  /// By default, it selects the word at the position of the force press,
  /// if selection is enabled.
  ///
  /// This callback is only applicable when force press is enabled.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onForcePressStart], which triggers this
  ///    callback.
  @protected
  void onForcePressStart(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    _shouldShowSelectionToolbar = true;
    if (delegate.selectionEnabled) {
      delegate.selectWordAt(
        offset: details.globalPosition,
        cause: SelectionChangedCause.forcePress,
      );
    }
  }

  /// Handler for [TextSelectionGestureDetector.onForcePressEnd].
  ///
  /// By default, it selects words in the range specified in [details] and shows
  /// toolbar if it is necessary.
  ///
  /// This callback is only applicable when force press is enabled.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onForcePressEnd], which triggers this
  ///    callback.
  @protected
  void onForcePressEnd(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    delegate.selectWordAt(
      offset: details.globalPosition,
      cause: SelectionChangedCause.forcePress,
    );
    if (shouldShowSelectionToolbar) {
      delegate.showToolbar();
    }
  }

  /// Handler for [TextSelectionGestureDetector.onSingleTapUp].
  ///
  /// By default, it selects word edge if selection is enabled.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onSingleTapUp], which triggers
  ///    this callback.
  @protected
  void onSingleTapUp(TapDragUpDetails details) {
    if (delegate.selectionEnabled) {
      delegate.selectPositionAt(
          from: lastTapDownPosition!, cause: SelectionChangedCause.tap);
      // Should select word edge, but not supporting it now
      // renderEditable.selectWordEdge(cause: SelectionChangedCause.tap);
    }
  }

  /// Handler for [TextSelectionGestureDetector.onSingleTapCancel].
  ///
  /// By default, it services as place holder to enable subclass override.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onSingleTapCancel], which triggers
  ///    this callback.
  @protected
  void onSingleTapCancel() {
    /* Subclass should override this method if needed. */
  }

  @protected
  void onSingleLongTapStart(LongPressStartDetails details) {
    if (delegate.selectionEnabled) {
      delegate.selectPositionAt(
        from: details.globalPosition,
        cause: SelectionChangedCause.longPress,
      );
    }
  }

  @protected
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    if (delegate.selectionEnabled) {
      delegate.selectPositionAt(
        from: details.globalPosition,
        cause: SelectionChangedCause.longPress,
      );
    }
  }

  @protected
  void onSingleLongTapEnd(LongPressEndDetails details) {
    if (shouldShowSelectionToolbar) {
      delegate.showToolbar();
    }
  }

  @protected
  void onDoubleTapDown(TapDragDownDetails details) {
    if (delegate.selectionEnabled) {
      delegate.selectWordAt(
          offset: details.globalPosition, cause: SelectionChangedCause.tap);
      if (shouldShowSelectionToolbar) delegate.showToolbar();
    }
  }

  @protected
  void onDragSelectionStart(TapDragStartDetails details) {
    delegate.selectPositionAt(
      from: details.globalPosition,
      cause: SelectionChangedCause.drag,
    );
  }

  @protected
  void onDragSelectionEnd(TapDragEndDetails details) {
    /* Subclass should override this method if needed. */
  }

  @protected
  void onDragSelectionUpdate(TapDragUpdateDetails details) {
    delegate.selectPositionAt(
      from: details.globalPosition - details.offsetFromOrigin,
      to: details.globalPosition,
      cause: SelectionChangedCause.drag,
    );
  }

  TextSelectionGestureDetector buildGestureDetector({
    Key? key,
    HitTestBehavior? behavior,
    required Widget child,
  }) =>
      TextSelectionGestureDetector(
        key: key,
        onTapDown: onTapDown,
        onForcePressStart:
            delegate.forcePressEnabled ? onForcePressStart : null,
        onForcePressEnd: delegate.forcePressEnabled ? onForcePressEnd : null,
        onSingleTapUp: onSingleTapUp,
        onSingleTapCancel: onSingleTapCancel,
        onSingleLongTapStart: onSingleLongTapStart,
        onSingleLongTapMoveUpdate: onSingleLongTapMoveUpdate,
        onSingleLongTapEnd: onSingleLongTapEnd,
        onDoubleTapDown: onDoubleTapDown,
        onDragSelectionStart: onDragSelectionStart,
        onDragSelectionUpdate: onDragSelectionUpdate,
        onDragSelectionEnd: onDragSelectionEnd,
        behavior: behavior,
        child: child,
      );
}
