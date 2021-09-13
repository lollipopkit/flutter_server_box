import 'package:flutter/material.dart';

class DebugProvider extends ChangeNotifier {
  final widgets = <Widget>[];

  void addText(String text) {
    _addText(text);
    notifyListeners();
  }

  void _addText(String text) {
    _addWidget(Text(text));
  }

  void addError(Object error) {
    _addError(error);
    notifyListeners();
  }

  void _addError(Object error) {
    _addMultiline(error, Colors.red);
  }

  void addMultiline(Object data, [Color color = Colors.blue]) {
    _addMultiline(data, color);
    notifyListeners();
  }

  void _addMultiline(Object data, [Color color = Colors.blue]) {
    final widget = Text(
      '$data',
      style: TextStyle(
        color: color,
      ),
    );
    _addWidget(SingleChildScrollView(
      child: widget,
      scrollDirection: Axis.horizontal,
    ));
  }

  void addWidget(Widget widget) {
    _addWidget(widget);
    notifyListeners();
  }

  void _addWidget(Widget widget) {
    final outlined = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.green,
        ),
      ),
      child: widget,
    );

    widgets.add(outlined);
  }

  void clear() {
    widgets.clear();
    notifyListeners();
  }
}
