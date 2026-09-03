import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/service/tombstone.dart';
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

  /// The crash the platform reported, held until there is a sink to report it
  /// to.
  ///
  /// **Held rather than sent, because of when this runs.** `collect` is called
  /// from `_initData`, and `DiagnosticsUpload.sync` — which is what installs a
  /// sink that uploads — is called after it and is not awaited. Reporting
  /// inline would hand every native crash to whatever sink happened to be
  /// installed at that moment, which is the local file and nothing else. So
  /// `DiagnosticsUpload` calls [reportPending] once its sink is in place, and
  /// a level that does not upload simply never calls it.
  ///
  /// Cleared as it is read, so one crash is reported once. `apply` already
  /// refuses a record it has seen, but MetricKit's path has no timestamp to
  /// deduplicate by and relies on the platform clearing what it hands over.
  ///
  /// **Persisted, because in memory it was lost by the launch that most needed
  /// it.** `apply` writes `lastExitInfoTs` before this is set, so the record
  /// counts as handled from that moment on; a launch that then died before
  /// reaching a sink dropped the crash *and* left nothing for the next launch
  /// to find. In [PrefStore] rather than a setting, for the same reason as
  /// the analytics identity: the backup file carries every setting, and a
  /// restored backup replaying someone else's crash is nonsense.
  static const _pendingKey = 'native_exit_pending';

  /// This run's copy, so the common case never touches storage: a crash held
  /// and reported within one launch is read straight back from here.
  static ({Object error, StackTrace? trace})? _pending;

  /// The trace is deliberately not kept here. A decoded tombstone runs to tens
  /// of kilobytes and `SharedPreferences` is the wrong place for it; the run
  /// that produced it already wrote it to the log file, which is what a manual
  /// report quotes. What survives is the fact and the reason — enough to know
  /// a native crash happened at all, which is what was missing.
  static void _holdCrash(String reason, Object? status, String? trace) {
    _pending = (
      error: NativeExitError(reason, status: status),
      trace: trace == null || trace.isEmpty ? null : StackTrace.fromString(trace),
    );
    unawaited(
      PrefStore.shared.set(_pendingKey, '$reason\u0000${status ?? ''}'),
    );
  }

  /// The previous run's native stack or ANR trace, when the platform had one.
  ///
  /// Separate from [lastExit] because it is large — a MetricKit call stack is
  /// capped at 16 KB, an ANR trace is a full thread dump, and a decoded
  /// tombstone is a signal line and a stack — and because it belongs in a
  /// report as a block rather than as a field. Held for the same reason: it
  /// describes the run that died and is only learned about after that run's
  /// log has been closed.
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

    if (crashed) {
      CrashLog.reportPreviousRunCrashed();
      // `lastExitTrace` rather than a local: the loop above has already picked
      // the crash's call stack over any hang's, which is the one worth
      // reporting when both were delivered together.
      _holdCrash(
        'metrickit crash',
        lastExit?['signal'],
        lastExitTrace,
      );
    }
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

      // Two shapes, decided by the reason. ANR hands back a thread dump as
      // plain text; a native crash hands back a tombstone as a protocol
      // buffer, which [Tombstone.decode] turns into the text a tombstone is
      // usually read as. Either way what lands here is a trace, and the rest
      // of this method does not need to know which it was.
      //
      // The protobuf is preferred when both are present, which does not happen
      // today — the platform side sends one or the other — and would mean the
      // structured record and the text disagreed if it did.
      final proto = info['traceProto'];
      final trace = proto is Uint8List
          ? Tombstone.decode(proto)
          : info['trace'] as String?;
      if (trace != null && trace.isNotEmpty) {
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
      if (crashed) {
        CrashLog.reportPreviousRunCrashed();
        // Held, not sent: nothing that uploads is installed this early — see
        // [_pending]. `trace` is the tombstone or thread dump decoded above,
        // so the report carries the stack rather than only the reason.
        _holdCrash(reason, info['status'], trace);
      }
    } catch (e, s) {
      Loggers.app.warning('NativeExitReport.apply', e, s);
    }
  }

  /// Hands the held crash to whatever sink is now installed.
  ///
  /// Called by `DiagnosticsUpload` once it has one, and by nothing else: a
  /// level that does not upload never calls this, so the record stays held and
  /// dies with the process — which is the same thing as not reporting it.
  static void reportPending() {
    final pending = _pending ?? _readPersisted();
    if (pending == null) return;
    _pending = null;
    unawaited(PrefStore.shared.remove(_pendingKey));
    Diag.error(pending.error, pending.trace, 'native exit');
  }

  /// Drops the in-memory copy, leaving only what was persisted — which is
  /// what a process death does. Tests only.
  @visibleForTesting
  static void debugForgetPending() => _pending = null;

  /// A crash held by a launch that never reached a sink.
  ///
  /// No trace: see [_holdCrash]. The reason alone still answers the question
  /// nothing else can, which is whether the app died in native code.
  static ({Object error, StackTrace? trace})? _readPersisted() {
    final raw = PrefStore.shared.get<String>(_pendingKey);
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('\u0000');
    final status = parts.length > 1 && parts[1].isNotEmpty
        ? int.tryParse(parts[1]) ?? parts[1]
        : null;
    return (
      error: NativeExitError(parts.first, status: status),
      trace: null,
    );
  }

}

/// A death outside Dart, in the shape a reporting sink understands.
///
/// There is no exception and no Dart stack for a process the kernel killed, so
/// one is made here. **The message is short and stable on purpose**: a backend
/// groups by type and value, and a tombstone's addresses differ on every
/// crash — putting them here would file every occurrence as its own issue and
/// hide the fact that it is one bug. The addresses travel in the stack trace,
/// and the record's own fields travel in the breadcrumb `apply` writes.
final class NativeExitError implements Exception {
  const NativeExitError(this.reason, {this.status});

  /// `crash_native`, `anr`, `signaled`, `metrickit crash`, …
  final String reason;

  /// The signal number for `signaled`, the exit status otherwise. Part of the
  /// message because a SIGSEGV and a SIGABRT are different bugs; not enough of
  /// it varies to break grouping.
  final Object? status;

  @override
  String toString() {
    final status = this.status;
    return status == null || status == 0
        ? 'Native exit: $reason'
        : 'Native exit: $reason ($status)';
  }
}
