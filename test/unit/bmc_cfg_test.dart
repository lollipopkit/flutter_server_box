import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';

/// The app's own BMC config: how an address is parsed and when a record counts
/// as usable. The protocol side moved to `package:redfish`, which knows nothing
/// about how this app stores anything.
void main() {
  group('BmcCfg', () {
    test('parses an address and defaults the port per scheme', () {
      const https = BmcCfg(addr: 'https://10.0.0.9');
      expect(https.uri?.host, '10.0.0.9');
      expect(https.port, 443);

      const withPort = BmcCfg(addr: 'https://10.0.0.9:8443');
      expect(withPort.port, 8443);

      const plain = BmcCfg(addr: 'http://10.0.0.9');
      expect(plain.port, 80);
    });

    test('rejects what is not a usable address', () {
      for (final addr in ['', '10.0.0.9', 'ftp://10.0.0.9', 'not a url']) {
        expect(
          BmcCfg(addr: addr).uri,
          isNull,
          reason: 'should not parse: $addr',
        );
      }
    });

    test('is complete on an address and an account, without a certificate', () {
      // Reviewing the certificate needs a connection, which needs these first
      const cfg = BmcCfg(addr: 'https://10.0.0.9', credId: 'cred-1');
      expect(cfg.isComplete, isTrue);
      expect(cfg.certSha256, isNull);

      // An address with no account names a device nothing can log in to
      expect(const BmcCfg(addr: 'https://10.0.0.9').isComplete, isFalse);
      // and an account against an address that is not one is no better
      expect(const BmcCfg(addr: 'nope', credId: 'cred-1').isComplete, isFalse);
    });

    test('copyWith can clear the pinned certificate', () {
      const pinned = BmcCfg(addr: 'https://a', certSha256: 'ab');
      expect(pinned.copyWith(certSha256: null).certSha256, isNull);
      // and leaves it alone when not named
      expect(pinned.copyWith(credId: 'v').certSha256, 'ab');
      // clearing the account is sayable too, and separate from clearing the pin
      const withCred = BmcCfg(addr: 'https://a', credId: 'c');
      expect(withCred.copyWith(credId: null).credId, isNull);
    });

    test('survives a round trip, and omits what is unset', () {
      const cfg = BmcCfg(addr: 'https://a', certSha256: 'ab');
      expect(BmcCfg.fromJson(cfg.toJson()), cfg);
      expect(
        const BmcCfg(addr: 'https://a').toJson().containsKey('credId'),
        isFalse,
      );
    });
  });
}
