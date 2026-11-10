import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/stores.dart';

abstract final class AppAuth {
  /// Asks for the device's authentication before something secret is shown
  /// or used, when the app lock is on; passes without asking when it is off.
  ///
  /// Only [AuthResult.success] passes: a device that can no longer
  /// authenticate keeps the secret hidden rather than showing it unasked.
  static Future<bool> confirm() async {
    if (!Stores.setting.useBioAuth.fetch()) return true;
    return passed(await LocalAuth.goWithResult());
  }

  /// Whether [result] lets the user through, saying why when trying again
  /// will not help; a wrong finger or a cancel needs no message.
  static bool passed(AuthResult result) {
    switch (result) {
      case AuthResult.success:
        return true;
      case AuthResult.notAvail:
        Toast.error('${libL10n.bioAuth}: ${libL10n.notAvailable}');
      case AuthResult.lockedOut:
        Toast.error('${libL10n.bioAuth}: ${libL10n.fail}');
      case AuthResult.fail:
      case AuthResult.cancel:
        break;
    }
    return false;
  }
}
