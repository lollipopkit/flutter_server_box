/// The algorithm sets a server is offered, and the switch that picks one.
///
/// The failure this exists for is a handshake that dies at host-key
/// negotiation with `No matching host key algorithm`, because the daemon on the
/// other end only knows the SHA-1 `ssh-rsa` spelling. What is asserted here is
/// that a server which has not asked for the retired algorithms is proposed
/// exactly dartssh2's default, and that opting in appends them rather than
/// replacing anything — the order being the whole reason a current host never
/// falls through to them.
library;

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ssh_algorithms.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

void main() {
  const modern = SSHAlgorithms();
  const plain = SshCredential(ip: '10.0.0.1');
  const optedIn = SshCredential(ip: '10.0.0.1', allowLegacyAlgorithms: true);

  List<String> names(Iterable<Object?> algorithms) =>
      [for (final a in algorithms) (a as dynamic).name as String];

  test('a server without the switch is proposed the default set', () {
    final offered = SshAlgorithms.of(plain);
    expect(names(offered.kex), names(modern.kex));
    expect(names(offered.hostkey), names(modern.hostkey));
    expect(names(offered.cipher), names(modern.cipher));
    expect(names(offered.mac), names(modern.mac));
  });

  test('which no longer contains the retired spellings', () {
    expect(names(modern.hostkey), isNot(contains('ssh-rsa')));
    expect(names(modern.hostkey), isNot(contains('ssh-rsa-cert-v01@openssh.com')));
    expect(
      names(modern.kex),
      isNot(contains('diffie-hellman-group14-sha1')),
    );
    expect(names(modern.cipher), isNot(contains('aes256-cbc')));
    expect(names(modern.mac), isNot(contains('hmac-sha1')));
  });

  // #1783: a server whose only host key is a certificate.
  test('host certificates are offered, before the keys they certify', () {
    final hostkey = names(modern.hostkey);
    expect(
      hostkey,
      containsAll(const [
        'ssh-ed25519-cert-v01@openssh.com',
        'ecdsa-sha2-nistp256-cert-v01@openssh.com',
        'rsa-sha2-512-cert-v01@openssh.com',
      ]),
    );
    expect(
      hostkey.indexOf('ssh-ed25519-cert-v01@openssh.com'),
      lessThan(hostkey.indexOf('ssh-ed25519')),
    );
  });

  // OpenSSH's `order_hostkeyalgs`: what can be relied on goes first, unless
  // the first choice's key is already the one pinned.
  group('ordered by what is trusted for the host', () {
    bool cert(String n) => n.endsWith('-cert-v01@openssh.com');
    List<String> hostkey({bool ca = false, Set<String> pinned = const {}}) =>
        names(SshAlgorithms.of(
          plain,
          preferCertificates: ca,
          pinnedKeyTypes: pinned,
        ).hostkey);
    final base = names(modern.hostkey);

    test('nothing trusted: as it is', () {
      expect(hostkey(), base);
    });

    test('the first choice pinned: as it is, authority or not', () {
      expect(hostkey(pinned: {'ssh-ed25519'}), base);
      expect(hostkey(ca: true, pinned: {'ssh-ed25519'}), base);
    });

    test('another key pinned: it, and its certificate, first', () {
      final ordered = hostkey(pinned: {'rsa-sha2-512'});
      expect(ordered.take(2), [
        'rsa-sha2-512-cert-v01@openssh.com',
        'rsa-sha2-512',
      ]);
      expect(ordered.skip(2), [
        for (final n in base)
          if (n != 'rsa-sha2-512' && n != 'rsa-sha2-512-cert-v01@openssh.com') n,
      ]);
    });

    test('an authority: every certificate first, each half in its order', () {
      final ordered = hostkey(ca: true);
      final firstKey = ordered.indexWhere((n) => !cert(n));
      expect(firstKey, greaterThan(0));
      expect(ordered.take(firstKey), base.where(cert));
      expect(ordered.skip(firstKey), base.where((n) => !cert(n)));
    });

    test('only the host keys move', () {
      final ordered = SshAlgorithms.of(plain, preferCertificates: true);
      expect(names(ordered.kex), names(modern.kex));
      expect(names(ordered.cipher), names(modern.cipher));
      expect(names(ordered.mac), names(modern.mac));
    });
  });

  test('opting in appends them after the modern ones', () {
    final offered = SshAlgorithms.of(optedIn);

    // Every modern algorithm is still there, and still first, so a host that
    // offers one negotiates it and never reaches the tail.
    expect(
      names(offered.kex).take(modern.kex.length),
      names(modern.kex),
    );
    expect(
      names(offered.hostkey).take(modern.hostkey.length),
      names(modern.hostkey),
    );
    expect(
      names(offered.cipher).take(modern.cipher.length),
      names(modern.cipher),
    );
    expect(names(offered.mac).take(modern.mac.length), names(modern.mac));

    // The host key that motivated this is last, so it is only reached when the
    // server offers nothing newer.
    expect(names(offered.hostkey).last, 'ssh-rsa');
    expect(names(offered.hostkey), contains('ssh-rsa-cert-v01@openssh.com'));
    expect(
      names(offered.kex),
      containsAll(const [
        'diffie-hellman-group14-sha1',
        'diffie-hellman-group-exchange-sha1',
        'diffie-hellman-group1-sha1',
      ]),
    );
    expect(names(offered.cipher), containsAll(const ['aes256-cbc', 'aes128-cbc']));
    expect(
      names(offered.mac),
      containsAll(const [
        'hmac-sha1',
        'hmac-md5',
        'hmac-sha2-256-96',
        'hmac-sha2-512-96',
      ]),
    );
  });

  test('the two switches are different sets, not the same list twice', () {
    expect(
      names(SshAlgorithms.of(plain).hostkey),
      isNot(names(SshAlgorithms.of(optedIn).hostkey)),
    );
  });
}
