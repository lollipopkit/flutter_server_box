import 'package:flutter/widgets.dart';

mixin FocusManagerMixin<T extends StatefulWidget> on State<T> {
  FocusNode get focusNode;

  late FocusNode _oldFocusNode;

  late FocusAttachment _focusAttachment;

  @override
  void initState() {
    super.initState();

    _focusAttachment = focusNode.attach(context);
    _oldFocusNode = focusNode;
  }

  @override
  void didUpdateWidget(T oldWidget) {
    if (focusNode != _oldFocusNode) {
      _focusAttachment.detach();
      _focusAttachment = focusNode.attach(context);
      _oldFocusNode = focusNode;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _focusAttachment.detach();
    super.dispose();
  }

  @mustCallSuper
  @override
  Widget build(BuildContext context) {
    super.build(context);
    _focusAttachment.reparent();
    return _NullWidget();
  }
}

class _NullWidget extends StatelessWidget {
  const _NullWidget();

  @override
  Widget build(BuildContext context) {
    throw FlutterError(
        'Widgets that mix FocusManagerMixin into their State must call'
        'super.build() but must ignore the return value of the superclass.');
  }
}
