import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/iperf.dart';

void main() {
  test('normalizes structurally valid iperf hosts', () {
    expect(normalizeIperfHost('example.com'), 'example.com');
    expect(normalizeIperfHost('192.0.2.1'), '192.0.2.1');
    expect(normalizeIperfHost('[2001:db8::1]'), '2001:db8::1');
  });

  test('rejects malformed iperf hosts', () {
    for (final host in [
      '999.999.999.999',
      'a..b',
      '-example.com',
      'example-.com',
      '[not-an-ip]',
      'host name',
      'host;echo',
    ]) {
      expect(normalizeIperfHost(host), isNull, reason: host);
    }
  });

  test('builds a command that is safe for POSIX and cmd shells', () {
    expect(
      buildIperfClientCommand('2001:db8::1', '5201'),
      'iperf -c 2001:db8::1 -p 5201',
    );
    expect(isValidIperfPort('1'), isTrue);
    expect(isValidIperfPort('65535'), isTrue);
    expect(isValidIperfPort('0'), isFalse);
    expect(isValidIperfPort('65536'), isFalse);
  });
}
