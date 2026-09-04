import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/private_address.dart';

/// The gate in front of every geo lookup.
///
/// Both directions matter and they fail differently. A public address wrongly
/// called private is a server the globe silently will not draw. A private one
/// wrongly called public is a name sent to a resolver and a request made that
/// the user did not ask for — and it can never produce a right answer, so
/// nothing downstream would notice.
void main() {
  group('IPv4 that only one network can reach', () {
    const private = [
      '0.0.0.0',
      '0.1.2.3',
      '10.0.0.1',
      '10.255.255.255',
      '127.0.0.1',
      '127.1.2.3',
      // Carrier-grade NAT, RFC 6598. Public space until 2012, so a database
      // old enough still places it.
      '100.64.0.1',
      '100.127.255.255',
      '169.254.1.1',
      '172.16.0.1',
      '172.31.255.255',
      '192.0.0.8',
      '192.0.2.1',
      // 6to4 relay anycast, RFC 7526. Every relay answered on this address, so
      // it never identified a place; the scheme was deprecated in 2015.
      '192.88.99.1',
      '192.88.99.255',
      '192.168.0.1',
      '198.18.0.1',
      '198.19.255.255',
      '198.51.100.1',
      '203.0.113.1',
      '224.0.0.1',
      '239.255.255.255',
      '240.0.0.1',
      '255.255.255.255',
    ];
    for (final host in private) {
      test(host, () => expect(isPrivateHost(host), isTrue));
    }
  });

  group('IPv4 that is somewhere', () {
    const public = [
      '1.1.1.1',
      '8.8.8.8',
      // Just outside each range above, which is where an inclusive bound put
      // one address in the wrong class and nothing said so.
      '9.255.255.255',
      '11.0.0.0',
      '100.63.255.255',
      '100.128.0.0',
      '126.255.255.255',
      '128.0.0.1',
      '169.253.255.255',
      '169.255.0.0',
      '172.15.255.255',
      '172.32.0.0',
      '192.0.1.255',
      '192.0.3.0',
      '192.167.255.255',
      '192.169.0.0',
      '198.17.255.255',
      '198.20.0.0',
      '198.51.99.255',
      '203.0.112.255',
      '223.255.255.255',
    ];
    for (final host in public) {
      test(host, () => expect(isPrivateHost(host), isFalse));
    }
  });

  group('IPv6', () {
    const private = [
      '::',
      '::1',
      'fc00::1',
      'fd12:3456::1',
      'fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
      'fe80::1',
      'febf::1',
      'ff02::1',
      '2001:db8::1',
      // A zone index is not part of the address, and its presence already says
      // the address is link-local.
      'fe80::1%en0',
      // Brackets are how a literal appears in a URL, and `Uri.host` keeps them.
      '[::1]',
    ];
    for (final host in private) {
      test('$host is private', () => expect(isPrivateHost(host), isTrue));
    }

    const public = [
      '2001:4860:4860::8888',
      '2606:4700:4700::1111',
      '2001:db9::1',
      '2001:db7:ffff::1',
      // fe80::/10 ends at febf; fec0 was site-local and was deprecated back
      // into ordinary space.
      'fec0::1',
      '[2606:4700::1]',
    ];
    for (final host in public) {
      test('$host is public', () => expect(isPrivateHost(host), isFalse));
    }

    test('an IPv4 address carried inside a v6 one keeps its v4 answer', () {
      // What `InternetAddress.lookup` returns on a dual-stack host. Without
      // this, a LAN server reached over v6 reads as public.
      expect(isPrivateHost('::ffff:192.168.1.1'), isTrue);
      expect(isPrivateHost('::ffff:8.8.8.8'), isFalse);
    });
  });

  /// The unwrap on its own, because it is not only this file's business.
  ///
  /// `isPrivateAddress` has always done it; every *other* reader of an address
  /// did not, and each of them fails silently — a lookup asks the IPv6 file for
  /// a key whose leading bits are zero and answers nothing, and a dual-stack
  /// tie-break picks the wrong one because `type` says IPv6.
  group('unwrapping a v4-mapped address', () {
    test('answers the v4 address it carries', () {
      final unwrapped = unwrapV4Mapped(InternetAddress('::ffff:8.8.8.8'));
      expect(unwrapped.type, InternetAddressType.IPv4);
      expect(unwrapped.address, '8.8.8.8');
      expect(unwrapped.rawAddress, [8, 8, 8, 8]);
    });

    test('leaves a real v6 address alone', () {
      final addr = InternetAddress('2620:fe::fe');
      expect(unwrapV4Mapped(addr), addr);
      expect(unwrapV4Mapped(addr).type, InternetAddressType.IPv6);
    });

    test('leaves a v4 address alone', () {
      final addr = InternetAddress('8.8.8.8');
      expect(unwrapV4Mapped(addr), addr);
    });

    test('is not fooled by a v6 address that merely starts with zeros', () {
      // `::8.8.8.8` is v4-*compatible*, not v4-mapped: no `ffff` marker, and
      // it is a deprecated form that means something else.
      final addr = InternetAddress('::0.0.0.1');
      expect(unwrapV4Mapped(addr).type, InternetAddressType.IPv6);
    });
  });

  group('names', () {
    const private = [
      'localhost',
      'nas',
      'router',
      'MYSERVER',
      'printer.local',
      'host.home.arpa',
      'db.internal',
      'gateway.lan',
      'thing.home',
      'app.corp',
      'wiki.intranet',
      'a.localdomain',
      'x.test',
      'x.invalid',
      'x.example',
      // A trailing dot makes a name fully qualified and is not part of it.
      'printer.local.',
      '',
      '   ',
    ];
    for (final host in private) {
      test('"$host" is private', () => expect(isPrivateHost(host), isTrue));
    }

    const public = [
      'example.com',
      'server.example.com',
      'localhost.example.com',
      // The suffix has to be a whole label: `notlocal` does not end in
      // `.local`. A bare `notlocal` is not here — it has no dot, so the
      // single-label rule reaches it first, which is the right answer for a
      // different reason.
      'x.notlocal',
      'mylan.net',
    ];
    for (final host in public) {
      test('"$host" is public', () => expect(isPrivateHost(host), isFalse));
    }

    test('a single label is private even when it looks routable', () {
      // `com` resolves for nobody; whatever answers a bare label is the
      // resolver on this network, which is the whole point.
      expect(isPrivateHost('com'), isTrue);
    });
  });

  test('the parsed form agrees with the textual one', () {
    expect(isPrivateAddress(InternetAddress('10.1.2.3')), isTrue);
    expect(isPrivateAddress(InternetAddress('1.1.1.1')), isFalse);
    expect(isPrivateAddress(InternetAddress('fd00::1')), isTrue);
    expect(isPrivateAddress(InternetAddress('2606:4700::1111')), isFalse);
  });
}
