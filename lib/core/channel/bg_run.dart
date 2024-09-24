import 'package:flutter/services.dart';
import 'package:server_box/data/res/misc.dart';

abstract final class BgRunMC {
  static const _channel = MethodChannel('${Miscs.pkgName}/app_retain');

  static void moveToBg() {
    _channel.invokeMethod('sendToBackground');
  }

  static void startService() {
    _channel.invokeMethod('startService');
  }

  static void stopService() {
    _channel.invokeMethod('stopService');
  }
}
