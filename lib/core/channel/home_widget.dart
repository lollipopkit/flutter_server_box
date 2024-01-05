import 'package:flutter/services.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/data/res/store.dart';

abstract final class HomeWidgetMC {
  static const _channel = MethodChannel('${Miscs.pkgName}/home_widget');

  static void update() {
    if (!Stores.setting.autoUpdateHomeWidget.fetch()) return;
    _channel.invokeMethod('update');
  }
}
