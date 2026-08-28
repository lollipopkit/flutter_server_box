import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/data/res/store.dart';

/// Reads why the process died last time, from the system.
///
/// The half of crash reporting Dart cannot do. A SIGSEGV in the Rust FFI, in
/// proot, in the iOS Linux engine or in sqlite takes the process with it: no
/// Dart handler runs, nothing is written, and [CrashLog]'s marker is never set.
/// The next launch has no idea anything happened. Android has kept the record
/// since API 30 and this is what asks for it.
///
/// Deliberately not a signal handler, and that is worth stating because a crash
/// SDK would install one. Collection happens out of process — nothing runs
/// inside a crashing app, and nothing competes for SIGSEGV or SIGABRT. In this
/// app that is not a small point: the iOS Linux engine interrupts its guest
/// threads with SIGUSR1, and a reporter fighting over signal disposition is a
/// class of bug avoided rather than debugged.
abstract final class NativeExitReport {
  /// The reasons that mean something went wrong.
  ///
  /// The point of the list is what is *not* on it. Being reclaimed for memory,
  /// being force-stopped, or exiting on request are all ordinary ends to a run,
  /// and raising a crash prompt for them would train the user to dismiss it —
  /// including the once it matters. This distinction is the thing a marker file
  /// alone could never make.
  static const _crashReasons = {'crash', 'crash_native', 'anr', 'signaled'};

  /// Whether a record describes something going wrong, rather than a run
  /// ending.
  ///
  /// `signaled` needs [status] to answer, and the distinction is not academic
  /// on this app's userbase: a SIGKILL (9) is what an OEM background killer
  /// sends, and it is reported as `REASON_SIGNALED` exactly like a SIGSEGV
  /// (11) or SIGABRT (6) would be. Counting it would raise a crash prompt
  /// after every aggressive task-kill on the ROMs where that is routine —
  /// which is the same mistake the reason list exists to avoid.
  @visibleForTesting
  static bool isCrash(String reason, Object? status) {
    if (!_crashReasons.contains(reason)) return false;
    if (reason == 'signaled' && status == 9) return false;
    return true;
  }

  /// The platform's account of how the previous run ended, once [collect] has
  /// seen it.
  ///
  /// Held here because of where it lands: the record describes the *previous*
  /// run but is written into *this* run's log, while a report is built from
  /// the previous run's file. Without somewhere for it to be read from, the
  /// one thing a crash report would leave out is why the app crashed.
  static Map<String, String>? lastExit;

  /// The previous run's native stack or ANR trace, when the platform had one.
  ///
  /// Separate from [lastExit] because it is large — a MetricKit call stack is
  /// capped at 16 KB and an ANR trace is a full thread dump — and because it
  /// belongs in a report as a block rather than as a field. Held for the same
  /// reason: it describes the run that died and is only learned about after
  /// that run's log has been closed.
  static String? lastExitTrace;

  /// Folds the system's record into this run's log.
  ///
  /// Best effort throughout. Every failure costs one report, and none of them
  /// is a reason for the app not to start.
  static Future<void> collect() async {
    try {
      final info = await MethodChans.lastExitInfo();
      if (info != null) apply(info);
    } catch (e, s) {
      Loggers.app.warning('NativeExitReport.collect', e, s);
    }
    try {
      applyDiagnostics(await MethodChans.takeCrashDiagnostics());
    } catch (e, s) {
      Loggers.app.warning('NativeExitReport.collect (metrickit)', e, s);
    }
  }

  /// Folds MetricKit's records in, on iOS.
  ///
  /// No de-duplication here, unlike [apply]: the platform side clears what it
  /// hands over, so a record arrives exactly once. Nor is there a timestamp to
  /// order them by — delivery is on the system's schedule, and a payload
  /// arriving now can describe a crash from several sessions ago. The prompt
  /// says "last time" and will occasionally be wrong about *when*; it will not
  /// be wrong about *whether*, which is the part that matters.
  @visibleForTesting
  static void applyDiagnostics(List<Map<String, Object?>> records) {
    if (records.isEmpty) return;
    var crashed = false;

    for (final record in records) {
      final kind = '${record['kind']}';
      // A hang is not a crash: the app was alive and unresponsive, which is a
      // different bug with different causes, and prompting for one would call
      // a slow frame a crash.
      if (kind == 'crash') crashed = true;

      // Same reason as the Android path: what a report is built from is the
      // previous run's file, and this describes that run without being in it.
      // A crash wins over a hang when both were delivered.
      if (kind == 'crash' || lastExit == null) {
        lastExit = {
          'reason': 'metrickit $kind',
          if (record['signal'] != null) 'signal': '${record['signal']}',
          if (record['exceptionType'] != null)
            'exceptionType': '${record['exceptionType']}',
          if (record['terminationReason'] != null)
            'terminationReason': '${record['terminationReason']}',
          'appVersion': '${record['appVersion'] ?? '-'}',
        };
      }

      Diag.crumb(
        DiagCategory.lifecycle,
        'metrickit $kind',
        level: kind == 'crash' ? DiagLevel.error : DiagLevel.warning,
        data: {
          // Both come off the diagnostic's own metadata rather than this run:
          // delivery lags the crash by up to a day, so the app and the OS may
          // both have moved on since.
          'appVersion': '${record['appVersion'] ?? '-'}',
          'osVersion': '${record['osVersion'] ?? '-'}',
          if (record['signal'] != null) 'signal': '${record['signal']}',
          if (record['exceptionType'] != null)
            'exceptionType': '${record['exceptionType']}',
          if (record['terminationReason'] != null)
            'terminationReason': '${record['terminationReason']}',
          if (record['duration'] != null) 'duration': '${record['duration']}',
        },
      );

      final stack = record['callStack'];
      if (stack is String && stack.isNotEmpty) {
        // A crash's stack wins over a hang's when both arrived, matching how
        // [lastExit] is chosen.
        if (kind == 'crash' || lastExitTrace == null) lastExitTrace = stack;
        CrashLog.write('--- metrickit $kind call stack ---\n$stack');
      }
    }

    if (crashed) CrashLog.reportPreviousRunCrashed();
  }

  /// Folds one platform record into this run's log.
  ///
  /// Separated from [collect] so the decisions here — which reasons count as a
  /// crash, and whether this record has been seen — are testable without a
  /// platform channel. They are also the decisions that fail silently: getting
  /// the reason set wrong shows a crash prompt after an ordinary launch, or
  /// hides a real one.
  @visibleForTesting
  static void apply(Map<String, Object?> info) {
    try {
      // The record is handed back on every launch until another replaces it,
      // and carries no id, so the timestamp is what tells two apart.
      final ts = info['timestamp'];
      if (ts is! int) return;
      final seen = Stores.setting.lastExitInfoTs.fetch();
      if (ts <= seen) return;
      // Written before the report is raised, not after: a crash while
      // reporting a crash would otherwise leave the same record to be found
      // again on the next launch, forever.
      Stores.setting.lastExitInfoTs.put(ts);

      final reason = '${info['reason']}';
      final crashed = isCrash(reason, info['status']);

      lastExit = {
        'reason': reason,
        'description': '${info['description'] ?? '-'}',
        'status': '${info['status'] ?? '-'}',
        'importance': '${info['importance'] ?? '-'}',
      };

      Diag.crumb(
        DiagCategory.lifecycle,
        'previous exit',
        level: crashed ? DiagLevel.error : DiagLevel.info,
        data: {
          'reason': reason,
          'description': '${info['description'] ?? '-'}',
          'status': '${info['status'] ?? '-'}',
          // Whether the app was in front when it died: a crash the user was
          // looking at and one in the background are different reports.
          'importance': '${info['importance'] ?? '-'}',
        },
      );

      // ANR hands back a plain-text trace. A native crash's is a tombstone
      // serialised as a protocol buffer, which needs the generated schema to
      // read — the reason alone still answers what nothing else could, which
      // is whether the exit was a native crash at all.
      //
      // TODO(tombstone): decode the API 31+ protobuf so a native crash carries
      // its stack rather than only its name.
      final trace = info['trace'];
      if (trace is String && trace.isNotEmpty) {
        // Both: the file is what a developer reads on the device, and
        // [lastExitTrace] is what reaches a report — which is assembled from
        // the *previous* run's file, where this could never appear.
        lastExitTrace = trace;
        CrashLog.write('--- previous exit ($reason) trace ---\n$trace');
      }

      // Makes the prompt appear on this launch rather than the next. The
      // marker exists because a Dart crash has no way to tell the following
      // launch anything; the platform is telling us directly, about a run
      // that is already over, so there is nothing to route through a file.
      if (crashed) CrashLog.reportPreviousRunCrashed();
    } catch (e, s) {
      Loggers.app.warning('NativeExitReport.apply', e, s);
    }
  }
}
