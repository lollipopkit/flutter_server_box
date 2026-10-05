import 'dart:io';

import 'package:server_box/data/model/server/proc.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:test/test.dart';

import '../../helpers/rust_lib_helper.dart';

/// The app's half of the process table: what `sbm_parser::proc` reads
/// (`crates/sbm_parser/tests/proc_compat.rs`) reaching the page's model
/// whole. The parsing itself is asserted on the Rust side.
void main() {
  setUpAll(initRustLibForTest);

  String fixture(String name) =>
      File('crates/sbm_parser/tests/fixtures/process/$name').readAsStringSync();

  test('a reading, its columns, orders and signals', () async {
    final r = await PsResult.parse(fixture('linux_procps.txt'), SystemType.linux, sampledAtMillis: 1000);
    expect(r.issue, isNull);
    expect(r.procs, isNotEmpty);
    expect(r.columns.cpu, isTrue);
    expect(r.sorts, containsAll([ProcSortMode.cpu, ProcSortMode.pid, ProcSortMode.name]));
    // No speeds on a first reading: no order by them either.
    expect(r.sorts, isNot(contains(ProcSortMode.read)));
    expect((r.sort, r.ascending), (ProcSortMode.cpu, false));
    expect(r.signals, [ProcSignal.term, ProcSignal.kill]);
    final p = r.procs.first;
    expect(p.name, isNotEmpty);
    expect(p.killable, p.startId != null);
  });

  test('ordered again, and an order the table cannot answer falls back', () async {
    final r = await PsResult.parse(fixture('linux_procps.txt'), SystemType.linux, sampledAtMillis: 1000);
    final byPid = await r.sortedBy(SystemType.linux, ProcSortMode.pid);
    final pids = byPid.procs.map((p) => p.pid).toList();
    expect(pids, [...pids]..sort());
    expect((byPid.sort, byPid.ascending), (ProcSortMode.pid, true));
    final read = await r.sortedBy(SystemType.linux, ProcSortMode.read, ascending: true);
    expect((read.sort, read.ascending), (ProcSortMode.cpu, false));
  });

  test('the next reading has speeds against the previous one', () async {
    final raw = fixture('linux_procps.txt');
    final first = await PsResult.parse(raw, SystemType.linux, sampledAtMillis: 1000);
    final second = await PsResult.parse(raw, SystemType.linux, previous: first, sampledAtMillis: 3000);
    expect(second.procs.where((p) => p.readSpeed != null), isNotEmpty);
  });

  test('macOS has no stop the app can check', () async {
    final r = await PsResult.parse(fixture('macos.txt'), SystemType.bsd, sampledAtMillis: 1000);
    expect(r.signals, isEmpty);
    expect(r.procs.every((p) => !p.killable), isTrue);
  });

  test('a table it cannot read says why', () async {
    final r = await PsResult.parse('hello\nworld\n', SystemType.linux, sampledAtMillis: 1000);
    expect(r.issue?.failure, PsParseFailure.unsupportedOutput);
  });
}
