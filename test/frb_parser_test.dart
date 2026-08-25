// sbm_parser FFI integration tests:
// verify binding loading and the JSON assembly contract. Parsing behavior itself
// is locked by crates/sbm_parser/tests/dart_compat.rs (same fixtures and expectations).
// Build the native library first: cargo build -p sbm_ffi

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/src/rust/api/parser.dart';
import 'package:server_box/src/rust/api/script.dart' as script;

import 'rust_lib_helper.dart';

const _cpuRaw = '''cpu  18232538 52837 5772391 334460731 247294 0 134107 0 0 0
cpu0  1823253 5283 577239 33446073 24729 0 13410 0 0 0''';

const _memRaw = '''MemTotal:       32768 kB
MemFree:        16384 kB
MemAvailable:   24576 kB
SwapTotal:      2097148 kB
SwapFree:       1048574 kB''';

const _netRaw = '''Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 45929941  269112    0    0    0     0          0         0 45929941  269112    0    0    0     0       0          0
  eth0: 48481023  505772    0    0    0     0          0         0 36002262  202307    0    0    0     0       0          0''';

const _dfRaw = '''Filesystem     1K-blocks     Used Available Use% Mounted on
udev              864088        0    864088   0% /dev
tmpfs             176724      688    176036   1% /run
/dev/vda3       40910528 18067948  20951380  47% /
/dev/vda2         192559    11807    180752   7% /boot/efi
''';

const _connRaw =
    'Tcp: RtoAlgorithm RtoMin RtoMax MaxConn ActiveOpens PassiveOpens AttemptFails EstabResets CurrEstab InSegs OutSegs RetransSegs InErrs OutRsts InCsumErrors\n'
    'Tcp: 1 200 120000 -1 11 22 33 44 55 66 77 88 99 111 222';

void main() {
  setUpAll(initRustLibForTest);

  Future<Map<String, dynamic>> parseViaFfi(Map<String, String> raw) async {
    final json = await parseStatusJson(
      system: 'linux',
      raw: raw,
      tempDivisor: 1000.0,
    );
    return jsonDecode(json) as Map<String, dynamic>;
  }

  test('cpu section', () async {
    final cpu = (await parseViaFfi({'cpu': _cpuRaw}))['cpu'] as List;
    expect(cpu.length, 2);
    expect(cpu[0]['id'], 'cpu');
    expect(cpu[0]['user'], 18232538);
    expect(cpu[1]['id'], 'cpu0');
    expect(cpu[1]['idle'], 33446073);
  });

  test('memory/swap section', () async {
    final status = await parseViaFfi({'mem': _memRaw});
    expect(status['mem']['total'], 32768);
    expect(status['mem']['avail'], 24576);
    expect(status['swap']['total'], 2097148);
    expect(status['swap']['free'], 1048574);
  });

  test('net section', () async {
    final net = (await parseViaFfi({'net': _netRaw}))['net'] as List;
    expect(net.length, 2);
    expect(net[0]['device'], 'lo');
    expect(net[1]['device'], 'eth0');
    expect(net[1]['rx_bytes'], 48481023);
    expect(net[1]['tx_bytes'], 36002262);
  });

  test('disk section (df fallback)', () async {
    final disks = (await parseViaFfi({'disk': _dfRaw}))['disks'] as List;
    // vda3, vda2; tmpfs and the kernel mounts (udev on /dev) excluded
    expect(disks.length, 2);
    expect(disks.any((d) => d['mount'] == '/dev'), isFalse);
    final root = disks.firstWhere((d) => d['mount'] == '/');
    expect(root['path'], '/dev/vda3');
    expect(root['used_percent'], 47);
    expect(root['size'], 40910528);
  });

  test('conn section', () async {
    final conn = (await parseViaFfi({'conn': _connRaw}))['conn'];
    expect(conn['max_conn'], -1);
    expect(conn['fail'], 33);
  });

  test('temps honors tempDivisor', () async {
    const types = '/sys/class/thermal/thermal_zone0/x86_pkg_temp';
    final milli = await parseStatusJson(
      system: 'linux',
      raw: {'tempType': types, 'tempVal': '45000'},
      tempDivisor: 1000.0,
    );
    expect(jsonDecode(milli)['temps']['x86_pkg_temp'], 45.0);
    final celsius = await parseStatusJson(
      system: 'linux',
      raw: {'tempType': types, 'tempVal': '45'},
      tempDivisor: 1.0,
    );
    expect(jsonDecode(celsius)['temps']['x86_pkg_temp'], 45.0);
  });

  test('uptime/sys/host section', () async {
    final status = await parseViaFfi({
      'uptime':
          '19:39:15 up 61 days, 18:16,  1 user,  load average: 0.00, 0.00, 0.00',
      'sys': 'PRETTY_NAME="Ubuntu 22.04.3 LTS"\n',
      'host': ' myhost \n',
    });
    expect(status['uptime'], '61 days, 18:16');
    expect(status['sys'], 'Ubuntu 22.04.3 LTS');
    expect(status['host'], 'myhost');
  });

  // The two keys `ServerStatus.osId`/`osIdLike` are read out of, which the app
  // takes from this JSON by name — a rename on the Rust side would otherwise
  // show up as marks silently reverting to the prose match.
  test('sys section carries the os-release identifiers', () async {
    final status = await parseViaFfi({
      'sys':
          'ID=linuxmint\nID_LIKE="ubuntu debian"\nPRETTY_NAME="Linux Mint 21.3"\n',
    });
    expect(status['os_id'], 'linuxmint');
    expect(status['os_id_like'], ['ubuntu', 'debian']);
    expect(status['sys'], 'Linux Mint 21.3');
  });

  test('batteries/sensors/gpu/smart sections', () async {
    final battery = await File(
      'crates/sbm_parser/tests/fixtures/power_supply.txt',
    ).readAsString();
    final sensors = await File(
      'crates/sbm_parser/tests/fixtures/sensors1.txt',
    ).readAsString();
    final nvidia = await File(
      'crates/sbm_parser/tests/fixtures/nvidia.xml',
    ).readAsString();
    final smart = await File(
      'crates/sbm_parser/tests/fixtures/smartctl.json',
    ).readAsString();

    final status = await parseViaFfi({
      'battery': battery,
      'sensors': sensors,
      'nvidia': nvidia,
      'diskSmart': smart,
    });

    // The Linux branch collects Li-poly batteries only
    expect((status['batteries'] as List).length, 1);
    expect(status['batteries'][0]['percent'], 73);
    expect((status['sensors'] as List).length, 4);
    expect(status['sensors'][0]['device'], 'coretemp-isa-0000');
    expect((status['nvidia'] as List).length, 4);
    final smartList = status['disk_smart'] as List;
    expect(smartList.length, 1);
    expect(smartList[0]['device'], '/dev/sda');
    expect(smartList[0]['temperature'], 35.0);
  });

  test('diskio section', () async {
    const raw =
        '   7       0 loop0 55 0 2170 42 0 0 0 0 0 80 42 0 0 0 0 0 0\n'
        ' 259       0 nvme0n1 1234 0 567890 100 4321 0 98765 200 0 300 400 0 0 0 0 0 0';
    final diskio = (await parseViaFfi({'diskio': raw}))['diskio'] as List;
    expect(diskio.length, 1); // loop skipped
    expect(diskio[0]['dev'], 'nvme0n1');
    expect(diskio[0]['sectors_read'], 567890);
  });

  test('windows net speed delta', () {
    const raw = '''[
      [{"Name": "Ethernet", "BytesReceivedPersec": 1000, "BytesSentPersec": 500, "Timestamp_Sys100NS": 10000000}],
      [{"Name": "Ethernet", "BytesReceivedPersec": 3000, "BytesSentPersec": 1500, "Timestamp_Sys100NS": 20000000}]
    ]''';
    final speeds = jsonDecode(parseWindowsNetSpeedJson(raw: raw)) as List;
    expect(speeds.length, 1);
    expect(speeds[0]['name'], 'Ethernet');
    expect(speeds[0]['rx'], 2000.0);
    expect(speeds[0]['tx'], 1000.0);
  });

  test('command specs cover linux/bsd/windows', () {
    for (final system in ['linux', 'bsd', 'windows']) {
      final specs = commandSpecs(system: system);
      expect(specs, isNotEmpty, reason: system);
      expect(specs.map((s) => s.key), contains('cpu'));
    }
  });

  test('buildScript smoke via FFI', () {
    final unix = script.buildScript(
      system: 'linux',
      disabled: [],
      buildNumber: 'test',
    );
    expect(unix, startsWith('#!/bin/sh'));
    expect(unix, contains('SbStatus() {'));
    expect(unix, contains('case \$1 in'));

    final win = script.buildScript(
      system: 'windows',
      disabled: [],
      buildNumber: 'test',
    );
    expect(win, contains('function SbStatus {'));
    expect(win, contains('switch (\$args[0])'));
  });

  test('the custom-command installer writes files, not commands', () {
    // The whole point of the move: what a user typed never reaches a shell
    // this app generated. It travels encoded and lands in a file.
    final install = script.installCustomCmdsCommand(
      system: 'linux',
      cmds: [script.CustomCmd(name: 'probe', cmd: 'rm -rf / #')],
    );
    expect(install, isNot(contains('rm -rf /')));
    expect(install, contains('custom_cmds'));
    // Written aside and moved, so a poll sees one set or the other.
    expect(install, contains('.new'));
    // Under the user's home, not beside the script: the script's directory
    // defaults to a temp one and moves when that is unwritable, and these
    // files are the only copy of what the user typed.
    expect(install, contains(r'$HOME/.config/server_box/custom_cmds'));
  });

  test('the editor reads back what the installer wrote', () {
    // The two halves of the editor, checked against each other: what the
    // listing script prints is what the parser turns back into commands. A
    // directory that does not exist is a different answer from an empty one —
    // the migration seeds the first and must leave the second alone.
    final read = script.readCustomCmdsCommand(system: 'linux');
    expect(read, contains(r'$HOME/.config/server_box/custom_cmds'));
    expect(read, contains('base64'));

    final listing = [
      'SrvBoxCusCmdDir',
      // 00100_<base64url of 'probe'> <base64 of the command>
      '00100_${base64Url.encode(utf8.encode('probe'))} '
          '${base64.encode(utf8.encode('echo hi\necho there'))}',
      '',
    ].join('\n');
    final parsed = script.parseCustomCmdsListing(raw: listing);
    expect(parsed, isNotNull);
    expect(parsed!.length, 1);
    expect(parsed.first.name, 'probe');
    expect(parsed.first.cmd, 'echo hi\necho there');

    expect(script.parseCustomCmdsListing(raw: ''), isNull);
    expect(script.parseCustomCmdsListing(raw: 'SrvBoxCusCmdDir\n'), isEmpty);
  });

  test('parseScriptSegments round-trip via FFI', () async {
    expect(
      script.containsScriptSegment(raw: 'SrvBoxSep.time\nnot a marker'),
      isFalse,
    );

    final raw = [
      script.scriptSegmentMarker(key: 'time', custom: false), '123',
      script.scriptSegmentMarker(key: 'x', custom: true), 'hello',
      // A custom command named after a built-in section, plus output that
      // looks like an unencoded marker
      script.scriptSegmentMarker(key: 'time', custom: true), 'SrvBoxSep.host',
      '',
    ].join('\n');

    expect(script.containsScriptSegment(raw: raw), isTrue);
    expect(script.containsStatusSegment(raw: raw), isTrue);
    expect(
      script.containsStatusSegment(
        raw: '${script.scriptSegmentMarker(key: 'x', custom: true)}\nhello',
      ),
      isFalse,
    );

    final segments = await script.parseScriptSegments(raw: raw);
    final map = {for (final s in segments) s.key: s.value};
    final customX = script.customResultKey(name: 'x');
    final customTime = script.customResultKey(name: 'time');
    expect(map['time'], '123');
    expect(map[customX], 'hello');
    // The namespaced key is what the app reads, and it did not clobber 'time'
    expect(map[customTime], 'SrvBoxSep.host');
    expect(script.customResultName(key: customX), 'x');
    expect(script.customResultName(key: 'time'), isNull);
    // Order is preserved, which is the only record of how the user arranged
    // their custom commands once those live on the server.
    expect(segments.map((s) => s.key).toList(), [
      'time',
      customX,
      customTime,
    ]);
  });

  test('enum names stay in sync with the FFI manifest', () {
    final cases = <(String, List<ShellCmdType>)>[
      ('linux', StatusCmdType.values),
      ('bsd', BSDStatusCmdType.values),
      ('windows', WindowsStatusCmdType.values),
    ];
    for (final (system, types) in cases) {
      final manifestKeys = {
        for (final spec in commandSpecs(system: system)) spec.key,
      };
      for (final type in types) {
        expect(
          manifestKeys,
          contains(type.name),
          reason: '$system/${type.name} missing from the Rust manifest',
        );
      }
      expect(
        manifestKeys.length,
        types.length,
        reason: '$system manifest and enum should have the same entries',
      );
    }
  });
}
