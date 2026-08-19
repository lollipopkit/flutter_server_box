/// Trust-on-first-use for a TLS certificate, in the two halves the platform
/// forces it into.
///
/// SSH host keys are verified by an *async* callback, so the app can put the
/// question to the user from inside it (`HostKeyVerifier`). TLS gives no such
/// opening: `HttpClient.badCertificateCallback` and dio's `validateCertificate`
/// are both `bool Function(...)`, so nothing there can wait for an answer.
///
/// So the two halves are separated, which turns out to be the better shape
/// anyway:
///
/// - [fetchServerCert] is the *review* step, driven by the user from a settings
///   page. It opens a socket for no purpose but to read the certificate and
///   closes it again, having sent nothing.
/// - [PinnedCert.accepts] is the *enforcement* step, and answers with no
///   interaction at all. An unreviewed or changed certificate is refused, not
///   queried — by then there is a request waiting to go out.
///
/// Written against no particular caller: a BMC is the first user, and PVE and
/// the monitor agent could replace their accept-anything switches with this
/// without changing where either keeps its configuration.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';

/// SHA-256 of a certificate's DER form, lowercase hex.
///
/// Not `X509Certificate.sha1`, which is the only digest `dart:io` offers ready
/// made: SHA-1 has no business being the thing a trust decision rests on.
String certFingerprint(X509Certificate cert) =>
    sha256.convert(cert.der).toString();

/// A certificate as it is shown to someone deciding whether to trust it.
///
/// The fingerprint alone is unreadable, and a person asked to compare one
/// against a BMC's web UI needs the rest to know they are looking at the same
/// thing.
class CertInfo {
  const CertInfo({
    required this.fingerprint,
    required this.subject,
    required this.issuer,
    required this.startValidity,
    required this.endValidity,
  });

  CertInfo.of(X509Certificate cert)
    : fingerprint = certFingerprint(cert),
      subject = cert.subject,
      issuer = cert.issuer,
      startValidity = cert.startValidity,
      endValidity = cert.endValidity;

  final String fingerprint;
  final String subject;
  final String issuer;
  final DateTime startValidity;
  final DateTime endValidity;

  /// Whether the certificate is outside its own validity window.
  ///
  /// Worth showing rather than acting on: BMCs are frequently shipped with
  /// certificates that expired years ago, and refusing those would refuse most
  /// of the hardware this is for. The user is told and decides.
  bool get isExpired {
    final now = DateTime.now();
    return now.isBefore(startValidity) || now.isAfter(endValidity);
  }

  /// The fingerprint in the colon-separated form fingerprints are usually
  /// printed in, which is how a BMC's own web UI shows it.
  String get prettyFingerprint {
    final pairs = <String>[];
    for (var i = 0; i + 1 < fingerprint.length; i += 2) {
      pairs.add(fingerprint.substring(i, i + 2));
    }
    return pairs.join(':').toUpperCase();
  }
}

/// Reads the certificate [host]:[port] presents, without making a request.
///
/// `onBadCertificate` accepts unconditionally, which is the whole point: this
/// is the step whose *job* is to look at a certificate no CA vouches for. It is
/// safe because nothing is sent — the socket is destroyed as soon as the
/// handshake yields a certificate, so no credential can reach whatever
/// answered.
///
/// Throws whatever the connection threw. A BMC that is off, unreachable or not
/// speaking TLS is a different problem from one whose certificate is unknown,
/// and the caller has to be able to say which.
Future<CertInfo> fetchServerCert(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final socket = await SecureSocket.connect(
    host,
    port,
    timeout: timeout,
    onBadCertificate: (_) => true,
  );
  try {
    final cert = socket.peerCertificate;
    if (cert == null) {
      throw const TlsException('the server presented no certificate');
    }
    return CertInfo.of(cert);
  } finally {
    socket.destroy();
  }
}

/// The decision half: does this certificate match what was reviewed.
class PinnedCert {
  const PinnedCert(this.fingerprint);

  /// What the user accepted, or null if nothing has been reviewed.
  final String? fingerprint;

  bool get hasPin => fingerprint?.isNotEmpty == true;

  /// Whether [cert] is the one that was pinned.
  ///
  /// False when nothing is pinned, deliberately. The alternative — trusting
  /// whatever appears the first time a request happens to be made — is
  /// trust-on-first-*use*, where the use is a request already carrying a
  /// password. Reviewing is a step someone takes, not a side effect of a poll.
  ///
  /// A null [cert] is also false: it means the caller could not obtain one,
  /// and "no certificate" must never read as "matches".
  bool accepts(X509Certificate? cert) {
    final pinned = fingerprint;
    if (pinned == null || pinned.isEmpty || cert == null) return false;
    return _constantTimeEquals(pinned.toLowerCase(), certFingerprint(cert));
  }

  /// Compared without an early exit.
  ///
  /// A fingerprint is public, so this is not guarding a secret; it costs
  /// nothing and keeps the habit in a file whose whole subject is what to
  /// trust.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
