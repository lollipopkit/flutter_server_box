import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/self_addr.dart';

/// Which of a machine's reported addresses places it.
///
/// The *parsing* — turning three platforms' three command formats into a list
/// — is `sbm_parser::common::parse_ips` and is tested there, against the real
/// output shapes. What is left on this side is the filter, and the filter is
/// what makes a deliberately format-blind parse safe: everything below is
/// something that reaches here and must not be treated as an answer.
void main() {
  group('what counts as an address that places a machine', () {
    test('a public one does', () {
      expect(
        SelfAddr.pick(['127.0.0.1', '192.168.1.42', '45.32.10.20'])?.address,
        '45.32.10.20',
      );
    });

    test('a dotted netmask does not', () {
      // `255.255.255.0` parses perfectly well as an address, and the upstream
      // parser keeps it. What refuses it is 240/4 being reserved — the filter
      // doing work the format-blind parse cannot.
      expect(SelfAddr.publicIn(['255.255.255.0']), isEmpty);
    });

    test('nor loopback, LAN, link-local or CGNAT', () {
      expect(
        SelfAddr.publicIn([
          '127.0.0.1',
          '10.0.0.7',
          '172.17.0.1',
          '192.168.1.42',
          '169.254.5.5',
          // Tailscale's range. Public space until RFC 6598 took it in 2012,
          // so a database old enough still places it — somewhere wrong.
          '100.101.102.103',
          '::1',
          'fe80::1',
          'fd00::1',
        ]),
        isEmpty,
      );
    });

    test('nor a documentation address', () {
      // TEST-NET-3 and the IPv6 documentation prefix, which turn up in copied
      // examples and in nothing reachable.
      expect(SelfAddr.publicIn(['203.0.113.4', '2001:db8::1']), isEmpty);
    });

    test('nor anything that is not an address at all', () {
      // The upstream parser only emits things that parsed, but this is fed
      // from a wire format an older or different agent also writes.
      expect(SelfAddr.publicIn(['', 'not an address', '1500']), isEmpty);
    });

    test('IPv4 wins on a dual-stack machine', () {
      // The bundled database has far more IPv4 records, so taking v6 would
      // turn a hit into a miss and gain nothing. v6 is listed first on purpose.
      const reported = ['2606:4700::1111', '45.32.10.20'];
      expect(SelfAddr.pick(reported)?.address, '45.32.10.20');
      expect(SelfAddr.publicIn(reported).first.address, '2606:4700::1111');
    });

    test('v6 is taken when it is all there is', () {
      expect(
        SelfAddr.pick(['10.0.0.7', '2606:4700::1111'])?.address,
        '2606:4700::1111',
      );
    });

    test('order is what the machine listed, and repeats are one', () {
      final found = SelfAddr.publicIn([
        '45.32.10.20',
        '8.8.8.8',
        '45.32.10.20',
      ]);
      expect(found.map((e) => e.address), ['45.32.10.20', '8.8.8.8']);
    });

    test('a machine behind NAT has no answer, and nothing crashes', () {
      expect(SelfAddr.pick(const []), isNull);
      expect(SelfAddr.pick(['192.168.1.42']), isNull);
    });
  });
}
