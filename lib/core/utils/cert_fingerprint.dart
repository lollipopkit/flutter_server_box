import 'dart:io' show X509Certificate;

import 'package:server_box/src/rust/api/bmc.dart' show CertInfo, certFingerprint, certInfoFromDer;

/// A certificate fingerprint stored as bare hex (a pin: `BmcCfg.certSha256`,
/// `PveConfig.certSha256`) in the colon-separated upper-case form
/// certificates are usually shown in — how PVE's and a BMC's own web UIs
/// print it, and what `CertInfo.prettyFingerprint` gives for one just
/// presented. One already in that form is only upper-cased.
String prettyCertFingerprint(String hex) {
  if (hex.contains(':')) return hex.toUpperCase();
  final pairs = <String>[
    for (var i = 0; i + 1 < hex.length; i += 2) hex.substring(i, i + 2),
  ];
  return pairs.join(':').toUpperCase();
}

/// [cert] as the dialogs show it: read by `sbm_redfish`, or from what Dart's
/// own parse gives when that cannot read it.
CertInfo certInfoOf(X509Certificate cert) =>
    certInfoFromDer(der: cert.der) ??
    CertInfo(
      fingerprint: certFingerprint(der: cert.der),
      subject: cert.subject,
      issuer: cert.issuer,
      notBefore: cert.startValidity.millisecondsSinceEpoch ~/ 1000,
      notAfter: cert.endValidity.millisecondsSinceEpoch ~/ 1000,
    );
