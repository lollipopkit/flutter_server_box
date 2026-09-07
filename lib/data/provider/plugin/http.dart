import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// What a plugin asked for, and what it got. PLUGINS.md section 4.3.
typedef PluginHttpResult = ({
  int status,
  Map<String, String> headers,
  String body,
  String bodyEncoding,
  Map<String, Object?>? cert,
});

/// `sb.http.fetch`, and the certificate rules it exists to enforce.
///
/// **The pin is the whole trust decision.** The client is built with no
/// trusted roots at all, so `badCertificateCallback` runs on every handshake
/// and is the only thing that can accept one — a chain that a real CA vouches
/// for is refused exactly like a self-signed one unless it is the certificate
/// that was reviewed. Anything less would mean a plugin naming a public CA's
/// certificate for a host it does not own, which is the attack pinning is for.
///
/// That is also why an absent pin refuses rather than falls back to ordinary
/// validation: the hardware this is first for — a BMC — ships certificates no
/// CA has ever seen, so "valid chain" and "the right machine" have nothing to
/// do with each other there.
///
/// The review half is [probeCert], which reads a certificate and sends
/// nothing. It cannot be a callback: TLS verification is synchronous and there
/// is no opening to ask a user from inside it. `sbm_plugin::scope` refuses a
/// probe carrying a body or headers, which is what makes accepting any
/// certificate there safe.
abstract final class PluginHttp {
  /// Anything larger is refused rather than held.
  ///
  /// A plugin runs in an interpreter with a memory ceiling, and the body
  /// crosses the FFI boundary as one string on the way in. A Redfish document
  /// — the reason this exists — is tens of kilobytes.
  static const maxBodyBytes = 8 * 1024 * 1024;

  static const defaultTimeout = Duration(seconds: 30);

  /// Reads the certificate [host]:[port] presents, having sent nothing.
  ///
  /// The socket is destroyed as soon as the handshake yields one, so no
  /// credential can reach whatever answered.
  static Future<PluginHttpResult> probe(
    String host,
    int port, {
    Duration timeout = defaultTimeout,
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
        throw const TlsException('the peer presented no certificate');
      }
      return (
        // Nothing was requested, so there is no status to report. The plugin
        // is told to read `cert` by the presence of this being 0.
        status: 0,
        headers: const <String, String>{},
        body: '',
        bodyEncoding: 'utf8',
        cert: describeCert(cert),
      );
    } finally {
      socket.destroy();
    }
  }

  /// One request, refused unless the peer is [pinSha256].
  ///
  /// [pinSha256] is required and checked before a byte of the request exists —
  /// a password must not reach a certificate nobody vouched for. A plain
  /// `http://` URL carries no certificate and so cannot be pinned; it is
  /// allowed, because a plugin talking to `127.0.0.1` over a forwarded port is
  /// a real case and the address list already said which hosts it may reach.
  static Future<PluginHttpResult> fetch({
    required String url,
    String method = 'GET',
    Map<String, String> headers = const {},
    String? body,
    String bodyEncoding = 'utf8',
    String? pinSha256,
    Duration timeout = defaultTimeout,
  }) async {
    final uri = Uri.parse(url);
    final tls = uri.scheme == 'https';
    if (tls && (pinSha256 == null || pinSha256.isEmpty)) {
      throw const TlsException(
        'https needs `pinSha256`: review the certificate with `probeCert` '
        'first',
      );
    }

    // No trusted roots, so every certificate reaches the callback and the pin
    // is the only thing that can accept one.
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = timeout
      ..badCertificateCallback = (cert, _, _) => _matches(pinSha256, cert);
    try {
      final request = await client
          .openUrl(method.toUpperCase(), uri)
          .timeout(timeout);
      // Off, so a redirect cannot move a pinned request to another host — the
      // address list was checked against the URL the plugin named, and a 3xx
      // is an answer the plugin gets to see and decide about.
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (body != null && body.isNotEmpty) {
        request.add(
          bodyEncoding == 'base64' ? base64Decode(body) : utf8.encode(body),
        );
      }

      final response = await request.close().timeout(timeout);
      final bytes = await _readCapped(response);
      final collected = <String, String>{};
      response.headers.forEach((name, values) {
        collected[name] = values.join(', ');
      });

      // Decoded as text where it is text, which is nearly always: base64 costs
      // an interpreter something on every byte, and a Redfish document is
      // JSON. Undecodable bytes fall back rather than fail.
      String out;
      String encoding;
      try {
        out = utf8.decode(bytes);
        encoding = 'utf8';
      } on FormatException {
        out = base64Encode(bytes);
        encoding = 'base64';
      }

      final cert = response.certificate;
      return (
        status: response.statusCode,
        headers: collected,
        body: out,
        bodyEncoding: encoding,
        cert: cert == null ? null : describeCert(cert),
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<int>> _readCapped(HttpClientResponse response) async {
    final out = <int>[];
    await for (final chunk in response) {
      out.addAll(chunk);
      if (out.length > maxBodyBytes) {
        throw const HttpException('the answer is larger than the limit');
      }
    }
    return out;
  }

  /// SHA-256 of the DER form, lowercase hex.
  ///
  /// Not `X509Certificate.sha1`, the only digest `dart:io` offers ready made:
  /// SHA-1 has no business being what a trust decision rests on.
  static String fingerprint(X509Certificate cert) =>
      sha256.convert(cert.der).toString();

  /// Compared without an early exit.
  ///
  /// A fingerprint is public, so this guards no secret; it costs nothing and
  /// keeps the habit where the subject is what to trust.
  static bool _matches(String? pinned, X509Certificate? cert) {
    if (pinned == null || pinned.isEmpty || cert == null) return false;
    final a = pinned.toLowerCase();
    final b = fingerprint(cert);
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// A certificate as it is shown to somebody deciding whether to trust it.
  ///
  /// The fingerprint alone is unreadable, and a person comparing one against a
  /// BMC's own web interface needs the rest to know they are looking at the
  /// same thing.
  static Map<String, Object?> describeCert(X509Certificate cert) {
    final now = DateTime.now();
    return {
      'sha256': fingerprint(cert),
      'subject': cert.subject,
      'issuer': cert.issuer,
      'notBefore': cert.startValidity.toUtc().toIso8601String(),
      'notAfter': cert.endValidity.toUtc().toIso8601String(),
      // Worth showing rather than acting on: BMCs are routinely shipped with
      // certificates that expired years ago, and refusing those would refuse
      // most of the hardware this is for.
      'expired':
          now.isBefore(cert.startValidity) || now.isAfter(cert.endValidity),
    };
  }
}
