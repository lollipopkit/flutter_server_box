import 'package:flutter/widgets.dart';
import 'package:xterm/core.dart';

import '../../locator.dart';
import '../store/setting.dart';

class VirtualKeyboard extends TerminalInputHandler with ChangeNotifier {
  VirtualKeyboard();

  bool _ctrl = false;
  bool get ctrl => _ctrl;
  set ctrl(bool value) {
    if (value != _ctrl) {
      _ctrl = value;
      notifyListeners();
    }
  }

  bool _alt = false;
  bool get alt => _alt;
  set alt(bool value) {
    if (value != _alt) {
      _alt = value;
      notifyListeners();
    }
  }

  final _setting = locator<SettingStore>();

  void reset(TerminalKeyboardEvent e) {
    if (e.ctrl) {
      ctrl = false;
    }
    if (e.alt) {
      alt = false;
    }
    notifyListeners();
  }

  @override
  String? call(TerminalKeyboardEvent event) {
    final e = event.copyWith(
      ctrl: event.ctrl || ctrl,
      alt: event.alt || alt,
    );
    if (_setting.sshVirtualKeyAutoOff.fetch()) {
      reset(e);
    }
    return defaultInputHandler.call(e);
  }
}
