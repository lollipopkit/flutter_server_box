// sbm_parser::virt through FFI: the same fixtures and expected JSON as
// crates/sbm_parser/tests/virt.rs, so the bridge is shown to carry the
// parsers' output unchanged. Parsing behaviour itself is locked there.
// Build the native library first: cargo build -p sbm_ffi

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/src/rust/api/script.dart' as script;
import 'package:server_box/src/rust/api/virt.dart';

import '../../helpers/rust_lib_helper.dart';

const _dir = 'crates/sbm_parser/tests/fixtures/virt';

String _fixture(String name) => File('$_dir/$name').readAsStringSync();

/// One `virsh` call's section as the scripts print it: marker, output, and
/// the exit-status line (`sbm_parser::virt::RC_PREFIX`).
String _section(String key, String body, [int rc = 0]) =>
    '${script.scriptSegmentMarker(key: key, custom: false)}\n$body\nSbVirtRc=$rc\n';

void main() {
  setUpAll(initRustLibForTest);

  test('overview fixture parses to the expected JSON', () async {
    final raw = [
      _section('virt.version', _fixture('version_libvirt11.txt')),
      _section('virt.list', _fixture('list_uuid_name.txt')),
      _section('virt.autostart', _fixture('list_autostart.txt')),
      _section('virt.persistent', _fixture('list_persistent.txt')),
      _section('virt.stats', _fixture('domstats.txt')),
    ].join();
    final json = jsonDecode(await parseVirtOverviewJson(raw: raw));
    expect(json, jsonDecode(_fixture('overview.expected.json')));
    final odd = (json['domains'] as List).last as Map<String, dynamic>;
    expect(odd['name'], 'it\'s-"odd"');
    expect(odd['state'], 'stopped');
    expect(odd['reason'], 'failed');
  });

  test('domain detail fixtures parse to the expected JSON', () async {
    final captured =
        _section('virt.display', _fixture('domdisplay_cirros_run.txt')) +
        _section('virt.xml', _fixture('dumpxml_cirros_run.xml'));
    expect(
      jsonDecode(await parseVirtDomainDetailJson(raw: captured)),
      jsonDecode(_fixture('detail_cirros_run.expected.json')),
    );
    final raw =
        _section('virt.display', _fixture('domdisplay_win11.txt')) +
        _section('virt.xml', _fixture('dumpxml_win11.xml'));
    final json = jsonDecode(await parseVirtDomainDetailJson(raw: raw));
    expect(json, jsonDecode(_fixture('detail_win11.expected.json')));
  });

  test('permission error crosses as a typed exception', () async {
    final raw = _section('virt.version', _fixture('error_permission.txt'), 1);
    await expectLater(
      parseVirtProbeJson(raw: raw),
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

  test('scripts quote the domain', () {
    final s = virtActionScript(
      action: VirtActionKind.forceStop,
      domain: "it's odd",
    );
    expect(s, contains("V destroy --domain 'it'\\''s odd'\n"));
    expect(virtOverviewScript(), contains('domstats --raw'));
    expect(
      virtConsoleCommand(domain: 'a b'),
      "virsh --connect qemu:///system console --force --domain 'a b'",
    );
  });
}
