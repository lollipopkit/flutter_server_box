/// What the app will and will not accept from a BMC's TLS certificate.
///
/// The shape is forced by the platform: `HttpClient.badCertificateCallback`
/// and dio's `validateCertificate` are both synchronous, so nothing there can
/// ask the user anything. Reviewing is therefore a step someone takes
/// (`fetchServerCert`), and enforcement answers alone (`PinnedCert.accepts`).
///
/// The half worth locking down is the second one, because every way it could
/// be wrong is a way to accept the wrong certificate silently.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/cert_pin.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';

/// Enough of an [X509Certificate] to decide about: only `der` is read.
class _FakeCert implements X509Certificate {
  _FakeCert(this.der);

  @override
  final Uint8List der;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  final certA = _FakeCert(Uint8List.fromList([1, 2, 3, 4]));
  final certB = _FakeCert(Uint8List.fromList([1, 2, 3, 5]));
  final fpA = sha256.convert(certA.der).toString();

  group('certFingerprint', () {
    test('is SHA-256 of the DER form, lowercase hex', () {
      expect(certFingerprint(certA), fpA);
      expect(fpA, hasLength(64));
      expect(fpA, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('a one-byte difference is a different fingerprint', () {
      expect(certFingerprint(certA), isNot(certFingerprint(certB)));
    });
  });

  group('PinnedCert', () {
    test('accepts the certificate that was pinned', () {
      expect(PinnedCert(fpA).accepts(certA), isTrue);
    });

    test('refuses a different certificate', () {
      expect(PinnedCert(fpA).accepts(certB), isFalse);
    });

    test('refuses everything when nothing has been reviewed', () {
      // Not trust-on-first-*use*: the first use is a request already carrying
      // a password, so accepting whatever turns up there would hand it to
      // whatever turned up.
      expect(const PinnedCert(null).accepts(certA), isFalse);
      expect(const PinnedCert('').accepts(certA), isFalse);
    });

    test('refuses a null certificate even when something is pinned', () {
      // "Could not obtain one" must never read as "matches".
      expect(PinnedCert(fpA).accepts(null), isFalse);
    });

    test('compares case-insensitively, since the pin is stored as text', () {
      expect(PinnedCert(fpA.toUpperCase()).accepts(certA), isTrue);
    });

    test('a truncated pin does not match by prefix', () {
      // The comparison is length-checked first; a pin that is a prefix of the
      // real fingerprint must not pass
      expect(PinnedCert(fpA.substring(0, 32)).accepts(certA), isFalse);
    });

    test('hasPin distinguishes unreviewed from reviewed', () {
      expect(const PinnedCert(null).hasPin, isFalse);
      expect(const PinnedCert('').hasPin, isFalse);
      expect(PinnedCert(fpA).hasPin, isTrue);
    });
  });

  group('CertInfo', () {
    test('prints the fingerprint the way a BMC web UI does', () {
      final info = CertInfo(
        fingerprint: 'abcd1234',
        subject: '/CN=bmc',
        issuer: '/CN=bmc',
        startValidity: _epoch,
        endValidity: _epoch,
      );
      expect(info.prettyFingerprint, 'AB:CD:12:34');
    });

    test('an expired certificate is reported, not refused', () {
      final past = DateTime(2000);
      final info = CertInfo(
        fingerprint: 'ab',
        subject: '/CN=bmc',
        issuer: '/CN=bmc',
        startValidity: past,
        endValidity: past.add(const Duration(days: 1)),
      );
      // BMCs ship long-expired certificates; refusing those would refuse most
      // of the hardware this exists for, so the decision stays with the user
      expect(info.isExpired, isTrue);
      expect(PinnedCert(certFingerprint(certA)).accepts(certA), isTrue);
    });
  });

  group('BmcCfg', () {
    test('parses an address and defaults the port per scheme', () {
      const https = BmcCfg(addr: 'https://10.0.0.9', user: 'admin');
      expect(https.uri?.host, '10.0.0.9');
      expect(https.port, 443);

      const withPort = BmcCfg(addr: 'https://10.0.0.9:8443', user: 'admin');
      expect(withPort.port, 8443);

      const plain = BmcCfg(addr: 'http://10.0.0.9', user: 'admin');
      expect(plain.port, 80);
    });

    test('rejects what is not a usable address', () {
      for (final addr in ['', '10.0.0.9', 'ftp://10.0.0.9', 'not a url']) {
        expect(
          BmcCfg(addr: addr, user: 'admin').uri,
          isNull,
          reason: 'should not parse: $addr',
        );
      }
    });

    test('is complete on an address and an account, without a certificate', () {
      // Reviewing the certificate needs a connection, which needs these first
      const cfg = BmcCfg(addr: 'https://10.0.0.9', user: 'admin');
      expect(cfg.isComplete, isTrue);
      expect(cfg.certSha256, isNull);

      expect(const BmcCfg(addr: 'https://10.0.0.9', user: ' ').isComplete, isFalse);
      expect(const BmcCfg(addr: 'nope', user: 'admin').isComplete, isFalse);
    });

    test('copyWith can clear the pinned certificate', () {
      const pinned = BmcCfg(addr: 'https://a', user: 'u', certSha256: 'ab');
      expect(pinned.copyWith(certSha256: null).certSha256, isNull);
      // and leaves it alone when not named
      expect(pinned.copyWith(user: 'v').certSha256, 'ab');
    });

    test('survives a round trip, and omits what is unset', () {
      const cfg = BmcCfg(addr: 'https://a', user: 'u', certSha256: 'ab');
      expect(BmcCfg.fromJson(cfg.toJson()), cfg);
      expect(
        const BmcCfg(addr: 'https://a', user: 'u').toJson().containsKey('pwd'),
        isFalse,
      );
    });
  });
}

/// A stand-in for the validity dates these cases do not read. `DateTime`
/// cannot be `const`, which is why it is not written inline.
final _epoch = DateTime.utc(1970);
