import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/res/store.dart';
import 'package:xterm/core.dart';

part 'virtual_keyboard.g.dart';
part 'virtual_keyboard.freezed.dart';

@freezed
abstract class VirtKeyState with _$VirtKeyState {
  const factory VirtKeyState({
    @Default(false) final bool ctrl,
    @Default(false) final bool alt,
    @Default(false) final bool shift,
  }) = _VirtKeyState;
}

@riverpod
class VirtKeyboard extends _$VirtKeyboard implements TerminalInputHandler {
  @override
  VirtKeyState build() {
    return const VirtKeyState();
  }

  bool get ctrl => state.ctrl;
  bool get alt => state.alt;
  bool get shift => state.shift;

  void setCtrl(bool value) {
    if (value != state.ctrl) {
      state = state.copyWith(ctrl: value);
    }
  }

  void setAlt(bool value) {
    if (value != state.alt) {
      state = state.copyWith(alt: value);
    }
  }

  void setShift(bool value) {
    if (value != state.shift) {
      state = state.copyWith(shift: value);
    }
  }

  void reset(TerminalKeyboardEvent e) {
    state = state.copyWith(
      ctrl: e.ctrl ? false : state.ctrl,
      alt: e.alt ? false : state.alt,
      shift: e.shift ? false : state.shift,
    );
  }

  @override
  String? call(TerminalKeyboardEvent event) {
    final e = event.copyWith(
      ctrl: event.ctrl || state.ctrl,
      alt: event.alt || state.alt,
      shift: event.shift || state.shift,
    );
    if (Stores.setting.sshVirtualKeyAutoOff.fetch()) {
      reset(e);
    }
    return defaultInputHandler.call(e);
  }
}
