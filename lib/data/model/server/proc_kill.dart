import 'package:server_box/data/model/server/proc.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/src/rust/api/proc.dart' as ffi;

enum ProcKillOutcome {
  succeeded,

  /// The PID now names another process, or none: nothing was signalled.
  targetChanged,

  /// The account may not signal it.
  denied,
  failed,
}

/// Stopping one process, as `sbm_parser::proc` builds and reads it: the
/// command checks the process's start identity before it signals, so a PID
/// reused since the table was read is never what is stopped.
abstract final class ProcKill {
  /// Null where the platform cannot check what it would signal.
  static String? command(Proc target, SystemType system, ProcSignal signal) =>
      ffi.procKillCommand(
        pid: target.pid,
        startId: target.startId,
        system: system.name,
        signal: signal.name,
      );

  static ProcKillOutcome outcome(String output) =>
      switch (ffi.procKillOutcome(output: output)) {
        'succeeded' => ProcKillOutcome.succeeded,
        'target_changed' => ProcKillOutcome.targetChanged,
        'denied' => ProcKillOutcome.denied,
        _ => ProcKillOutcome.failed,
      };
}
