import 'package:flutter/services.dart';
import 'package:toolbox/data/res/misc.dart';

abstract final class HomeWidgetMC {
  static const _channel = MethodChannel('${Miscs.pkgName}/home_widget');

  static void update() {
    _channel.invokeMethod('update');
  }
}
