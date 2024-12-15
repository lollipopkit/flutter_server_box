import 'package:flutter/services.dart';
import 'package:server_box/data/res/misc.dart';

abstract final class MethodChans {
  static const _channel = MethodChannel('${Miscs.pkgName}/main_chan');

  static void moveToBg() {
    _channel.invokeMethod('sendToBackground');
  }

  /// TODO: try fix the fn, then uncomment it and [stopService]
  /// Issues #639
  static void startService() {
    // _channel.invokeMethod('startService');
  }

  static void stopService() {
    // _channel.invokeMethod('stopService');
  }

  static void updateHomeWidget() async {
    //if (!Stores.setting.autoUpdateHomeWidget.fetch()) return;
    await _channel.invokeMethod('updateHomeWidget');
  }
}
