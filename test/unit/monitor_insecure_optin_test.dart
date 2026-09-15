import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';

void main() {
  group('needsInsecureOptIn', () {
    test('plaintext away from loopback needs the opt-in', () {
      expect(
        const MonitorHttpCredential(addr: 'http://10.0.0.1:3770')
            .needsInsecureOptIn,
        isTrue,
      );
      // The address the app actually reaches an OrbStack VM on.
      expect(
        const MonitorHttpCredential(addr: 'http://[fd07::1]:3770')
            .needsInsecureOptIn,
        isTrue,
      );
    });

    test('but https, loopback and an existing opt-in do not', () {
      for (final cred in [
        const MonitorHttpCredential(addr: 'https://10.0.0.1:3770'),
        const MonitorHttpCredential(addr: 'http://localhost:3770'),
        const MonitorHttpCredential(addr: 'http://127.0.0.1:3770'),
        const MonitorHttpCredential(
          addr: 'http://10.0.0.1:3770',
          allowInsecure: true,
        ),
      ]) {
        expect(cred.needsInsecureOptIn, isFalse, reason: cred.addr);
      }
    });

    test('allowingInsecure changes that and nothing else', () {
      const before = MonitorHttpCredential(
        addr: 'http://10.0.0.1:3770',
        user: 'admin',
        pwd: 'secret',
        ignoreCert: true,
      );
      final after = before.allowingInsecure();

      expect(after.allowInsecure, isTrue);
      expect(after.needsInsecureOptIn, isFalse);
      expect(after.addr, before.addr);
      expect(after.user, before.user);
      expect(after.pwd, before.pwd);
      expect(after.ignoreCert, before.ignoreCert);
      // A changed credential is what makes `Spi.shouldReconnect` fire, which
      // is what reconnects after the one-tap fix.
      expect(after, isNot(before));
    });
  });
}
