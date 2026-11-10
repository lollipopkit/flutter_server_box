import 'package:server_box/data/model/server/proc.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/src/rust/api/proc.dart' as ffi;

/// Stopping one process, as `sbm_parser::proc` builds and reads it: the
/// command checks the process's start identity before it signals, so a PID
/// reused since the table was read is never what is stopped.
abstract final class ProcKill {
  /// Null where the platform cannot check what it would signal.
  static String? command(Proc target, SystemType system, ProcSignal signal) =>
      ffi.procKillCommand(pid: target.pid, startId: target.startId, system: system.ffi, signal: signal);

  static ProcKillOutcome outcome(String output) => ffi.procKillOutcome(output: output);
}
