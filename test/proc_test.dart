import 'package:server_box/data/model/server/proc.dart';
import 'package:test/test.dart';

void main() {
  test('parse process', () {
    const raw = '''
  PID USER       VSZ STAT COMMAND
    1 root      1276 S    /sbin/procd
''';
    final psResult = PsResult.parse(raw);
    expect(psResult.procs.length, 1);
    expect(psResult.procs.single.pid, 1);
    expect(psResult.procs.single.command, '/sbin/procd');
  });

  test('parse linux process io counters', () {
    const raw = '''
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 1024 2048 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 - - /usr/bin/app --flag
''';
    final psResult = PsResult.parse(raw, sampledAtMillis: 1000);
    expect(psResult.procs.length, 2);
    expect(psResult.procs[0].pid, 2);
    expect(psResult.procs[1].readBytes, 1024);
    expect(psResult.procs[1].writeBytes, 2048);
    expect(psResult.procs[1].readSpeed, isNull);
    expect(psResult.procs[1].writeSpeed, isNull);
    expect(psResult.procs[1].command, '/sbin/procd');
  });

  test('calculate process io speed from previous snapshot', () {
    const first = '''
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 1000 2000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 500 700 /usr/bin/app
''';
    const second = '''
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 3000 5000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 1000 1200 /usr/bin/app
''';
    final previous = PsResult.parse(first, sampledAtMillis: 1000);
    final current = PsResult.parse(
      second,
      previous: previous,
      sampledAtMillis: 3000,
    );
    final proc = current.procs.firstWhere((e) => e.pid == 1);
    expect(proc.readSpeed, 1000);
    expect(proc.writeSpeed, 1500);
  });

  test('io speed is null for missing previous and counter rollback', () {
    const first = '''
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 3000 5000 /sbin/procd
''';
    const second = '''
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 1000 4000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 1000 1200 /usr/bin/app
''';
    final previous = PsResult.parse(first, sampledAtMillis: 1000);
    final current = PsResult.parse(
      second,
      previous: previous,
      sampledAtMillis: 3000,
    );
    final rolledBack = current.procs.firstWhere((e) => e.pid == 1);
    final newProc = current.procs.firstWhere((e) => e.pid == 2);
    expect(rolledBack.readSpeed, isNull);
    expect(rolledBack.writeSpeed, isNull);
    expect(newProc.readSpeed, isNull);
    expect(newProc.writeSpeed, isNull);
  });

  test('sort process by io speed with null last', () {
    const first = '''
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 1000 1000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 1000 1000 /usr/bin/app
3 nobody 0.0 0.1 1024 256 ? S 10:02 00:00 - - idle
''';
    const second = '''
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 2000 6000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 5000 2000 /usr/bin/app
3 nobody 0.0 0.1 1024 256 ? S 10:02 00:00 - - idle
''';
    final previous = PsResult.parse(first, sampledAtMillis: 1000);
    final byRead = PsResult.parse(
      second,
      previous: previous,
      sampledAtMillis: 2000,
      sort: ProcSortMode.read,
    );
    final byWrite = PsResult.parse(
      second,
      previous: previous,
      sampledAtMillis: 2000,
      sort: ProcSortMode.write,
    );
    expect(byRead.procs.map((e) => e.pid), [2, 1, 3]);
    expect(byWrite.procs.map((e) => e.pid), [1, 2, 3]);
  });

  test('parse windows process json io counters', () {
    const first = '''
[
  {"ProcessName":"a","Id":1,"CPU":1.5,"WorkingSet":1024,"IOReadBytes":100,"IOWriteBytes":200},
  {"ProcessName":"b","Id":2,"CPU":0.5,"WorkingSet":512,"IOReadBytes":1000,"IOWriteBytes":1200}
]
''';
    const second = '''
[
  {"ProcessName":"a","Id":1,"CPU":1.5,"WorkingSet":1024,"IOReadBytes":1100,"IOWriteBytes":2200},
  {"ProcessName":"b","Id":2,"CPU":0.5,"WorkingSet":512,"IOReadBytes":1200,"IOWriteBytes":1600}
]
''';
    final previous = PsResult.parse(first, sampledAtMillis: 1000);
    final current = PsResult.parse(
      second,
      previous: previous,
      sampledAtMillis: 2000,
      sort: ProcSortMode.write,
    );
    expect(current.procs.first.pid, 1);
    expect(current.procs.first.readSpeed, 1000);
    expect(current.procs.first.writeSpeed, 2000);
  });
}
