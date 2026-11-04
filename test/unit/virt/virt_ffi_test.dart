// sbm_virt::libvirt through FFI: the same fixtures as
// crates/sbm_virt/tests/libvirt.rs, so the bridge is shown to carry the
// parsers' output. Parsing behaviour itself is locked there.
// Build the native library first: cargo build -p sbm_ffi

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/src/rust/api/script.dart' as script;
import 'package:server_box/src/rust/api/virt.dart';
import 'package:server_box/src/rust/api/virt_view.dart';

import '../../helpers/rust_lib_helper.dart';

const _dir = 'crates/sbm_virt/tests/fixtures/libvirt';

String _fixture(String name) => File('$_dir/$name').readAsStringSync();

/// One `virsh` call's section as the scripts print it: marker, output, and
/// the exit-status line (`sbm_virt::libvirt::RC_PREFIX`).
String _section(String key, String body, [int rc = 0]) =>
    '${script.scriptSegmentMarker(key: key, custom: false)}\n$body\nSbVirtRc=$rc\n';

void main() {
  setUpAll(initRustLibForTest);

  test('overview fixture crosses as the view the parser made', () {
    final raw = [
      _section('virt.version', _fixture('version_libvirt11.txt')),
      _section('virt.list', _fixture('list_uuid_name.txt')),
      _section('virt.autostart', _fixture('list_autostart.txt')),
      _section('virt.persistent', _fixture('list_persistent.txt')),
      _section('virt.stats', _fixture('domstats.txt')),
    ].join();
    final view = LibvirtRates().view(raw: raw, atMs: 0, upload: false);
    final expected = jsonDecode(_fixture('overview.expected.json')) as Map<String, dynamic>;
    final domains = (expected['domains'] as List).cast<Map<String, dynamic>>();
    expect([for (final g in view.guests) g.name], [for (final d in domains) d['name']]);
    final odd = view.guests.last;
    expect(odd.name, 'it\'s-"odd"');
    expect(odd.state, GuestState.stopped);
    expect(odd.stateReason, 'failed');
  });

  test('permission error crosses as a typed exception', () async {
    final raw = _section('virt.version', _fixture('error_permission.txt'), 1);
    await expectLater(
      virtLibvirtProbe(raw: raw),
      throwsA(
        isA<VirtFfiError>()
            .having((e) => e.kind, 'kind', VirtErrorKind.permissionDenied)
            .having((e) => e.message, 'message', contains('Permission denied')),
      ),
    );
    expect(
      () => parseVirtAction(
        raw: _section('virt.action', _fixture('error_already_active.txt'), 1),
      ),
      throwsA(
        isA<VirtFfiError>().having(
          (e) => e.kind,
          'kind',
          VirtErrorKind.invalidState,
        ),
      ),
    );
    parseVirtAction(raw: _section('virt.action', "Domain 'x' started"));
  });
}
