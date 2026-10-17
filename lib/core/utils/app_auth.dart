import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/store.dart';

abstract final class AppAuth {
  /// Asks for the device's authentication before something secret is shown
  /// or used, when the app lock is on; passes without asking when it is off.
  static Future<bool> confirm() async {
    if (!Stores.setting.useBioAuth.fetch()) return true;
    return await LocalAuth.goWithResult() == AuthResult.success;
  }
}
