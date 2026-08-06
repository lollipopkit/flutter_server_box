import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'overlay.dart';
import 'overlay_manager.dart';

class MathSelectionHandleOverlay extends StatefulWidget {
  MathSelectionHandleOverlay({
    Key? key,
    // required this.ast,
    required this.manager,
    required this.selection,
    required this.position,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.onSelectionHandleChanged,
    this.onSelectionHandleTapped,
    required this.selectionControls,
    this.dragStartBehavior = DragStartBehavior.start,
  }) : super(key: key);

  // final SyntaxTree ast;
  final SelectionOverlayManagerMixin manager;
  final TextSelection selection;
  final MathSelectionHandlePosition position;
  final LayerLink startHandleLayerLink;
  final LayerLink endHandleLayerLink;
  final ValueChanged<TextSelection> onSelectionHandleChanged;
  final VoidCallback? onSelectionHandleTapped;
  final TextSelectionControls selectionControls;
  final DragStartBehavior dragStartBehavior;

  // RenderEditableLine get renderLine =>
  //     ast.greenRoot.key?.currentContext?.findRenderObject()
  //         as RenderEditableLine;

  @override
  _MathSelectionHandleOverlayState createState() =>
      _MathSelectionHandleOverlayState();
}

class _MathSelectionHandleOverlayState extends State<MathSelectionHandleOverlay>
    with SingleTickerProviderStateMixin {
  late Offset _dragPosition;

  late AnimationController _controller;

  Animation<double> get _opacity => _controller.view;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: SelectionOverlay.fadeDuration, vsync: this);

    _controller.forward();
  }

  @override
  void didUpdateWidget(MathSelectionHandleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    final handleSize = widget.selectionControls
        .getHandleSize(widget.manager.preferredLineHeight);
    _dragPosition = details.globalPosition + Offset(0.0, -handleSize.height);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragPosition += details.delta;
    final position = widget.manager.getPositionForOffset(_dragPosition);

    if (widget.selection.isCollapsed) {
      widget
          .onSelectionHandleChanged(TextSelection.collapsed(offset: position));
      return;
    }

    TextSelection newSelection;
    switch (widget.position) {
      case MathSelectionHandlePosition.start:
        newSelection = TextSelection(
          baseOffset: position,
          extentOffset: widget.selection.extentOffset,
        );
        break;
      case MathSelectionHandlePosition.end:
        newSelection = TextSelection(
          baseOffset: widget.selection.baseOffset,
          extentOffset: position,
        );
        break;
    }

    if (newSelection.baseOffset >= newSelection.extentOffset) {
      return;
    } // don't allow order swapping.

    widget.onSelectionHandleChanged(newSelection);
  }

  void _handleTap() {
    if (widget.onSelectionHandleTapped != null) {
      widget.onSelectionHandleTapped!();
    }
  }

  @override
  Widget build(BuildContext context) {
    LayerLink layerLink;
    TextSelectionHandleType type;

    switch (widget.position) {
      case MathSelectionHandlePosition.start:
        layerLink = widget.startHandleLayerLink;
        type = _chooseType(
          TextDirection.ltr, // renderLine.textDirection,
          TextSelectionHandleType.left,
          TextSelectionHandleType.right,
        );
        break;
      case MathSelectionHandlePosition.end:
        // For collapsed selections, we shouldn't be building the [end] handle.
        assert(!widget.selection.isCollapsed);
        layerLink = widget.endHandleLayerLink;
        type = _chooseType(
          TextDirection.ltr, // renderLine.textDirection,
          TextSelectionHandleType.right,
          TextSelectionHandleType.left,
        );
        break;
    }

    final handleAnchor = widget.selectionControls.getHandleAnchor(
      type,
      widget.manager.preferredLineHeight,
    );
    final handleSize = widget.selectionControls.getHandleSize(
      widget.manager.preferredLineHeight,
    );

    final handleRect = Rect.fromLTWH(
      -handleAnchor.dx,
      -handleAnchor.dy,
      handleSize.width,
      handleSize.height,
    );

    // Make sure the GestureDetector is big enough to be easily interactive.
    final interactiveRect = handleRect.expandToInclude(
      Rect.fromCircle(
          center: handleRect.center, radius: kMinInteractiveDimension / 2),
    );
    final padding = RelativeRect.fromLTRB(
      math.max((interactiveRect.width - handleRect.width) / 2, 0),
      math.max((interactiveRect.height - handleRect.height) / 2, 0),
      math.max((interactiveRect.width - handleRect.width) / 2, 0),
      math.max((interactiveRect.height - handleRect.height) / 2, 0),
    );
    Widget child;
    // This is a workaround for the improperly handled breaking change at https://github.com/flutter/flutter/pull/83639#discussion_r653426749.
    if (widget.selectionControls.buildHandle is Widget Function(
        BuildContext context,
        TextSelectionHandleType type,
        double textLineHeight,
        VoidCallback? onTap)) {
      child = (widget.selectionControls.buildHandle)(
        context,
        type,
        widget.manager.preferredLineHeight,
        null,
      );
    } else {
      child = (widget.selectionControls.buildHandle)(
        context,
        type,
        widget.manager.preferredLineHeight,
      );
    }

    return CompositedTransformFollower(
      link: layerLink,
      offset: interactiveRect.topLeft,
      showWhenUnlinked: false,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          alignment: Alignment.topLeft,
          width: interactiveRect.width,
          height: interactiveRect.height,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            dragStartBehavior: widget.dragStartBehavior,
            onPanStart: _handleDragStart,
            onPanUpdate: _handleDragUpdate,
            onTap: _handleTap,
            child: Padding(
              padding: EdgeInsets.only(
                left: padding.left,
                top: padding.top,
                right: padding.right,
                bottom: padding.bottom,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  TextSelectionHandleType _chooseType(
    TextDirection textDirection,
    TextSelectionHandleType ltrType,
    TextSelectionHandleType rtlType,
  ) {
    if (widget.selection.isCollapsed) return TextSelectionHandleType.collapsed;

    switch (textDirection) {
      case TextDirection.ltr:
        return ltrType;
      case TextDirection.rtl:
        return rtlType;
    }
  }
}
