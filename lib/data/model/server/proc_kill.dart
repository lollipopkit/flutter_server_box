import 'dart:convert';

import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/server/proc.dart';
import 'package:server_box/data/model/server/system.dart';

/// How to ask a process to go.
enum ProcSignal {
  /// Asks. The process can clean up, and can also ignore it.
  term,

  /// Does not ask. For a process that ignored [term] or cannot act on it.
  kill,
}

enum ProcKillOutcome {
  succeeded,

  /// The PID is gone, or now belongs to a process that started at a different
  /// time — something the kernel handed the number to after the list was read.
  targetChanged,

  /// The process exists and this account may not signal it.
  denied,
  failed,
}

/// Stopping one process, refused if its PID has been reused.
///
/// The identity is the `START_ID` the process table carries: `starttime` from
/// `/proc/<pid>/stat` on Linux, the creation time in UTC ticks on Windows.
/// Without one there is nothing to check a PID against, and [command] answers
/// null rather than signalling whatever holds the number now.
abstract final class ProcKill {
  static const _succeeded = 'SrvBoxKill.Succeeded';
  static const _targetChanged = 'SrvBoxKill.TargetChanged';
  static const _denied = 'SrvBoxKill.Denied';
  static const _failed = 'SrvBoxKill.Failed';

  /// Whether [command] can say anything for [target] on [system]. What a page
  /// asks before it offers the action at all.
  static bool supports(Proc target, SystemType system) => signalsFor(
    system,
  ).any((signal) => command(target, system, signal) != null);

  /// Which signals mean something on [system]. Windows has no polite request:
  /// `TerminateProcess` is the only stop there is, so it is offered once, as
  /// what it is.
  static List<ProcSignal> signalsFor(SystemType system) => switch (system) {
    SystemType.windows => const [ProcSignal.kill],
    SystemType.linux => ProcSignal.values,
    SystemType.bsd => const [],
  };

  /// Null where the process cannot be stopped safely from here: no identity to
  /// check, or a platform with no implementation (BSD).
  ///
  /// Unix commands are POSIX `sh` and are meant to be fed to one as its stdin
  /// (`entry: 'sh'`), which is also what lets the same text run under `sudo`.
  static String? command(Proc target, SystemType system, ProcSignal signal) {
    final startId = target.startId;
    if (startId == null) return null;
    return switch (system) {
      SystemType.linux => _linux(target.pid, startId, signal),
      SystemType.windows => signal == ProcSignal.kill
          ? _windows(target.pid, startId)
          : null,
      SystemType.bsd => null,
    };
  }

  static ProcKillOutcome outcome(String output) {
    if (output.contains(_succeeded)) return ProcKillOutcome.succeeded;
    if (output.contains(_targetChanged)) return ProcKillOutcome.targetChanged;
    if (output.contains(_denied)) return ProcKillOutcome.denied;
    return ProcKillOutcome.failed;
  }

  /// A pidfd where the machine has one, the PID where it does not.
  ///
  /// The pidfd is the exact answer: opened before `stat` is read, it keeps
  /// naming that process even if the process exits and its number is reused
  /// before the signal is sent. It needs python3 (the shell has no way to
  /// hold one), Python 3.9 and Linux 5.3; Python answers with nothing where
  /// any of those is missing and the shell does the same check by PID.
  ///
  /// That fallback has a window between reading `stat` and `kill` in which
  /// the PID could be reused. It is microseconds wide and needs the PID space
  /// to wrap inside it. `kill`, `top` and `htop` check nothing at all, and
  /// the alternative on Alpine and on an older kernel was not being able to
  /// stop a process from here.
  static String _linux(int pid, String startId, ProcSignal signal) {
    final name = switch (signal) {
      ProcSignal.term => 'TERM',
      ProcSignal.kill => 'KILL',
    };
    final python =
        '''
import os
import signal
import sys

pid = $pid
expected = ${jsonEncode(startId)}
try:
    fd = os.pidfd_open(pid)
    send = signal.pidfd_send_signal
except ProcessLookupError:
    print("$_targetChanged")
    sys.exit(0)
except (AttributeError, OSError):
    sys.exit(0)
try:
    with open(f"/proc/{pid}/stat", encoding="utf-8") as stat_file:
        fields = stat_file.read().rsplit(") ", 1)[1].split()
    if fields[19] != expected:
        print("$_targetChanged")
    else:
        send(fd, signal.SIG$name)
        print("$_succeeded")
except (ProcessLookupError, FileNotFoundError):
    print("$_targetChanged")
except PermissionError:
    print("$_denied")
except Exception:
    print("$_failed")
finally:
    os.close(fd)
''';
    return '''
pid=$pid
expected=${shellSingleQuote(startId)}
out=
if command -v python3 >/dev/null 2>&1; then
	out=\$(python3 -c ${shellSingleQuote(python)} 2>/dev/null)
fi
case \$out in
SrvBoxKill.*) echo "\$out" ;;
*)
	stat=
	[ -r "/proc/\$pid/stat" ] && IFS= read -r stat < "/proc/\$pid/stat"
	if [ -z "\$stat" ]; then
		echo $_targetChanged
	else
		set -f
		set -- \${stat##*") "}
		set +f
		if [ "\${20}" != "\$expected" ]; then
			echo $_targetChanged
		elif kill -s $name "\$pid" 2>/dev/null; then
			echo $_succeeded
		elif [ -e "/proc/\$pid" ]; then
			echo $_denied
		else
			echo $_targetChanged
		fi
	fi
	;;
esac
''';
  }

  static String _windows(int pid, String startId) {
    final expected = "'${startId.replaceAll("'", "''")}'";
    final script =
        'Add-Type -TypeDefinition \'using System; using '
        'System.Runtime.InteropServices; public static class SrvBoxNative { '
        '[DllImport("kernel32.dll", SetLastError=true)] public static extern '
        'bool TerminateProcess(IntPtr process, uint exitCode); }\' '
        '-ErrorAction SilentlyContinue; '
        '\$p = Get-Process -Id $pid -ErrorAction SilentlyContinue; '
        'if (\$null -eq \$p) { Write-Output \'$_targetChanged\' } '
        'else { try { \$handle = \$p.Handle; '
        'if (\$p.StartTime.ToUniversalTime().Ticks.ToString() -ne $expected) '
        '{ Write-Output \'$_targetChanged\' } '
        'elseif ([SrvBoxNative]::TerminateProcess(\$handle, 1)) { '
        '\$p.WaitForExit(); Write-Output \'$_succeeded\' } '
        'else { Write-Output \'$_failed\' } } '
        'catch { Write-Output \'$_failed\' } }';
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes
        ..add(unit & 0xff)
        ..add(unit >> 8);
    }
    return 'powershell.exe -NoProfile -NonInteractive '
        '-ExecutionPolicy Bypass -EncodedCommand ${base64Encode(bytes)}';
  }
}
