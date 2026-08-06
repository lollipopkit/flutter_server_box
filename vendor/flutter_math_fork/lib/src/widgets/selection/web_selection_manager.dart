import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controller.dart';
import 'selection_manager.dart';

/// Selection utility mixin for Web
///
/// On web, we cannot use the toolbar for copying, instead we rely on the
/// right-click context menu.
///
/// DomCanvas backend basically paints any text twice: first by Flutter canvas
/// and then by browser's `textarea`. The browser `textarea` will be purely
/// transparent, and serves the sole purpose to provide context menu behaviors.
///
/// To add copy function to the right-click context menu, we need to open up a
/// [TextInputConnection] (which will create a HTML `textarea`), then pass
/// transform and size args to [TextInputConnection] (which will position the
/// `textarea` accordingly). Finally, to ensure `textarea` selection covers  our
/// widget，we use an absurdly large font size and keep a select-all state.
///
mixin WebSelectionControlsManagerMixin<T extends StatefulWidget>
    on SelectionManagerMixin<T> implements TextInputClient {
  FocusNode get focusNode;
  late FocusNode _oldFocusNode;

  TextInputConnection? _textInputConnection;

  bool get hasFocus => focusNode.hasFocus;

  late MathController _oldController;

  @override
  void initState() {
    super.initState();
    _oldFocusNode = focusNode..addListener(_handleFocusChange);
    _oldController = controller..addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_oldFocusNode != focusNode) {
      _oldFocusNode.removeListener(_handleFocusChange);
      _oldFocusNode = focusNode..addListener(_handleFocusChange);
    }
    if (_oldController != controller) {
      _oldController.removeListener(_handleControllerChange);
      _oldController = controller..addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusChange);
    controller.removeListener(_handleControllerChange);
    _closeInputConnectionIfNeeded();
    super.dispose();
  }

  void _handleFocusChange() {
    if (hasFocus && focusNode.consumeKeyboardToken()) {
      _openInputConnection();
    } else if (!hasFocus) {
      _closeInputConnectionIfNeeded();
    }
  }

  void _handleControllerChange() {
    _textInputConnection?.setEditingState(currentTextEditingValue);
  }

  bool get _hasInputConnection =>
      _textInputConnection != null && _textInputConnection!.attached;

  void _openInputConnection() {
    if (!_hasInputConnection) {
      _textInputConnection = TextInput.attach(
        this,
        TextInputConfiguration(
          inputType: TextInputType.multiline,
          readOnly: true,
          autocorrect: false,
          enableSuggestions: false,
        ),
      );
      _textInputConnection!
        ..show()
        ..setStyle(
          fontSize: 10000, // An absurd size to cover all
          fontWeight: FontWeight.normal,
          fontFamily: 'KaTeX_Main',
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )
        ..setEditingState(currentTextEditingValue);
      _updateSizeAndTransform();
    } else {
      _textInputConnection!.show();
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _textInputConnection!.close();
      _textInputConnection = null;
    }
  }

  void _updateSizeAndTransform() {
    if (_textInputConnection != null) {
      final renderBox = this.context.findRenderObject();
      if (renderBox is RenderBox) {
        final size = renderBox.size;
        final transform = renderBox.getTransformTo(null);
        _textInputConnection?.setEditableSizeAndTransform(size, transform);
      }
      SchedulerBinding.instance
          .addPostFrameCallback((Duration _) => _updateSizeAndTransform());
    }
  }

  @override
  void connectionClosed() {
    _textInputConnection?.connectionClosedReceived();
    _textInputConnection = null;
  }

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  TextEditingValue get currentTextEditingValue => super.textEditingValue;

  @override
  void performAction(TextInputAction action) {
    // no-op
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // no-op
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // no-op
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    // Disregard and reset.
    final currentTextEditingValue = this.currentTextEditingValue;
    if (value != currentTextEditingValue) {
      _textInputConnection!.setEditingState(currentTextEditingValue);
    }
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // no-op
  }
}
