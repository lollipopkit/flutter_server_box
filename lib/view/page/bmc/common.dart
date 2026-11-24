import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/bmc/bmc_cfg.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/widget/cert_sheet.dart';

/// Route argument carrying a [BmcTarget] for detail, logs, and drives pages.
final class BmcTargetRequiredArgs {
  final BmcTarget target;

  const BmcTargetRequiredArgs(this.target);
}

/// Optional route argument for [BmcTargetEditPage].
final class BmcTargetEditArgs {
  final BmcTarget? target;
  final String? serverId;

  const BmcTargetEditArgs({this.target, this.serverId});
}

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

String bmcIntentText(PowerIntent intent) => switch (intent) {
  PowerIntent.on_ => l10n.bmcPowerOnAction,
  PowerIntent.gracefulShutdown => l10n.bmcShutdown,
  PowerIntent.forceOff => l10n.bmcForceOff,
  PowerIntent.restart => l10n.restart,
  PowerIntent.powerCycle => l10n.bmcPowerCycle,
};

String bmcPowerText(PowerState state) => switch (state) {
  PowerState.on_ => l10n.bmcPowerOn,
  PowerState.off => l10n.bmcPowerOff,
  PowerState.poweringOn || PowerState.poweringOff => libL10n.loadingEllipsis,
  PowerState.paused => l10n.virtPaused,
  PowerState.unknown => libL10n.unknown,
};

/// Formats a sensor reading without leaving trailing whitespace when [r.unit]
/// is missing or empty.
String formatBmcReading(BmcReading r) {
  final unit = r.unit;
  if (unit == 'Cel') return '${r.value.toStringAsFixed(1)}°C';
  final numText = r.value.toStringAsFixed(0);
  if (unit == null || unit.isEmpty) return numText;
  return '$numText $unit';
}

String bmcBootEnabledText(String enabled) => switch (enabled) {
  'Disabled' => l10n.bmcBootDisabled,
  'Once' => l10n.bmcBootOnce,
  'Continuous' => l10n.bmcBootContinuous,
  _ => enabled,
};

/// Fetches the leaf TLS certificate presented by [addr] and asks the user to
/// confirm its fingerprint. Returns the accepted SHA-256 fingerprint, or null
/// when cancelled / failed.
Future<String?> reviewBmcCert(
  BuildContext context, {
  required String addr,
  String? pinned,
  bool reconnects = false,
}) async {
  final uri = BmcCfg.parseUri(addr);
  if (uri == null) {
    Toast.error(l10n.bmcAddrInvalid);
    return null;
  }
  final host = uri.host;
  final port = uri.port;

  final (info, err) = await context.showLoadingSheet(
    fn: () => bmcFetchServerCert(host: host, port: port),
    showErr: false,
  );
  if (!context.mounted) return null;
  if (err != null || info == null) {
    Toast.error(libL10n.fail, body: err == null ? null : bmcErrorText(err));
    return null;
  }

  final accepted = await showCertTrustSheet(
    context,
    cert: info,
    previous: pinned != info.fingerprint ? pinned : null,
    source: '$host:$port',
    reconnects: reconnects,
  );
  if (!accepted || !context.mounted) return null;
  return info.fingerprint;
}

/// Prompts the user to review [target]'s certificate and persists the accepted
/// SHA-256 fingerprint immediately.
Future<bool> trustBmcTargetCert(
  BuildContext context,
  WidgetRef ref,
  BmcTarget target,
) async {
  final reviewedAddr = target.addr.trim();
  final fp = await reviewBmcCert(
    context,
    addr: reviewedAddr,
    pinned: target.certSha256,
    reconnects: true,
  );
  if (fp == null || !context.mounted) return false;
  final saved = ref
      .read(bmcTargetsProvider.notifier)
      .updateCertPin(target.id, fp, expectedAddr: reviewedAddr);
  if (!saved) {
    Toast.error(libL10n.fail, body: l10n.bmcStaleWrite);
    return false;
  }
  return true;
}

/// Asks for confirmation before sending Power On to [target], runs [run], and
/// surfaces the outcome via toast.
///
/// Captures [target]'s address and certificate pin before opening the sheet and
/// aborts without sending if either changed while the confirmation was open.
Future<void> confirmAndRunBmcPowerOn({
  required BuildContext context,
  required WidgetRef ref,
  required BmcTarget target,
  required Future<BmcPowerResult> Function() run,
}) async {
  final expectedAddr = target.addr.trim();
  final expectedCert = target.certSha256;
  final ok = await context.showSheet<bool>(
    title: l10n.bmcPowerOnAction,
    child: Text(l10n.bmcPowerConfirm(target.name, 'On')),
    actions: Btnx.cancelOk,
  );
  if (ok != true || !context.mounted) return;
  final current = ref.read(bmcTargetsProvider).targets[target.id];
  if (current == null ||
      current.addr.trim() != expectedAddr ||
      current.certSha256 != expectedCert) {
    Toast.error(libL10n.fail, body: l10n.bmcStaleWrite);
    return;
  }
  final result = await run();
  switch (result) {
    case BmcPowerResult.confirmed:
      Toast.success(l10n.bmcPowerDone);
    case BmcPowerResult.accepted:
      Toast.warn(l10n.bmcPowerAccepted);
    case BmcPowerResult.notSupported:
      Toast.error(libL10n.fail, body: l10n.bmcPowerUnsupported);
    case BmcPowerResult.failed:
      Toast.error(libL10n.fail);
  }
}

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
    if (result is BmcPowerResult) {
      switch (result) {
        case BmcPowerResult.confirmed:
          Toast.success(libL10n.success);
          return true;
        case BmcPowerResult.accepted:
          Toast.warn(l10n.bmcPowerAccepted);
          return true;
        case BmcPowerResult.notSupported:
          Toast.error(libL10n.fail, body: l10n.bmcPowerUnsupported);
          return false;
        case BmcPowerResult.failed:
          Toast.error(libL10n.fail);
          return false;
      }
    }
    Toast.success(libL10n.success);
    return true;
  }
}

/// `Critical` red, `Warning` orange, anything else plain.
Color? bmcHealthColor(String? health) => switch (health) {
  'Critical' => Colors.red,
  'Warning' => Colors.orange,
  _ => null,
};
