import 'package:flutter/services.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';

abstract final class HomeWidgetMC {
  static const _channel = MethodChannel('${Miscs.pkgName}/home_widget');

  static void update() {
    if (!Stores.setting.autoUpdateHomeWidget.fetch()) return;
    _channel.invokeMethod('update');
  }
}
