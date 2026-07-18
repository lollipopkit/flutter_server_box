// sbm_parser FFI 双跑验证(ADR 0001 Phase 2):
// 同一 fixture 分别经 Rust FFI 与既有 Dart 解析器,断言结果一致。
// 运行前需构建原生库:cd rust && cargo build

import 'dart:convert';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/nvdia.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/src/rust/api/parser.dart';
import 'package:server_box/src/rust/frb_generated.dart';

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

void main() {
  setUpAll(() async {
    final lib = File('target/debug/libsbm_ffi.dylib').existsSync()
        ? 'target/debug/libsbm_ffi.dylib'
        : 'target/debug/libsbm_ffi.so';
    await RustLib.init(externalLibrary: ExternalLibrary.open(lib));
  });

  Map<String, dynamic> parseViaFfi(Map<String, String> raw) {
    final json = parseStatusJson(system: 'linux', raw: raw);
    return jsonDecode(json) as Map<String, dynamic>;
  }

  test('cpu parity with SingleCpuCore.parse', () {
    final ffi = parseViaFfi({'cpu': _cpuRaw})['cpu'] as List;
    final dart = SingleCpuCore.parse(_cpuRaw);

    expect(ffi.length, dart.length);
    for (var i = 0; i < dart.length; i++) {
      expect(ffi[i]['id'], dart[i].id);
      expect(ffi[i]['user'], dart[i].user);
      expect(ffi[i]['sys'], dart[i].sys);
      expect(ffi[i]['nice'], dart[i].nice);
      expect(ffi[i]['idle'], dart[i].idle);
      expect(ffi[i]['iowait'], dart[i].iowait);
      expect(ffi[i]['irq'], dart[i].irq);
      expect(ffi[i]['softirq'], dart[i].softirq);
    }
  });

  test('memory/swap parity with Memory.parse / Swap.parse', () {
    final ffi = parseViaFfi({'mem': _memRaw});
    final mem = Memory.parse(_memRaw);
    final swap = Swap.parse(_memRaw);

    expect(ffi['mem']['total'], mem.total);
    expect(ffi['mem']['free'], mem.free);
    expect(ffi['mem']['avail'], mem.avail);
    expect(ffi['swap']['total'], swap.total);
    expect(ffi['swap']['free'], swap.free);
    expect(ffi['swap']['cached'], swap.cached);
  });

  test('net parity with NetSpeed.parse', () {
    final ffi = parseViaFfi({'net': _netRaw})['net'] as List;
    final dart = NetSpeed.parse(_netRaw, 0);

    expect(ffi.length, dart.length);
    for (var i = 0; i < dart.length; i++) {
      expect(ffi[i]['device'], dart[i].device);
      expect(BigInt.from(ffi[i]['rx_bytes'] as int), dart[i].bytesIn);
      expect(BigInt.from(ffi[i]['tx_bytes'] as int), dart[i].bytesOut);
    }
  });

  test('disk parity with Disk.parse (df fallback)', () {
    final ffi = parseViaFfi({'disk': _dfRaw})['disks'] as List;
    final dart = Disk.parse(_dfRaw);

    expect(ffi.length, dart.length);
    for (var i = 0; i < dart.length; i++) {
      expect(ffi[i]['path'], dart[i].path);
      expect(ffi[i]['mount'], dart[i].mount);
      expect(ffi[i]['used_percent'], dart[i].usedPercent);
      expect(BigInt.from(ffi[i]['size'] as int), dart[i].size);
      expect(BigInt.from(ffi[i]['used'] as int), dart[i].used);
      expect(BigInt.from(ffi[i]['avail'] as int), dart[i].avail);
    }
  });

  test('conn parity with Conn.parse', () {
    const raw =
        'Tcp: RtoAlgorithm RtoMin RtoMax MaxConn ActiveOpens PassiveOpens AttemptFails EstabResets CurrEstab InSegs OutSegs RetransSegs InErrs OutRsts InCsumErrors\n'
        'Tcp: 1 200 120000 -1 11 22 33 44 55 66 77 88 99 111 222';
    final ffi = parseViaFfi({'conn': raw})['conn'];
    final dart = Conn.parse(raw);
    expect(ffi['max_conn'], dart!.maxConn);
    expect(ffi['fail'], dart.fail);
  });

  test('batteries parity with Batteries.parse', () async {
    final raw = await File(
      'crates/sbm_parser/tests/fixtures/power_supply.txt',
    ).readAsString();
    // App 调用为 onlyLiPoly=true,与 parse_status 的 Linux 分支一致
    final dart = Batteries.parse(raw, true);
    final ffi = parseViaFfi({'battery': raw})['batteries'] as List;
    expect(ffi.length, dart.length);
    for (var i = 0; i < dart.length; i++) {
      expect(ffi[i]['percent'], dart[i].percent);
      expect(ffi[i]['name'], dart[i].name);
      expect(ffi[i]['cycle'], dart[i].cycle);
      expect(ffi[i]['status'], dart[i].status.name);
    }
  });

  test('sensors parity with SensorItem.parse', () async {
    final raw = await File(
      'crates/sbm_parser/tests/fixtures/sensors1.txt',
    ).readAsString();
    final dart = SensorItem.parse(raw);
    final ffi = parseViaFfi({'sensors': raw})['sensors'] as List;
    expect(ffi.length, dart.length);
    for (var i = 0; i < dart.length; i++) {
      expect(ffi[i]['device'], dart[i].device);
      expect(ffi[i]['adapter'], dart[i].adapter.raw);
      final ffiFirstDetail = (ffi[i]['details'] as List).firstOrNull;
      expect(ffiFirstDetail?[1], dart[i].summary);
    }
  });

  test('nvidia parity with NvidiaSmi.fromXml', () async {
    final raw = await File(
      'crates/sbm_parser/tests/fixtures/nvidia.xml',
    ).readAsString();
    final dart = NvidiaSmi.fromXml(raw);
    final ffi = parseViaFfi({'nvidia': raw})['nvidia'] as List;
    expect(ffi.length, dart.length);
    for (var i = 0; i < dart.length; i++) {
      expect(ffi[i]['name'], dart[i].name);
      expect(ffi[i]['temp'], dart[i].temp);
      expect(ffi[i]['power'], dart[i].power);
      expect(ffi[i]['memory']['total'], dart[i].memory.total);
      expect(ffi[i]['memory']['used'], dart[i].memory.used);
      expect(ffi[i]['percent'], dart[i].percent);
      expect(ffi[i]['fan_speed'], dart[i].fanSpeed);
    }
  });

  test('smart parity with DiskSmart.parse', () async {
    final raw = await File(
      'crates/sbm_parser/tests/fixtures/smartctl.json',
    ).readAsString();
    final dart = DiskSmart.parse(raw);
    final ffi = parseViaFfi({'diskSmart': raw})['disk_smart'] as List;
    expect(ffi.length, dart.length);
    for (var i = 0; i < dart.length; i++) {
      expect(ffi[i]['device'], dart[i].device);
      expect(ffi[i]['healthy'], dart[i].healthy);
      expect(ffi[i]['temperature'], dart[i].temperature);
      expect(ffi[i]['model'], dart[i].model);
      expect(ffi[i]['power_on_hours'], dart[i].powerOnHours);
      expect(ffi[i]['power_cycle_count'], dart[i].powerCycleCount);
      expect(
        (ffi[i]['smart_attributes'] as Map).length,
        dart[i].smartAttributes.length,
      );
    }
  });

  test('uptime/sys/host parity', () {
    const uptimeRaw =
        '19:39:15 up 61 days, 18:16,  1 user,  load average: 0.00, 0.00, 0.00';
    const sysRaw = 'PRETTY_NAME="Ubuntu 22.04.3 LTS"\n';
    final ffi = parseViaFfi({
      'uptime': uptimeRaw,
      'sys': sysRaw,
      'host': ' myhost \n',
    });
    expect(ffi['uptime'], '61 days, 18:16');
    expect(ffi['sys'], 'Ubuntu 22.04.3 LTS');
    expect(ffi['host'], 'myhost');
  });

  test('diskio parity with DiskIO.parse', () {
    const raw =
        '   7       0 loop0 55 0 2170 42 0 0 0 0 0 80 42 0 0 0 0 0 0\n'
        ' 259       0 nvme0n1 1234 0 567890 100 4321 0 98765 200 0 300 400 0 0 0 0 0 0';
    final dart = DiskIO.parse(raw, 0);
    final ffi = parseViaFfi({'diskio': raw})['diskio'] as List;
    expect(ffi.length, dart.length);
    for (var i = 0; i < dart.length; i++) {
      expect(ffi[i]['dev'], dart[i].dev);
      expect(ffi[i]['sectors_read'], dart[i].sectorsRead);
      expect(ffi[i]['sectors_write'], dart[i].sectorsWrite);
    }
  });

  test('command specs cover linux/bsd/windows', () {
    for (final system in ['linux', 'bsd', 'windows']) {
      final specs = commandSpecs(system: system);
      expect(specs, isNotEmpty, reason: system);
      expect(specs.map((s) => s.key), contains('cpu'));
    }
    expect(separator(), 'SrvBoxSep');
  });
}
