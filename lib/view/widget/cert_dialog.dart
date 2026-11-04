import 'package:fl_lib/fl_lib.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/bmc.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/cert_fingerprint.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/src/rust/api/bmc.dart' show CertInfo;

/// Shows a certificate the system does not trust — a PVE node's, a BMC's, a
/// monitor agent's own — and answers whether the user accepts it.
///
/// [previous] is the fingerprint accepted before, when this one replaces it;
/// [source] the `host:port` it was read from, where the user typed that.
/// [reconnects] says whether accepting connects again at once, which the
/// button says. The dialog only answers; the caller pins the certificate.
Future<bool> showCertTrustDialog(
  BuildContext context, {
  required CertInfo cert,
  String? previous,
  String? source,
  bool reconnects = true,
}) async {
  final changed = previous != null && previous.isNotEmpty;
  final fmt = DateFormat.yMMMd(l10n.localeName);
  final accepted = await context.showRoundDialog<bool>(
    title: changed ? l10n.virtErrCertChanged : l10n.remoteDesktopTrustCertificate,
    barrierDismiss: false,
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            changed
                ? l10n.remoteDesktopCertificateChangedTip
                : l10n.remoteDesktopCertificateUnverifiedTip,
          ),
          UIs.height13,
          if (source != null) SelectableText('${libL10n.addr}: $source'),
          SelectableText('SHA-256\n${cert.prettyFingerprint}'),
          if (changed) ...[
            UIs.height7,
            SelectableText(
              l10n.remoteDesktopPreviousCertificate(
                prettyCertFingerprint(previous),
              ),
            ),
          ],
          UIs.height7,
          SelectableText(l10n.remoteDesktopCertificateSubject(cert.subject)),
          SelectableText(l10n.remoteDesktopCertificateIssuer(cert.issuer)),
          SelectableText(
            l10n.remoteDesktopCertificateValidity(
              fmt.format(cert.startValidity),
              fmt.format(cert.endValidity),
            ),
          ),
          if (cert.isExpired) ...[
            UIs.height7,
            Text(
              l10n.bmcCertExpired,
              style: const TextStyle(color: StatePalette.warn),
            ),
          ],
        ],
      ),
    ),
    actions: [
      Btn.cancel(),
      Btn.text(
        text: changed
            ? l10n.remoteDesktopReplaceTrust
            : reconnects
            ? l10n.remoteDesktopTrustReconnect
            : l10n.certTrust,
        textStyle: changed ? UIs.textRed : null,
        onTap: () => context.popDialog(true),
      ),
    ],
  );
  return accepted == true;
}
