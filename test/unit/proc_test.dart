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

  test('parse linux process io counters without start column', () {
    const raw = '''
PID USER %CPU %MEM VSZ RSS TTY STAT TIME READ_BYTES WRITE_BYTES COMMAND
8987 root 0.9 1.8 1276 512 ? Sl 02:10:05 1024 2048 barad_agent
''';
    final psResult = PsResult.parse(raw, sampledAtMillis: 1000);
    final proc = psResult.procs.single;

    expect(proc.pid, 8987);
    expect(proc.start, isNull);
    expect(proc.time, '02:10:05');
    expect(proc.readBytes, 1024);
    expect(proc.writeBytes, 2048);
    expect(proc.command, 'barad_agent');
    expect(proc.binary, 'barad_agent');
    expect(proc.args, isEmpty);
  });

  test('parse process binary and args for display', () {
    const raw = '''
PID USER %CPU %MEM VSZ RSS TTY STAT TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.0 1.0 173552 8396 ? Ss 00:01:08 7603757056 4942843904 /usr/lib/systemd/systemd --system --deserialize 20 showopts
''';
    final proc = PsResult.parse(raw).procs.single;

    expect(proc.binary, '/usr/lib/systemd/systemd');
    expect(proc.args, '--system --deserialize 20 showopts');
    expect(
      proc.command,
      '/usr/lib/systemd/systemd --system --deserialize 20 showopts',
    );
  });

  test('Unix command text preserves repeated whitespace', () {
    const raw = '''
PID USER COMMAND
1 root /bin/tool  --name 'a  b'
''';

    expect(
      PsResult.parse(raw).procs.single.command,
      "/bin/tool  --name 'a  b'",
    );
  });

  test('binary and args recognize all command whitespace', () {
    final proc = Proc(pid: 1, command: '\t/usr/bin/worker\t--job  one');

    expect(proc.binary, '/usr/bin/worker');
    expect(proc.args, '--job  one');
  });

  test('malformed optional metrics do not discard Unix process rows', () {
    const raw = '''
PID USER %CPU %MEM COMMAND
1 root - N/A /sbin/procd
''';
    final proc = PsResult.parse(raw).procs.single;

    expect(proc.pid, 1);
    expect(proc.cpu, isNull);
    expect(proc.mem, isNull);
    expect(proc.command, '/sbin/procd');
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

  test('IO speed uses elapsed sample time and matches predecessors by PID', () {
    const first = '''
PID START_ID READ_BYTES WRITE_BYTES COMMAND
1 100 1000 4000 /one
2 200 8000 2000 /two
''';
    const second = '''
PID START_ID READ_BYTES WRITE_BYTES COMMAND
2 200 10000 10000 /two
1 100 5000 6000 /one
''';
    final previous = PsResult.parse(first, sampledAtMillis: 1000);
    final current = PsResult.parse(
      second,
      previous: previous,
      sampledAtMillis: 5000,
      sort: ProcSortMode.pid,
    );

    expect(current.procs[0].readSpeed, 1000);
    expect(current.procs[0].writeSpeed, 500);
    expect(current.procs[1].readSpeed, 500);
    expect(current.procs[1].writeSpeed, 2000);
  });

  test('IO speed is null for zero or negative sample intervals', () {
    const first = '''
PID START_ID READ_BYTES WRITE_BYTES COMMAND
1 100 1000 2000 /one
''';
    const second = '''
PID START_ID READ_BYTES WRITE_BYTES COMMAND
1 100 3000 5000 /one
''';
    final previous = PsResult.parse(first, sampledAtMillis: 2000);

    for (final sampledAt in [2000, 1000]) {
      final current = PsResult.parse(
        second,
        previous: previous,
        sampledAtMillis: sampledAt,
      ).procs.single;
      expect(current.readSpeed, isNull);
      expect(current.writeSpeed, isNull);
    }
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

  test('missing process identity does not inherit IO counters by PID', () {
    const first = '''
PID USER %CPU %MEM TIME READ_BYTES WRITE_BYTES COMMAND
7 root 0.1 1.2 00:01 1000 2000 /usr/bin/worker --old
''';
    const second = '''
PID USER %CPU %MEM TIME READ_BYTES WRITE_BYTES COMMAND
7 root 0.1 1.2 00:02 3000 5000 /usr/bin/worker --new
''';
    final previous = PsResult.parse(first, sampledAtMillis: 1000);
    final current = PsResult.parse(
      second,
      previous: previous,
      sampledAtMillis: 3000,
    );

    expect(current.procs.single.readSpeed, isNull);
    expect(current.procs.single.writeSpeed, isNull);
  });

  test(
    'PID reuse with a new process start ID does not inherit IO counters',
    () {
      const first = '''
PID USER %CPU %MEM VSZ RSS TTY STAT TIME START_ID READ_BYTES WRITE_BYTES COMMAND
42 root 0.1 1.2 1276 512 ? S 00:01 100 1000 2000 /usr/bin/worker
''';
      const second = '''
PID USER %CPU %MEM VSZ RSS TTY STAT TIME START_ID READ_BYTES WRITE_BYTES COMMAND
42 root 0.1 1.2 1276 512 ? S 00:01 200 9000 12000 /usr/bin/worker
''';
      final previous = PsResult.parse(first, sampledAtMillis: 1000);
      final current = PsResult.parse(
        second,
        previous: previous,
        sampledAtMillis: 2000,
      );

      expect(current.procs.single.startId, '200');
      expect(current.procs.single.readSpeed, isNull);
      expect(current.procs.single.writeSpeed, isNull);
    },
  );

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
  {"ProcessName":"a","Id":1,"CPUPercent":12.5,"StartId":"100","WorkingSet":1024,"IOReadBytes":100,"IOWriteBytes":200},
  {"ProcessName":"b","Id":2,"CPUPercent":2.5,"StartId":"200","WorkingSet":512,"IOReadBytes":1000,"IOWriteBytes":1200}
]
''';
    const second = '''
[
  {"ProcessName":"a","Id":1,"CPUPercent":25.0,"StartId":"100","WorkingSet":1024,"IOReadBytes":1100,"IOWriteBytes":2200},
  {"ProcessName":"b","Id":2,"CPUPercent":5.0,"StartId":"200","WorkingSet":512,"IOReadBytes":1200,"IOWriteBytes":1600}
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
    expect(current.procs.first.cpu, 25);
    expect(current.procs.first.startId, '100');
    expect(current.procs.first.rssKb, 1);
    expect(current.procs.last.rssKb, 1);
  });

  test('Windows cumulative CPU seconds are not parsed as CPU usage', () {
    const raw = '''
{"ProcessName":"legacy","Id":1,"CPU":99.5,"WorkingSet":1024}
''';
    final proc = PsResult.parse(raw).procs.single;

    expect(proc.cpu, isNull);
  });

  test('invalid numeric metrics and negative RSS are omitted', () {
    const unixRaw = '''
PID %CPU %MEM RSS COMMAND
1 NaN Infinity -1 /bad
''';
    final unixProc = PsResult.parse(unixRaw).procs.single;
    expect(unixProc.cpu, isNull);
    expect(unixProc.mem, isNull);
    expect(unixProc.rssKb, isNull);

    const windowsRaw = '''
{"Id":2,"WorkingSet":-1,"CPUPercent":"Infinity","IOReadBytes":1.5}
''';
    final windowsProc = PsResult.parse(windowsRaw).procs.single;
    expect(windowsProc.cpu, isNull);
    expect(windowsProc.rssKb, isNull);
    expect(windowsProc.readBytes, isNull);
  });

  test('negative Unix IO counters are omitted', () {
    const raw = '''
PID START_ID READ_BYTES WRITE_BYTES COMMAND
1 100 -1 -2 /bad
''';
    final proc = PsResult.parse(raw).procs.single;

    expect(proc.readBytes, isNull);
    expect(proc.writeBytes, isNull);
  });

  test('scalar JSON is classified as invalid Windows JSON', () {
    for (final raw in ['null', '123', 'true', '"text"']) {
      final result = PsResult.parse(raw);
      expect(result.procs, isEmpty);
      expect(result.issue?.failure, PsParseFailure.invalidWindowsJson);
    }
  });

  test('Windows fields fall back after empty or unparsable values', () {
    const raw = r'''
{"Id":7,"CommandLine":"","Path":"C:\\app.exe","CPUPercent":"","PercentProcessorTime":12.5,"IOReadBytes":1.5,"ReadTransferCount":100,"WorkingSet":"bad","WorkingSetSize":2048}
''';
    final proc = PsResult.parse(raw).procs.single;

    expect(proc.command, r'C:\app.exe');
    expect(proc.cpu, 12.5);
    expect(proc.readBytes, 100);
    expect(proc.rssKb, 2);
  });

  test('invalid Windows rows preserve typed diagnostics', () {
    const raw = '''
[
  {"ProcessName":"missing-pid"},
  {"ProcessName":"fractional-pid","Id":1.5},
  "not-an-object",
  {"ProcessName":"valid","Id":7,"CPUPercent":3.0}
]
''';
    final result = PsResult.parse(raw, sampledAtMillis: 1234);

    expect(result.procs.map((proc) => proc.pid), [7]);
    expect(result.issue?.failure, PsParseFailure.invalidWindowsRows);
    expect(
      RegExp(
        'missing or invalid PID',
      ).allMatches(result.issue!.diagnostics).length,
      2,
    );
    expect(result.issue?.diagnostics, contains('expected an object'));
    expect(result.sampledAtMillis, 1234);
  });

  test('Windows rows reject non-positive process IDs', () {
    const raw = '''
[
  {"ProcessName":"zero","Id":0},
  {"ProcessName":"negative","Id":-2},
  {"ProcessName":"string-zero","Id":"0"},
  {"ProcessName":"valid","Id":3}
]
''';
    final result = PsResult.parse(raw);

    expect(result.procs.map((proc) => proc.pid), [3]);
    expect(result.issue?.failure, PsParseFailure.invalidWindowsRows);
    expect(
      RegExp(
        'missing or invalid PID',
      ).allMatches(result.issue!.diagnostics).length,
      3,
    );
  });

  test('Unix rows reject non-positive and duplicate process IDs', () {
    const raw = '''
PID COMMAND
0 zero
-1 negative
2 valid
2 duplicate
''';
    final result = PsResult.parse(raw);

    expect(result.procs.map((proc) => proc.pid), [2]);
    expect(result.issue?.failure, PsParseFailure.invalidRows);
    expect(result.issue?.diagnostics, contains('Invalid process ID'));
    expect(result.issue?.diagnostics, contains('Duplicate process ID'));
  });

  test('Windows rows reject duplicate process IDs', () {
    const raw = '''
[{"Id":3,"ProcessName":"first"},{"Id":3,"ProcessName":"second"}]
''';
    final result = PsResult.parse(raw);

    expect(result.procs, hasLength(1));
    expect(result.issue?.failure, PsParseFailure.invalidWindowsRows);
    expect(result.issue?.diagnostics, contains('duplicate PID 3'));
  });

  test('malformed Windows JSON preserves typed diagnostics', () {
    final result = PsResult.parse('{"ProcessName":', sampledAtMillis: 5678);

    expect(result.procs, isEmpty);
    expect(result.issue?.failure, PsParseFailure.invalidWindowsJson);
    expect(result.issue?.diagnostics, contains('Invalid Windows process JSON'));
    expect(result.sampledAtMillis, 5678);
  });

  test('sortedBy reorders processes and keeps metadata', () {
    final original = PsResult(
      sampledAtMillis: 1234,
      issue: const PsParseIssue(
        failure: PsParseFailure.invalidRows,
        diagnostics: 'partial parse error',
      ),
      procs: [
        Proc(
          user: 'z-user',
          pid: 3,
          cpu: 0.2,
          mem: 5,
          rss: '2048',
          readSpeed: 10,
          writeSpeed: 20,
          command: '/zeta',
        ),
        Proc(
          user: 'a-user',
          pid: 1,
          cpu: 9,
          mem: 1,
          rss: null,
          readSpeed: null,
          writeSpeed: null,
          command: '/alpha',
        ),
        Proc(
          user: 'm-user',
          pid: 2,
          cpu: 3,
          mem: 8,
          rss: '1024',
          readSpeed: 50,
          writeSpeed: 5,
          command: '/middle',
        ),
      ],
    );

    expect(original.sortedBy(ProcSortMode.cpu).procs.map((e) => e.pid), [
      1,
      2,
      3,
    ]);
    expect(original.sortedBy(ProcSortMode.mem).procs.map((e) => e.pid), [
      2,
      3,
      1,
    ]);
    expect(original.sortedBy(ProcSortMode.rss).procs.map((e) => e.pid), [
      3,
      2,
      1,
    ]);
    expect(original.sortedBy(ProcSortMode.read).procs.map((e) => e.pid), [
      2,
      3,
      1,
    ]);
    expect(original.sortedBy(ProcSortMode.write).procs.map((e) => e.pid), [
      3,
      2,
      1,
    ]);
    expect(original.sortedBy(ProcSortMode.pid).procs.map((e) => e.pid), [
      1,
      2,
      3,
    ]);
    expect(original.sortedBy(ProcSortMode.user).procs.map((e) => e.pid), [
      1,
      2,
      3,
    ]);
    expect(original.sortedBy(ProcSortMode.name).procs.map((e) => e.pid), [
      1,
      2,
      3,
    ]);
    expect(
      original
          .sortedBy(ProcSortMode.cpu, ascending: true)
          .procs
          .map((e) => e.pid),
      [3, 2, 1],
    );
    expect(
      original
          .sortedBy(ProcSortMode.pid, ascending: false)
          .procs
          .map((e) => e.pid),
      [3, 2, 1],
    );
    expect(
      original
          .sortedBy(ProcSortMode.rss, ascending: true)
          .procs
          .map((e) => e.pid),
      [2, 3, 1],
    );

    final sorted = original.sortedBy(ProcSortMode.pid);
    expect(sorted.issue, same(original.issue));
    expect(sorted.sampledAtMillis, original.sampledAtMillis);
    expect(original.procs.map((e) => e.pid), [3, 1, 2]);
  });

  test('CPU sort breaks equal-value ties by PID', () {
    final result = PsResult(
      procs: [
        Proc(pid: 20, cpu: 5, command: 'second'),
        Proc(pid: 10, cpu: 5, command: 'first'),
      ],
    ).sortedBy(ProcSortMode.cpu);

    expect(result.procs.map((proc) => proc.pid), [10, 20]);
  });

  test('malformed process header preserves typed diagnostics', () {
    const raw = '''
USER CPU COMMAND
root 0.0 /sbin/procd
''';
    final result = PsResult.parse(raw, sampledAtMillis: 4321);

    expect(result.procs, isEmpty);
    expect(result.issue?.failure, PsParseFailure.unsupportedOutput);
    expect(
      result.issue?.diagnostics,
      contains('Unsupported process output header'),
    );
    expect(result.sampledAtMillis, 4321);
  });
}
