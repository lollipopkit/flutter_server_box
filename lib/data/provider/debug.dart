import 'package:flutter/material.dart';
import 'package:toolbox/data/res/ui.dart';

import '../../data/res/misc.dart';

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
      _addWidget(Text.rich(TextSpan(
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
      _addWidget(Text(text));
    }
  }

  void addMultiline(Object data, [Color color = Colors.blue]) {
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

  void _addWidget(Widget widget) {
    widgets.add(widget);
    widgets.add(height13);
    if (widgets.length > maxDebugLogLines) {
      widgets.removeRange(0, widgets.length - maxDebugLogLines);
    }
    notifyListeners();
  }

  void clear() {
    widgets.clear();
    notifyListeners();
  }
}
