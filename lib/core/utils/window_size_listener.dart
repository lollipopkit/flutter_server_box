import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/store.dart';
import 'package:window_manager/window_manager.dart';

abstract final class WindowSizeListener {
  static final _WindowSizeListener instance = _WindowSizeListener();
}

final class _WindowSizeListener implements WindowListener {
  @override
  void onWindowBlur() {
  }

  @override
  void onWindowClose() {
  }

  @override
  void onWindowDocked() {
  }

  @override
  void onWindowEnterFullScreen() {
  }

  @override
  void onWindowEvent(String eventName) {
  }

  @override
  void onWindowFocus() {
  }

  @override
  void onWindowLeaveFullScreen() {
  }

  @override
  void onWindowMaximize() {
  }

  @override
  void onWindowMinimize() {
  }

  @override
  void onWindowMove() {
  }

  @override
  void onWindowMoved() {
  }

  @override
  void onWindowResize() {
    if (!isLinux) return;
    final current = Stores.setting.windowSize.fetch();
    if (current.isEmpty) return;

    windowManager.getSize().then((size) {
      Stores.setting.windowSize.put(size.toIntStr());
    });
  }

  @override
  void onWindowResized() {
    if (!isMacOS || !isWindows) return;
    final current = Stores.setting.windowSize.fetch();
    if (current.isEmpty) return;

    windowManager.getSize().then((size) {
      Stores.setting.windowSize.put(size.toIntStr());
    });
  }

  @override
  void onWindowRestore() {
  }

  @override
  void onWindowUndocked() {
  }

  @override
  void onWindowUnmaximize() {
  }

}