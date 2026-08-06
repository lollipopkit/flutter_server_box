import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'gesture_detector_builder.dart';
import 'gesture_detector_builder_selectable.dart';
import 'overlay.dart';
import 'selection_manager.dart';

mixin SelectionOverlayManagerMixin<T extends StatefulWidget>
    on SelectionManagerMixin<T>
    implements MathSelectionGestureDetectorBuilderDelegate {
  FocusNode get focusNode;

  bool get hasFocus => focusNode.hasFocus;

  double get preferredLineHeight;

  TextSelectionControls get textSelectionControls;

  DragStartBehavior get dragStartBehavior;

  MathSelectionOverlay? get selectionOverlay => _selectionOverlay;
  MathSelectionOverlay? _selectionOverlay;

  final toolbarLayerLink = LayerLink();

  final startHandleLayerLink = LayerLink();

  final endHandleLayerLink = LayerLink();

  bool toolbarVisible = false;

  late SelectableMathSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;
  SelectableMathSelectionGestureDetectorBuilder
      get selectionGestureDetectorBuilder => _selectionGestureDetectorBuilder;

  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder =
        SelectableMathSelectionGestureDetectorBuilder(delegate: this);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectionOverlay?.update();
  }

  @override
  void dispose() {
    _selectionOverlay?.dispose();
    super.dispose();
  }

  /// Shows the selection toolbar at the location of the current cursor.
  ///
  /// Returns `false` if a toolbar couldn't be shown, such as when the toolbar
  /// is already shown, or when no text selection currently exists.
  bool showToolbar() {
    // Web is using native dom elements to enable clipboard functionality of the
    // toolbar: copy, paste, select, cut. It might also provide additional
    // functionality depending on the browser (such as translate). Due to this
    // we should not show a Flutter toolbar for the editable text elements.
    if (kIsWeb) {
      return false;
    }

    if (_selectionOverlay == null || _selectionOverlay!.toolbarIsVisible) {
      return false;
    }

    if (controller.selection.isCollapsed) {
      return false;
    }
    _selectionOverlay!.showToolbar();
    toolbarVisible = true;
    return true;
  }

  @override
  void hideToolbar([bool hideHandles = true]) {
    toolbarVisible = false;
    _selectionOverlay?.hideToolbar();
  }

  void hide() {
    toolbarVisible = false;
    _selectionOverlay?.hide();
  }

  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    // When the text field is activated by something that doesn't trigger the
    // selection overlay, we shouldn't show the handles either.
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar) {
      return false;
    }

    if (controller.selection.isCollapsed) return false;

    if (cause == SelectionChangedCause.keyboard) return false;

    if (cause == SelectionChangedCause.longPress) return true;

    if (controller.ast.greenRoot.capturedCursor > 1) return true;

    return false;
  }

  void handleSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause,
      [ExtraSelectionChangedCause? extraCause]) {
    super.handleSelectionChanged(selection, cause, extraCause);

    if (extraCause != ExtraSelectionChangedCause.handle) {
      _selectionOverlay?.hide();
      _selectionOverlay = null;

      // if (textSelectionControls != null) {
      _selectionOverlay = MathSelectionOverlay(
        clipboardStatus: kIsWeb ? null : ClipboardStatusNotifier(),
        manager: this,
        toolbarLayerLink: toolbarLayerLink,
        startHandleLayerLink: startHandleLayerLink,
        endHandleLayerLink: endHandleLayerLink,
        onSelectionHandleTapped: () {
          if (!controller.selection.isCollapsed) {
            toolbarVisible ? hideToolbar() : showToolbar();
          }
        },
        selectionControls: textSelectionControls,
        dragStartBehavior: dragStartBehavior,
        debugRequiredFor: widget,
      );
      _selectionOverlay!.handlesVisible = _shouldShowSelectionHandles(cause);
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance
            .addPostFrameCallback((_) => _selectionOverlay!.showHandles());
      } else {
        _selectionOverlay!.showHandles();
      }
      // _selectionOverlay.showHandles();
      // }
    } else {
      _selectionOverlay?.update();
    }
  }
}
