import 'dart:convert';
import 'dart:io';

import 'package:server_box/data/model/server/proc.dart';
import 'package:server_box/data/model/server/proc_kill.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:test/test.dart';

/// The stop command is a string assembled here and run by a shell on someone
/// else's machine, against a PID read a refresh ago. What matters is that it
/// refuses the wrong process and cannot be made to run anything else.
///
/// The Linux branches themselves — pidfd through python3, and the shell
/// fallback under dash and busybox — were run against real processes in
/// `python:3.12-alpine`, `alpine:3.20` and `ubuntu:24.04`: own process
/// stopped, wrong start time refused, missing PID refused, another user's
/// process reported as denied. What runs here is what a Mac's `/bin/sh` can
/// check: that the text parses, and that it answers rather than signals when
/// there is no `/proc` to prove the target by.
void main() {
  Proc proc({String? startId = '4242'}) =>
      Proc(pid: 12345, startId: startId, command: 'sleep 100');

  /// Fed on stdin, the way `entry: 'sh'` hands it to the server's shell.
  Future<({int code, String out, String err})> sh(String script) async {
    final process = await Process.start('/bin/sh', const []);
    final out = process.stdout.transform(utf8.decoder).join();
    final err = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(script);
    await process.stdin.close();
    return (code: await process.exitCode, out: await out, err: await err);
  }

  test('no identity, no command', () {
    for (final system in SystemType.values) {
      for (final signal in ProcSignal.values) {
        expect(ProcKill.command(proc(startId: null), system, signal), isNull);
      }
      expect(ProcKill.supports(proc(startId: null), system), isFalse);
    }
  });

  test('which signals each platform offers', () {
    expect(ProcKill.signalsFor(SystemType.linux), ProcSignal.values);
    // TerminateProcess is the only stop Windows has, and it is not a request.
    expect(ProcKill.signalsFor(SystemType.windows), [ProcSignal.kill]);
    expect(ProcKill.command(proc(), SystemType.windows, ProcSignal.term), isNull);
    expect(ProcKill.command(proc(), SystemType.windows, ProcSignal.kill), isNotNull);
    // Offered for the one signal it has.
    expect(ProcKill.supports(proc(), SystemType.windows), isTrue);

    expect(ProcKill.signalsFor(SystemType.bsd), isEmpty);
    expect(ProcKill.supports(proc(), SystemType.bsd), isFalse);
  });

  test('outcome reads the marker, and anything else is a failure', () {
    expect(ProcKill.outcome('SrvBoxKill.Succeeded\n'), ProcKillOutcome.succeeded);
    expect(
      ProcKill.outcome('noise\nSrvBoxKill.TargetChanged\n'),
      ProcKillOutcome.targetChanged,
    );
    expect(ProcKill.outcome('SrvBoxKill.Denied'), ProcKillOutcome.denied);
    expect(ProcKill.outcome(''), ProcKillOutcome.failed);
    expect(ProcKill.outcome('Traceback (most recent call last)'), ProcKillOutcome.failed);
  });

  test('the signal named is the signal sent', () {
    final term = ProcKill.command(proc(), SystemType.linux, ProcSignal.term)!;
    final kill = ProcKill.command(proc(), SystemType.linux, ProcSignal.kill)!;
    expect(term, contains('signal.SIGTERM'));
    expect(term, contains('kill -s TERM'));
    expect(term, isNot(contains('KILL')));
    expect(kill, contains('signal.SIGKILL'));
    expect(kill, contains('kill -s KILL'));
  });

  test('Windows compares the start time the table was read from', () {
    final command = ProcKill.command(proc(), SystemType.windows, ProcSignal.kill)!;
    final encoded = command.split(' ').last;
    final bytes = base64Decode(encoded);
    final script = String.fromCharCodes([
      for (var i = 0; i + 1 < bytes.length; i += 2) bytes[i] | bytes[i + 1] << 8,
    ]);

    // CIM's CreationDate, like the table's StartId: Get-Process's StartTime
    // is the same instant at a finer precision, and never compared equal.
    expect(script, contains("Win32_Process -Filter 'ProcessId=12345'"));
    expect(script, contains('CreationDate.ToUniversalTime().Ticks'));
    expect(script, isNot(contains('StartTime')));
    // The handle is taken before the check, so the PID cannot be reused
    // between the two.
    expect(
      script.indexOf(r'$handle = $p.Handle'),
      lessThan(script.indexOf('CreationDate')),
    );
    expect(script, contains("-ne '4242'"));
  });

  group('under /bin/sh', () {
    test('parses, and refuses a target it cannot prove', () async {
      final script = ProcKill.command(proc(), SystemType.linux, ProcSignal.kill)!;
      final result = await sh(script);

      expect(result.code, 0, reason: result.err);
      if (Directory('/proc').existsSync()) return;
      expect(
        ProcKill.outcome(result.out),
        ProcKillOutcome.targetChanged,
      );
    });

    test('a start id cannot inject a command', () async {
      final marker = File(
        '${Directory.systemTemp.createTempSync('proc_kill_').path}/owned',
      );
      final hostile = "1'; touch ${marker.path}; echo '";
      final script = ProcKill.command(
        proc(startId: hostile),
        SystemType.linux,
        ProcSignal.term,
      )!;
      await sh(script);

      expect(marker.existsSync(), isFalse);
      marker.parent.deleteSync(recursive: true);
    });
  });
}
