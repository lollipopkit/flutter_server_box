import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../ast/syntax_tree.dart';
import '../../utils/num_extension.dart';
import 'line.dart';

class EditableLine extends MultiChildRenderObjectWidget {
  EditableLine({
    Key? key,
    this.crossAxisAlignment = CrossAxisAlignment.baseline,
    this.cursorBlinkOpacityController,
    required this.cursorColor,
    this.cursorOffset,
    this.cursorOpacityAnimates = false,
    this.cursorRadius,
    this.cursorWidth = 1.0,
    this.cursorHeight,
    this.devicePixelRatio = 1.0,
    this.hintingColor,
    this.minDepth = 0.0,
    this.minHeight = 0.0,
    required this.node,
    this.paintCursorAboveText = false,
    required this.preferredLineHeight,
    this.selection = const TextSelection.collapsed(offset: -1),
    this.selectionColor,
    this.showCursor = false,
    this.startHandleLayerLink,
    this.endHandleLayerLink,
    this.textBaseline = TextBaseline.alphabetic,
    this.textDirection,
    List<Widget> children = const [],
  }) : super(key: key, children: children);

  final CrossAxisAlignment crossAxisAlignment;

  final AnimationController? cursorBlinkOpacityController;

  final Color cursorColor;

  final Offset? cursorOffset;

  final bool cursorOpacityAnimates;

  final Radius? cursorRadius;

  final double cursorWidth;

  final double? cursorHeight;

  final double devicePixelRatio;

  final Color? hintingColor;

  final double minDepth;

  final double minHeight;

  final EquationRowNode node;

  final bool paintCursorAboveText;

  final double preferredLineHeight;

  final TextSelection selection;

  final Color? selectionColor;

  final bool showCursor;

  final LayerLink? startHandleLayerLink;

  final LayerLink? endHandleLayerLink;

  final TextBaseline textBaseline;

  final TextDirection? textDirection;

  bool get _needTextDirection => true;

  @protected
  TextDirection? getEffectiveTextDirection(BuildContext context) =>
      textDirection ?? (_needTextDirection ? Directionality.of(context) : null);

  @override
  RenderEditableLine createRenderObject(BuildContext context) =>
      RenderEditableLine(
        crossAxisAlignment: crossAxisAlignment,
        cursorBlinkOpacityController: cursorBlinkOpacityController,
        cursorColor: cursorColor,
        cursorOffset: cursorOffset,
        cursorRadius: cursorRadius,
        cursorWidth: cursorWidth,
        cursorHeight: cursorHeight,
        devicePixelRatio: devicePixelRatio,
        hintingColor: hintingColor,
        minDepth: minDepth,
        minHeight: minHeight,
        node: node,
        paintCursorAboveText: paintCursorAboveText,
        preferredLineHeight: preferredLineHeight,
        selection: selection,
        selectionColor: selectionColor,
        showCursor: showCursor,
        startHandleLayerLink: startHandleLayerLink,
        endHandleLayerLink: endHandleLayerLink,
        textBaseline: textBaseline,
        textDirection: getEffectiveTextDirection(context),
      );

  @override
  void updateRenderObject(
          BuildContext context, RenderEditableLine renderObject) =>
      renderObject
        ..crossAxisAlignment = crossAxisAlignment
        ..cursorBlinkOpacityController = cursorBlinkOpacityController
        ..cursorColor = cursorColor
        ..cursorOffset = cursorOffset
        ..cursorRadius = cursorRadius
        ..cursorWidth = cursorWidth
        ..cursorHeight = cursorHeight
        ..devicePixelRatio = devicePixelRatio
        ..hintingColor = hintingColor
        ..minDepth = minDepth
        ..minHeight = minHeight
        ..node = node
        ..paintCursorAboveText = paintCursorAboveText
        ..preferredLineHeight = preferredLineHeight
        ..selection = selection
        ..selectionColor = selectionColor
        ..showCursor = showCursor
        ..startHandleLayerLink = startHandleLayerLink
        ..endHandleLayerLink = endHandleLayerLink
        ..textBaseline = textBaseline
        ..textDirection = getEffectiveTextDirection(context);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextBaseline>('textBaseline', textBaseline,
        defaultValue: null));
    properties.add(EnumProperty<CrossAxisAlignment>(
        'crossAxisAlignment', crossAxisAlignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
  }
}

class RenderEditableLine extends RenderLine {
  RenderEditableLine({
    List<RenderBox>? children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.baseline,
    AnimationController? cursorBlinkOpacityController,
    required Color cursorColor,
    Offset? cursorOffset,
    Radius? cursorRadius,
    double cursorWidth = 1.0,
    double? cursorHeight,
    double devicePixelRatio = 1.0,
    Color? hintingColor,
    double minDepth = 0,
    double minHeight = 0,
    required this.node,
    bool paintCursorAboveText = false,
    required this.preferredLineHeight,
    TextSelection selection = const TextSelection.collapsed(offset: -1),
    Color? selectionColor,
    bool showCursor = false,
    LayerLink? startHandleLayerLink,
    LayerLink? endHandleLayerLink,
    TextBaseline textBaseline = TextBaseline.alphabetic,
    TextDirection? textDirection = TextDirection.ltr,
  })  :
        // assert(!showCursor || cursorColor != null),
        _cursorBlinkOpacityController = cursorBlinkOpacityController,
        _cursorColor = cursorColor,
        _cursorOffset = cursorOffset,
        _cursorRadius = cursorRadius,
        _cursorWidth = cursorWidth,
        _cursorHeight = cursorHeight,
        _devicePixelRatio = devicePixelRatio,
        _hintingColor = hintingColor,
        _paintCursorAboveText = paintCursorAboveText,
        _selection = selection,
        _selectionColor = selectionColor,
        _showCursor = showCursor,
        _startHandleLayerLink = startHandleLayerLink,
        _endHandleLayerLink = endHandleLayerLink,
        super(
          children: children,
          crossAxisAlignment: crossAxisAlignment,
          minDepth: minDepth,
          minHeight: minHeight,
          textBaseline: textBaseline,
          textDirection: textDirection,
        );

  AnimationController? get cursorBlinkOpacityController =>
      _cursorBlinkOpacityController;
  AnimationController? _cursorBlinkOpacityController;
  set cursorBlinkOpacityController(AnimationController? value) {
    if (_cursorBlinkOpacityController != value) {
      _cursorBlinkOpacityController?.removeListener(onCursorOpacityChanged);
      _cursorBlinkOpacityController = value;
      _cursorBlinkOpacityController?.addListener(onCursorOpacityChanged);
      markNeedsPaint();
    }
  }

  void onCursorOpacityChanged() {
    if (showCursor && selection.isCollapsed && isSelectionInRange) {
      markNeedsPaint();
    }
  }

  /// The color to use when painting the cursor.
  Color get cursorColor => _cursorColor;
  Color _cursorColor;
  set cursorColor(Color value) {
    if (_cursorColor != value) {
      _cursorColor = value;
      markNeedsPaint();
    }
  }

  /// {@macro flutter.rendering.editable.cursorOffset}
  Offset? get cursorOffset => _cursorOffset;
  Offset? _cursorOffset;
  set cursorOffset(Offset? value) {
    if (_cursorOffset != value) {
      _cursorOffset = value;
      markNeedsPaint();
    }
  }

  /// How rounded the corners of the cursor should be.
  ///
  /// A null value is the same as [Radius.zero].
  Radius? get cursorRadius => _cursorRadius;
  Radius? _cursorRadius;
  set cursorRadius(Radius? value) {
    if (_cursorRadius != value) {
      _cursorRadius = value;
      markNeedsPaint();
    }
  }

  double get cursorWidth => _cursorWidth;
  double _cursorWidth;
  set cursorWidth(double value) {
    if (_cursorWidth != value) {
      _cursorWidth = value;
      markNeedsPaint();
    }
  }

  /// How tall the cursor will be.
  ///
  /// This can be null, in which case the getter will actually return
  /// [preferredLineHeight].
  ///
  /// Setting this to itself fixes the value to the current
  /// [preferredLineHeight]. Setting
  /// this to null returns the behaviour of deferring to [preferredLineHeight].
  double get cursorHeight => _cursorHeight ?? preferredLineHeight;
  double? _cursorHeight;
  set cursorHeight(double? value) {
    if (_cursorHeight != value) {
      _cursorHeight = value;
      markNeedsPaint();
    }
  }

  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio != value) {
      _devicePixelRatio = value;
      markNeedsPaint();
    }
  }

  Color? get hintingColor => _hintingColor;
  Color? _hintingColor;
  set hintingColor(Color? value) {
    if (_hintingColor != value) {
      _hintingColor = value;
      markNeedsPaint();
    }
  }

  EquationRowNode node;

  /// {@template flutter.rendering.editable.paintCursorOnTop}
  bool get paintCursorAboveText => _paintCursorAboveText;
  bool _paintCursorAboveText;
  set paintCursorAboveText(bool value) {
    if (_paintCursorAboveText != value) {
      _paintCursorAboveText = value;
      markNeedsPaint();
    }
  }

  double preferredLineHeight;

  TextSelection get selection => _selection;
  TextSelection _selection;
  set selection(TextSelection value) {
    if (_selection != value) {
      _selection = value;
      markNeedsPaint();
    }
  }

  /// The color to use when painting the selection.
  Color? get selectionColor => _selectionColor;
  Color? _selectionColor;
  set selectionColor(Color? value) {
    if (_selectionColor != value) {
      _selectionColor = value;
      markNeedsPaint();
    }
  }

  /// Whether to paint the cursor.
  bool get showCursor => _showCursor;
  bool _showCursor;
  set showCursor(bool value) {
    if (_showCursor != value) {
      _showCursor = value;
      markNeedsPaint();
    }
  }

  LayerLink? get startHandleLayerLink => _startHandleLayerLink;
  LayerLink? _startHandleLayerLink;
  set startHandleLayerLink(LayerLink? value) {
    if (_startHandleLayerLink != value) {
      _startHandleLayerLink = value;
      markNeedsPaint();
    }
  }

  LayerLink? get endHandleLayerLink => _endHandleLayerLink;
  LayerLink? _endHandleLayerLink;
  set endHandleLayerLink(LayerLink? value) {
    if (_endHandleLayerLink != value) {
      _endHandleLayerLink = value;
      markNeedsPaint();
    }
  }

  bool get isSelectionInRange =>
      _selection.end >= 0 && _selection.start <= childCount;

  int getCaretIndexForPoint(Offset globalOffset) {
    final localOffset = globalToLocal(globalOffset);
    var minDist = double.infinity;
    var minPosition = 0;
    for (var i = 0; i < caretOffsets.length; i++) {
      final dist = (caretOffsets[i] - localOffset.dx).abs();
      if (dist <= minDist) {
        minDist = dist;
        minPosition = i;
      }
    }
    return minPosition;
  }

  // Will always attempt to get the nearest left caret
  int getNearestLeftCaretIndexForPoint(Offset globalOffset) {
    final localOffset = globalToLocal(globalOffset);
    var index = 0;
    while (
        index < caretOffsets.length && caretOffsets[index] <= localOffset.dx) {
      index++;
    }
    return math.max(0, index - 1);
  }

  Offset getEndpointForCaretIndex(int index) {
    final dx = caretOffsets[index.clampInt(0, caretOffsets.length - 1)];
    final dy = size.height;
    return localToGlobal(Offset(dx, dy));
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    // Only paint selection/hinting if the part of the selection is in range
    if (isSelectionInRange) {
      final startOffset = caretOffsets[math.max(0, selection.start)];
      final endOffset = caretOffsets[math.min(childCount, selection.end)];
      if (_selection.isCollapsed) {
        if (_hintingColor != null) {
          // Paint hinting background if selection is collapsed
          context.canvas.drawRect(
            offset & size,
            Paint()
              ..style = PaintingStyle.fill
              ..color = _hintingColor!,
          );
        }
      } else if (_selectionColor != null) {
        // Paint selection if not collapsed
        context.canvas.drawRect(
          Rect.fromLTRB(startOffset, 0, endOffset, size.height).shift(offset),
          Paint()
            ..style = PaintingStyle.fill
            ..color = _selectionColor!,
        );
      }

      // Whatever which case, we need to mark the layer link.
      if (startHandleLayerLink != null) {
        context.pushLayer(
          LeaderLayer(
            link: startHandleLayerLink!,
            offset: Offset(startOffset, size.height) + offset,
          ),
          emptyPaintFunction,
          Offset.zero,
        );
      }
      if (endHandleLayerLink != null) {
        context.pushLayer(
          LeaderLayer(
            link: endHandleLayerLink!,
            offset: Offset(endOffset, size.height) + offset,
          ),
          emptyPaintFunction,
          Offset.zero,
        );
      }
    }

    if (_paintCursorAboveText) {
      super.paint(context, offset);
    }

    if (showCursor && _selection.isCollapsed && isSelectionInRange) {
      final cursorOffset = caretOffsets[selection.baseOffset];
      _paintCaret(context.canvas, Offset(cursorOffset, size.height) + offset);
    }

    if (!_paintCursorAboveText) {
      super.paint(context, offset);
    }

    return;
  }

  // static const _kCaretHeightOffset = 2.0;

  void _paintCaret(Canvas canvas, Offset baselineOffset) {
    final paint = Paint()
      ..color =
          _cursorColor.withOpacity(_cursorBlinkOpacityController?.value ?? 0);

    Rect _caretPrototype;

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        _caretPrototype = Rect.fromLTWH(
          0.0,
          0.0,
          _cursorWidth,
          cursorHeight + 2,
        );
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.ohos:
        _caretPrototype = Rect.fromLTWH(
          0.0,
          0.0, // _kCaretHeightOffset,
          _cursorWidth,
          cursorHeight, // - 2.0 * _kCaretHeightOffset,
        );
        break;
    }

    var caretRect = _caretPrototype
        .shift(baselineOffset)
        .shift(Offset(0, -0.9 * cursorHeight)); // 0.9 is eyeballed

    if (_cursorOffset != null) {
      caretRect = caretRect.shift(_cursorOffset!);
    }

    // final double caretHeight =
    //     _textPainter.getFullHeightForCaret(textPosition, _caretPrototype);
    // if (caretHeight != null) {
    //   switch (defaultTargetPlatform) {
    //     case TargetPlatform.iOS:
    //     case TargetPlatform.macOS:
    //       final heightDiff = caretHeight - caretRect.height;
    //       // Center the caret vertically along the text.
    //       caretRect = Rect.fromLTWH(
    //         caretRect.left,
    //         caretRect.top + heightDiff / 2,
    //         caretRect.width,
    //         caretRect.height,
    //       );
    //       break;
    //     case TargetPlatform.android:
    //     case TargetPlatform.fuchsia:
    //     case TargetPlatform.linux:
    //     case TargetPlatform.windows:
    //       // Override the height to take the full height of the glyph at the TextPosition
    //       // when not on iOS. iOS has special handling that creates a taller caret.
    //       caretRect = Rect.fromLTWH(
    //         caretRect.left,
    //         caretRect.top - _kCaretHeightOffset,
    //         caretRect.width,
    //         caretHeight,
    //       );
    //       break;
    //   }
    // }

    caretRect = caretRect.shift(_getPixelPerfectCursorOffset(caretRect));

    if (_cursorRadius == null) {
      canvas.drawRect(caretRect, paint);
    } else {
      final caretRRect = RRect.fromRectAndRadius(caretRect, _cursorRadius!);
      canvas.drawRRect(caretRRect, paint);
    }
  }

  /// Computes the offset to apply to the given [caretRect] so it perfectly
  /// snaps to physical pixels.
  Offset _getPixelPerfectCursorOffset(Rect caretRect) {
    final caretPosition = localToGlobal(caretRect.topLeft);
    final pixelMultiple = 1.0 / _devicePixelRatio;
    final pixelPerfectOffsetX = caretPosition.dx.isFinite
        ? (caretPosition.dx / pixelMultiple).round() * pixelMultiple -
            caretPosition.dx
        : 0.0;
    final pixelPerfectOffsetY = caretPosition.dy.isFinite
        ? (caretPosition.dy / pixelMultiple).round() * pixelMultiple -
            caretPosition.dy
        : 0.0;
    return Offset(pixelPerfectOffsetX, pixelPerfectOffsetY);
  }
}

void emptyPaintFunction(PaintingContext context, Offset offset) {}
