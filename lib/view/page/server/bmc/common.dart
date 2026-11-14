import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/src/rust/api/bmc.dart';

/// What a BMC's failure means, in this app's words.
String bmcFailureText(RedfishFailure failure, String? detail) =>
    switch (failure) {
      RedfishFailure.certificateRejected ||
      RedfishFailure.certNotReviewed => l10n.bmcCertRejected,
      RedfishFailure.unauthorized => l10n.bmcUnauthorized,
      RedfishFailure.noCredential => l10n.bmcAccountMissing,
      RedfishFailure.notAService => l10n.bmcNotAService,
      RedfishFailure.noSystem => l10n.bmcNoSystem,
      // Names the resource, because it is an answer about one resource
      RedfishFailure.forbidden => '${libL10n.fail}: ${detail ?? ''}',
      // Retrying after a fresh read is the fix: this is what a change made
      // through the BMC's own web interface in the meantime looks like.
      RedfishFailure.preconditionRequired => l10n.bmcStaleWrite,
      RedfishFailure.invalidUrl => l10n.bmcAddrInvalid,
      RedfishFailure.unreachable ||
      RedfishFailure.notSupported ||
      RedfishFailure.invalidResponse ||
      RedfishFailure.closed => detail ?? libL10n.fail,
    };

String bmcErrorText(Object e) =>
    e is BmcError ? bmcFailureText(e.failure, e.detail) : '$e';

extension BmcRun on BuildContext {
  /// Runs one change behind a loading sheet and says how it went. Bounded by
  /// the client's own timeout per request, not the sheet's: a write is a read
  /// for the ETag, the write, and a read back, each up to it.
  Future<bool> bmcRun(Future<void> Function() fn) => _bmcRun(fn);

  /// As [bmcRun], for a change the service may take as a task: taken is not
  /// done, and saying so is the point.
  Future<bool> bmcRunTask(Future<BmcPowerResult> Function() fn) => _bmcRun(fn);

  Future<bool> _bmcRun<T>(Future<T> Function() fn) async {
    final (result, err) = await showLoadingSheet(
      fn: fn,
      showErr: false,
      timeout: const Duration(minutes: 2),
    );
    if (err != null) {
      Toast.error(libL10n.fail, body: bmcErrorText(err));
      return false;
    }
    if (result is BmcPowerResult && result == BmcPowerResult.accepted) {
      Toast.warn(l10n.bmcPowerAccepted);
    } else {
      Toast.success(libL10n.success);
    }
    return true;
  }
}

/// `Critical` red, `Warning` orange, anything else plain.
Color? bmcHealthColor(String? health) => switch (health) {
  'Critical' => Colors.red,
  'Warning' => Colors.orange,
  _ => null,
};
