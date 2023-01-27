import 'package:flutter/material.dart';

/// format: [NAME][LEVEL]: MESSAGE
final _headReg = RegExp(r'(\[[A-Za-z]+\])(\[[A-Z]+\]): (.*)');
const _level2Color = {
  '[INFO]': Colors.blue,
  '[WARNING]': Colors.yellow,
};

class DebugProvider extends ChangeNotifier {
  final widgets = <Widget>[];

  void addText(String text) {
    final match = _headReg.allMatches(text);

    if (match.isNotEmpty) {
      addWidget(Text.rich(TextSpan(
        children: [
          TextSpan(
            text: match.first.group(1),
            style: const TextStyle(color: Colors.cyan),
          ),
          TextSpan(
            text: match.first.group(2),
            style: TextStyle(color: _level2Color[match.first.group(2)]),
          ),
          TextSpan(
            text: '\n${match.first.group(3)}',
          )
        ],
      )));
    } else {
      _addText(text);
    }

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
      scrollDirection: Axis.horizontal,
      child: widget,
    ));
  }

  void addWidget(Widget widget) {
    _addWidget(widget);
    notifyListeners();
  }

  void _addWidget(Widget widget) {
    widgets.add(widget);
    widgets.add(const SizedBox(height: 13));
  }

  void clear() {
    widgets.clear();
    notifyListeners();
  }
}
