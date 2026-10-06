// The iperf host/port rules and the command they build now live in
// `sbm_parser::iperf`; this drives them through the FFI the page itself uses.
// The Rust side has its own cases (crates/sbm_parser/src/iperf.rs).
//
// Build the native library first: cargo build -p sbm_ffi

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/src/rust/api/iperf.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  test('normalizes structurally valid iperf hosts', () {
    expect(ffi.iperfNormalizeHost(raw: 'example.com'), 'example.com');
    expect(ffi.iperfNormalizeHost(raw: '192.0.2.1'), '192.0.2.1');
    expect(ffi.iperfNormalizeHost(raw: '[2001:db8::1]'), '2001:db8::1');
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
      expect(ffi.iperfNormalizeHost(raw: host), isNull, reason: host);
    }
  });

  test('refuses a host with a shell metacharacter', () {
    for (final host in ['a;b', r'$(id)', '`id`', 'a\nb', 'a b', '-leading']) {
      expect(ffi.iperfNormalizeHost(raw: host), isNull, reason: host);
    }
  });

  test('builds a command that is safe for POSIX and cmd shells', () {
    expect(
      ffi.iperfClientCommand(host: '2001:db8::1', port: 5201),
      'iperf -c 2001:db8::1 -p 5201',
    );
    expect(ffi.iperfValidPort(raw: '1'), 1);
    expect(ffi.iperfValidPort(raw: '65535'), 65535);
    expect(ffi.iperfValidPort(raw: '0'), isNull);
    expect(ffi.iperfValidPort(raw: '65536'), isNull);
  });
}
