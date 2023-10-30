import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/data/res/ui.dart';

import '../../data/res/misc.dart';

const _level2Color = {
  'INFO': Colors.blue,
  'WARNING': Colors.yellow,
};

class DebugProvider extends ChangeNotifier {
  final widgets = <Widget>[];

  void addLog(LogRecord record) {
    final color = _level2Color[record.level.name] ?? Colors.blue;
    widgets.add(Text.rich(TextSpan(
      children: [
        TextSpan(
          text: '[${record.loggerName}]',
          style: const TextStyle(color: Colors.cyan),
        ),
        TextSpan(
          text: '[${record.level}]',
          style: TextStyle(color: color),
        ),
        TextSpan(
          text: record.error == null
              ? '\n${record.message}'
              : '\n${record.message}: ${record.error}',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    )));
    if (record.stackTrace != null) {
      widgets.add(SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          '${record.stackTrace}',
          style: const TextStyle(color: Colors.white),
        ),
      ));
    }
    widgets.add(UIs.height13);

    if (widgets.length > Miscs.maxDebugLogLines) {
      widgets.removeRange(0, widgets.length - Miscs.maxDebugLogLines);
    }
    notifyListeners();
  }

  void clear() {
    widgets.clear();
    notifyListeners();
  }
}
