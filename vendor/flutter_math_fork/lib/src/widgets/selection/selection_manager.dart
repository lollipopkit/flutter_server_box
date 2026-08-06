import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../ast/syntax_tree.dart';
import '../../encoder/tex/encoder.dart';
import '../../render/layout/line_editable.dart';
import '../../utils/render_box_extensions.dart';
import '../controller.dart';

enum ExtraSelectionChangedCause {
  // Selection handle dragged,
  handle,

  // Unfocused
  unfocus,

  // Changed by other code directly manipulating controller.
  exterior,
}

mixin SelectionManagerMixin<T extends StatefulWidget> on State<T>
    implements TextSelectionDelegate {
  MathController get controller;

  FocusNode get focusNode;

  bool get hasFocus;

  late FocusNode _oldFocusNode;

  late MathController _oldController;

  @override
  void initState() {
    super.initState();
    _oldFocusNode = focusNode..addListener(_handleFocusChange);
    _oldController = controller..addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (focusNode != _oldFocusNode) {
      _oldFocusNode.removeListener(_handleFocusChange);
      _oldFocusNode = focusNode..addListener(_handleFocusChange);
      _handleFocusChange();
    }
    if (controller != _oldController) {
      _oldController.removeListener(_onControllerChanged);
      _oldController = controller..addListener(_onControllerChanged);
      _onControllerChanged();
    }
  }

  @override
  void dispose() {
    _oldController.removeListener(_onControllerChanged);
    _oldFocusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!hasFocus) {
      handleSelectionChanged(TextSelection.collapsed(offset: -1), null,
          ExtraSelectionChangedCause.unfocus);
    }
  }

  SyntaxTree? _oldAst;
  TextSelection? _oldSelection;
  void _onControllerChanged() {
    if (_oldAst != controller.ast || _oldSelection != controller.selection) {
      handleSelectionChanged(
          controller.selection, null, ExtraSelectionChangedCause.exterior);
    }
  }

  void onSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause);

  @mustCallSuper
  void handleSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause,
      [ExtraSelectionChangedCause? extraCause]) {
    if (extraCause != ExtraSelectionChangedCause.unfocus &&
        extraCause != ExtraSelectionChangedCause.exterior &&
        !hasFocus) {
      focusNode.requestFocus();
    }
    _oldAst = controller.ast;
    _oldSelection = selection;
    controller.selection = selection;
    onSelectionChanged(selection, cause);
  }

  void selectPositionAt({
    required Offset from,
    Offset? to,
    required SelectionChangedCause cause,
  }) {
    final fromPosition = getPositionForOffset(from);
    final toPosition = to == null ? fromPosition : getPositionForOffset(to);
    handleSelectionChanged(
      TextSelection(baseOffset: fromPosition, extentOffset: toPosition),
      cause,
    );
  }

  void selectWordAt({
    required Offset offset,
    required SelectionChangedCause cause,
  }) {
    handleSelectionChanged(
      getWordRangeAtPoint(offset),
      cause,
    );
  }

  RenderEditableLine getRenderLineAtOffset(Offset globalOffset) {
    final rootRenderBox = this.rootRenderBox;
    final rootOffset = rootRenderBox.globalToLocal(globalOffset);
    final constrainedOffset = Offset(
      rootOffset.dx.clamp(0.0, rootRenderBox.size.width),
      rootOffset.dy.clamp(0.0, rootRenderBox.size.height),
    );
    return (controller.ast.greenRoot.key!.currentContext!.findRenderObject()
                as RenderEditableLine)
            .hittestFindLowest<RenderEditableLine>(constrainedOffset) ??
        controller.ast.greenRoot.key!.currentContext!.findRenderObject()
            as RenderEditableLine;
  }

  RenderBox get rootRenderBox => context.findRenderObject() as RenderBox;

  int getPositionForOffset(Offset globalOffset) {
    final target = getRenderLineAtOffset(globalOffset);
    final caretIndex = target.getCaretIndexForPoint(globalOffset);
    return target.node.pos + target.node.caretPositions[caretIndex];
  }

  Offset getLocalEndpointForPosition(int position) {
    final node = controller.ast.findNodeManagesPosition(position);
    var caretIndex = node.caretPositions
        .indexWhere((caretPosition) => caretPosition >= position);
    if (caretIndex == -1) {
      caretIndex = node.caretPositions.length - 1;
    }
    final renderLine =
        node.key!.currentContext!.findRenderObject() as RenderEditableLine;
    final globalOffset = renderLine.getEndpointForCaretIndex(caretIndex);

    return rootRenderBox.globalToLocal(globalOffset);
  }

  TextSelection getWordRangeAtPoint(Offset globalOffset) {
    final target = getRenderLineAtOffset(globalOffset);
    final caretIndex = target.getNearestLeftCaretIndexForPoint(globalOffset);
    final node = target.node;
    final extentCaretIndex = math.max(
      0,
      caretIndex + 1 >= node.caretPositions.length
          ? caretIndex - 1
          : caretIndex + 1,
    );
    final base = node.pos + node.caretPositions[caretIndex];
    final extent = node.pos + node.caretPositions[extentCaretIndex];
    return TextSelection(
      baseOffset: math.min(base, extent),
      extentOffset: math.max(base, extent),
    );
  }

  TextSelection getWordsRangeInRange({
    required Offset from,
    required Offset to,
  }) {
    final range1 = getWordRangeAtPoint(from);
    final range2 = getWordRangeAtPoint(to);

    if (range1.start <= range2.start) {
      return TextSelection(baseOffset: range1.start, extentOffset: range2.end);
    } else {
      return TextSelection(baseOffset: range1.end, extentOffset: range2.start);
    }
  }

  Rect getLocalEditingRegion() {
    final root = controller.ast.greenRoot.key!.currentContext!
        .findRenderObject() as RenderEditableLine;
    return Rect.fromPoints(
      Offset.zero,
      root.size.bottomRight(Offset.zero),
    );
  }

  @override
  TextEditingValue get textEditingValue {
    final encodeResult = controller.selectedNodes.encodeTex();
    String string;
    if (controller.selection.start == 0 &&
        controller.selection.end ==
            controller.ast.greenRoot.capturedCursor - 1) {
      string = encodeResult;
    } else {
      string = '$encodeResult$_selectAllReservedTag';
    }
    return TextEditingValue(
      text: string,
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: encodeResult.length,
      ),
    );
  }

  static const _selectAllReservedTag = 'THIS MARKUP SHOULD NOT APPEAR!';

  set textEditingValue(TextEditingValue value) {
    // Select All ?
    if (value.selection.start == 0 &&
        value.selection.end == value.text.length &&
        value.text.length > controller.ast.greenRoot.capturedCursor - 1) {
      handleSelectionChanged(
        TextSelection(
          baseOffset: 0,
          extentOffset: controller.ast.greenRoot.capturedCursor - 1,
        ),
        null,
        ExtraSelectionChangedCause.handle,
      );
    }
  }
}
