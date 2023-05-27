import 'package:flutter/widgets.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';
import 'package:xterm/core.dart';

class VirtualKeyboard extends TerminalInputHandler with ChangeNotifier {
  VirtualKeyboard();

  bool ctrl = false;
  bool alt = false;

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
    if (_setting.sshVirtualKeyAutoOff.fetch()!) {
      reset(e);
    }
    return defaultInputHandler.call(e);
  }
}
