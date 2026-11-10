import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/app_link.dart';

/// Puts a `serverbox://` link on the clipboard; `AppLinkRouter` acts on one.
abstract final class AppLinkUi {
  static void copy(AppLink link) {
    Pfs.copy(link.toString());
    Toast.success(libL10n.success);
  }
}
