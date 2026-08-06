import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../ast/syntax_tree.dart';
import 'handle_overlay.dart';
import 'overlay_manager.dart';
import 'selection_manager.dart';

enum MathSelectionHandlePosition { start, end }

class MathSelectionOverlay {
  MathSelectionOverlay({
    this.debugRequiredFor,
    required this.toolbarLayerLink,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    this.selectionControls,
    bool handlesVisible = false,
    required this.manager,
    this.dragStartBehavior = DragStartBehavior.start,
    this.onSelectionHandleTapped,
    this.clipboardStatus,
  }) : _handlesVisible = handlesVisible {
    final overlay = Overlay.of(context, rootOverlay: true);
    _toolbarController =
        AnimationController(duration: fadeDuration, vsync: overlay);
  }

  /// The context in which the selection handles should appear.
  ///
  /// This context must have an [Overlay] as an ancestor because this object
  /// will display the text selection handles in that [Overlay].
  BuildContext get context => manager.context;

  /// Debugging information for explaining why the [Overlay] is required.
  final Widget? debugRequiredFor;

  /// The object supplied to the [CompositedTransformTarget] that wraps the text
  /// field.
  final LayerLink toolbarLayerLink;

  /// The objects supplied to the [CompositedTransformTarget] that wraps the
  /// location of start selection handle.
  final LayerLink startHandleLayerLink;

  /// The objects supplied to the [CompositedTransformTarget] that wraps the
  /// location of end selection handle.
  final LayerLink endHandleLayerLink;

  /// Builds text selection handles and toolbar.
  final TextSelectionControls? selectionControls;

  /// The delegate for manipulating the current selection in the owning
  /// text field.
  final SelectionOverlayManagerMixin manager;

  /// Determines the way that drag start behavior is handled.
  ///
  /// If set to [DragStartBehavior.start], handle drag behavior will
  /// begin upon the detection of a drag gesture. If set to
  /// [DragStartBehavior.down] it will begin when a down event is first
  /// detected.
  ///
  /// In general, setting this to [DragStartBehavior.start] will make drag
  /// animation smoother and setting it to [DragStartBehavior.down] will make
  /// drag behavior feel slightly more reactive.
  ///
  /// By default, the drag start behavior is [DragStartBehavior.start].
  ///
  /// See also:
  ///
  ///  * [DragGestureRecognizer.dragStartBehavior], which gives an example for
  /// the different behaviors.
  final DragStartBehavior dragStartBehavior;

  /// A callback that's invoked when a selection handle is tapped.
  ///
  /// Both regular taps and long presses invoke this callback, but a drag
  /// gesture won't.
  final VoidCallback? onSelectionHandleTapped;

  /// Maintains the status of the clipboard for determining if its contents can
  /// be pasted or not.
  ///
  /// Useful because the actual value of the clipboard can only be checked
  /// asynchronously (see [Clipboard.getData]).
  final ClipboardStatusNotifier? clipboardStatus;

  /// Controls the fade-in and fade-out animations for the toolbar and handles.
  static const Duration fadeDuration = Duration(milliseconds: 150);

  late AnimationController _toolbarController;
  Animation<double> get _toolbarOpacity => _toolbarController.view;

  /// Retrieve current value.
  @visibleForTesting
  SyntaxTree? get value => _value;
  SyntaxTree? _value;

  /// A pair of handles. If this is non-null, there are always 2, though the
  /// second is hidden when the selection is collapsed.
  List<OverlayEntry>? _handles;

  /// A copy/paste toolbar.
  OverlayEntry? _toolbar;

  TextSelection get _selection => manager.controller.selection;

  /// Whether selection handles are visible.
  ///
  /// Set to false if you want to hide the handles. Use this property to show or
  /// hide the handle without rebuilding them.
  ///
  /// If this method is called while the [SchedulerBinding.schedulerPhase] is
  /// [SchedulerPhase.persistentCallbacks], i.e. during the build, layout, or
  /// paint phases (see [WidgetsBinding.drawFrame]), then the update is delayed
  /// until the post-frame callbacks phase. Otherwise the update is done
  /// synchronously. This means that it is safe to call during builds, but also
  /// that if you do call this during a build, the UI will not update until the
  /// next frame (i.e. many milliseconds later).
  ///
  /// Defaults to false.
  bool get handlesVisible => _handlesVisible;
  bool _handlesVisible;
  set handlesVisible(bool visible) {
    if (_handlesVisible == visible) return;
    _handlesVisible = visible;
    // If we are in build state, it will be too late to update visibility.
    // We will need to schedule the build in next frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(_markNeedsBuild);
    } else {
      _markNeedsBuild();
    }
  }

  /// Builds the handles by inserting them into the [context]'s overlay.
  void showHandles() {
    assert(_handles == null);
    _handles = <OverlayEntry>[
      OverlayEntry(
          builder: (BuildContext context) =>
              _buildHandle(context, MathSelectionHandlePosition.start)),
      OverlayEntry(
          builder: (BuildContext context) =>
              _buildHandle(context, MathSelectionHandlePosition.end)),
    ];

    Overlay.of(context, rootOverlay: true, debugRequiredFor: debugRequiredFor)
        .insertAll(_handles!);
  }

  /// Destroys the handles by removing them from overlay.
  void hideHandles() {
    if (_handles != null) {
      _handles![0].remove();
      _handles![1].remove();
      _handles = null;
    }
  }

  /// Shows the toolbar by inserting it into the [context]'s overlay.
  void showToolbar() {
    assert(_toolbar == null);
    _toolbar = OverlayEntry(builder: _buildToolbar);
    Overlay.of(context, rootOverlay: true, debugRequiredFor: debugRequiredFor)
        .insert(_toolbar!);
    _toolbarController.forward(from: 0.0);
  }

  /// Updates the overlay after the selection has changed.
  ///
  /// If this method is called while the [SchedulerBinding.schedulerPhase] is
  /// [SchedulerPhase.persistentCallbacks], i.e. during the build, layout, or
  /// paint phases (see [WidgetsBinding.drawFrame]), then the update is delayed
  /// until the post-frame callbacks phase. Otherwise the update is done
  /// synchronously. This means that it is safe to call during builds, but also
  /// that if you do call this during a build, the UI will not update until the
  /// next frame (i.e. many milliseconds later).
  void update() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(_markNeedsBuild);
    } else {
      _markNeedsBuild();
    }
  }

  void _markNeedsBuild([Duration? duration]) {
    if (_handles != null) {
      _handles![0].markNeedsBuild();
      _handles![1].markNeedsBuild();
    }
    _toolbar?.markNeedsBuild();
  }

  /// Whether the handles are currently visible.
  bool get handlesAreVisible => _handles != null && handlesVisible;

  /// Whether the toolbar is currently visible.
  bool get toolbarIsVisible => _toolbar != null;

  /// Hides the entire overlay including the toolbar and the handles.
  void hide() {
    if (_handles != null) {
      _handles![0].remove();
      _handles![1].remove();
      _handles = null;
    }
    if (_toolbar != null) {
      hideToolbar();
    }
  }

  /// Hides the toolbar part of the overlay.
  ///
  /// To hide the whole overlay, see [hide].
  void hideToolbar() {
    assert(_toolbar != null);
    _toolbarController.stop();
    _toolbar!.remove();
    _toolbar = null;
  }

  /// Final cleanup.
  void dispose() {
    hide();
    _toolbarController.dispose();
  }

  Widget _buildHandle(
      BuildContext context, MathSelectionHandlePosition position) {
    if ((_selection.isCollapsed &&
            position == MathSelectionHandlePosition.end) ||
        selectionControls == null) {
      return Container();
    } // hide the second handle when collapsed
    return Visibility(
      visible: handlesVisible,
      child: MathSelectionHandleOverlay(
        manager: manager,
        onSelectionHandleChanged: (TextSelection newSelection) {
          _handleSelectionHandleChanged(newSelection, position);
        },
        onSelectionHandleTapped: onSelectionHandleTapped,
        startHandleLayerLink: startHandleLayerLink,
        endHandleLayerLink: endHandleLayerLink,
        selection: _selection,
        selectionControls: selectionControls!,
        position: position,
        dragStartBehavior: dragStartBehavior,
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    if (selectionControls == null) return Container();

    // Find the horizontal midpoint, just above the selected text.
    final endpoint1 = manager.getLocalEndpointForPosition(_selection.start);

    final endpoint2 = manager.getLocalEndpointForPosition(_selection.end);

    final editingRegion = manager.getLocalEditingRegion();

    final isMultiline = false; // TODO
    // endpoints.last.point.dy - endpoints.first.point.dy >
    // manager.preferredLineHeight / 2;

    // If the selected text spans more than 1 line, horizontally center the
    // toolbar.
    // Derived from both iOS and Android.
    final midX = isMultiline
        ? editingRegion.width / 2
        : (endpoint1.dx + endpoint2.dx) / 2;

    final midpoint = Offset(
      midX,
      // The y-coordinate won't be made use of most likely.
      endpoint1.dy - manager.preferredLineHeight,
    );

    return FadeTransition(
      opacity: _toolbarOpacity,
      child: CompositedTransformFollower(
        link: toolbarLayerLink,
        showWhenUnlinked: false,
        offset: -editingRegion.topLeft,
        child: selectionControls!.buildToolbar(
          context,
          editingRegion,
          manager.preferredLineHeight,
          midpoint,
          [
            TextSelectionPoint(endpoint1, TextDirection.ltr),
            TextSelectionPoint(endpoint2, TextDirection.ltr),
          ],
          manager,
          clipboardStatus!,
          null,
        ),
      ),
    );
  }

  void _handleSelectionHandleChanged(
      TextSelection newSelection, MathSelectionHandlePosition position) {
    TextPosition textPosition;
    switch (position) {
      case MathSelectionHandlePosition.start:
        textPosition = newSelection.base;
        break;
      case MathSelectionHandlePosition.end:
        textPosition = newSelection.extent;
        break;
    }
    manager.handleSelectionChanged(
        newSelection, null, ExtraSelectionChangedCause.handle);
    manager.bringIntoView(textPosition);
  }
}
