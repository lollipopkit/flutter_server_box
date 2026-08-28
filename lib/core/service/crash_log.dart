import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Keeps a crashed run's log where the crash cannot take it.
///
/// [DebugProvider] holds a hundred lines in memory and the Logs page renders
/// them, which covers a user who notices something and goes looking. It cannot
/// cover a crash: the process is gone and the list with it. On the reports this
/// exists for the app was not reachable afterwards at all — one of them crashed
/// during launch, so no page could be opened to copy anything out of.
///
/// Three consequences shape what is here.
///
/// The sink is a file, and it is attached to the log stream *before* the parts
/// of startup most likely to fail. [handleErrors] runs first and buffers into
/// memory, [attach] hands that buffer to disk once there is a path to write to;
/// nothing between the two is lost, which matters because `RustLib.init`,
/// `Stores.init` and the schema migration all happen in there.
///
/// The previous run's file is kept whole rather than appended to. The run that
/// crashed is the one worth reading, and one file holding both interleaves the
/// crash with whatever the user did next.
///
/// Writes are synchronous. A crash gives no chance to flush, and the last lines
/// before it are the point of the file. The log level is WARNING, so this is
/// not on any hot path.
abstract final class CrashLog {
  /// The run happening now.
  @visibleForTesting
  static const currentName = 'app.log';

  /// The run before this one, kept whole. What a report is built from.
  @visibleForTesting
  static const previousName = 'app.log.1';

  /// Written when a handler here sees an error nothing else caught, read on the
  /// next launch, and deleted once read.
  ///
  /// A file rather than a line in the log, so that answering "did the last run
  /// end badly" does not mean parsing one — and so that a native crash handler
  /// could set it later without agreeing on a log format first.
  @visibleForTesting
  static const markerName = 'unhandled';

  /// A ceiling, not a target: a run that loops on an error would otherwise fill
  /// the disk. Past this the file stops growing and says so on its last line.
  @visibleForTesting
  static const maxBytes = 512 * 1024;

  static Directory? _dir;
  static RandomAccessFile? _file;
  static int _written = 0;
  static bool _truncated = false;
  static bool _lastRunEndedBadly = false;
  static StreamSubscription<LogRecord>? _sub;
  static bool _installed = false;
  static FlutterExceptionHandler? _prevFlutterOnError;
  static bool Function(Object, StackTrace)? _prevPlatformOnError;

  /// Lines logged before [attach] found somewhere to put them.
  static final _pending = <String>[];

  /// How many of those are kept. Startup between the two calls logs a handful
  /// on a healthy launch; this is a bound for the launch that is not healthy.
  static const _maxPending = 200;

  /// Whether the previous run ended on an error no handler expected.
  ///
  /// False until [attach] has run. Says nothing about a run the user ended
  /// themselves, or one Android reclaimed while it sat in the background —
  /// neither leaves the marker, which is the reason the marker exists rather
  /// than a "did we exit cleanly" flag. Flutter gets no reliable say in when it
  /// is being killed, so a flag like that reads a backgrounded app as a crash.
  static bool get lastRunEndedBadly => _lastRunEndedBadly;

  /// Installs the error handlers and starts buffering.
  ///
  /// Call before anything that can fail, and before [attach]: the errors worth
  /// catching most are the ones that stop the app from finishing startup, and
  /// those happen before there is a writable path.
  ///
  /// The handlers are additive. [FlutterError.onError] keeps presenting the
  /// error the way it did — the red screen in debug is how a developer notices
  /// at all — and [PlatformDispatcher.instance.onError] answers false so the
  /// zone in `main` still sees what it saw before.
  static void handleErrors() {
    // Idempotent: a second call would wrap the handlers this one installed,
    // and every error would then be recorded once per call.
    if (_installed) return;
    _installed = true;

    _sub = Logger.root.onRecord.listen(_onRecord);

    final presentError = _prevFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // `silent` is set for errors the framework expects to handle itself, and
      // for the second and later copies of one it already reported.
      if (!details.silent) {
        _recordUnhandled('FlutterError', details.exception, details.stack);
      }
      presentError?.call(details);
    };

    // Errors that reach the engine with nothing in Dart having handled them.
    // Answering false leaves them unhandled, which is what keeps `main`'s
    // `runZonedGuarded` reporting them as it does today.
    final onError = _prevPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, s) {
      _recordUnhandled('PlatformDispatcher', e, s);
      return onError?.call(e, s) ?? false;
    };
  }

  /// Rotates the previous run's file out of the way and starts writing.
  ///
  /// Best effort by construction: a device that cannot be written to is not one
  /// where the app should refuse to start, and every failure here costs a log
  /// rather than a feature. [handleErrors] keeps buffering if this never runs.
  static Future<void> attach(String dirPath) async {
    if (_file != null) return;
    try {
      final dir = await Directory(dirPath).create(recursive: true);
      _dir = dir;

      _lastRunEndedBadly = await _takeMarker(dir);

      final current = File(_path(dir, currentName));
      if (await current.exists()) {
        // `rename` over an existing file replaces it on POSIX and throws on
        // Windows, and this has to behave the same on both.
        final previous = File(_path(dir, previousName));
        if (await previous.exists()) await previous.delete();
        await current.rename(previous.path);
      }

      _file = await current.open(mode: FileMode.writeOnlyAppend);
      _written = 0;
      _truncated = false;

      final pending = List.of(_pending);
      _pending.clear();
      for (final line in pending) {
        _writeLine(line);
      }
    } catch (e, s) {
      // Not through `Loggers`: that arrives back here and finds no file, so it
      // would only fill the buffer this failure means nothing will ever drain.
      debugPrint('CrashLog.attach($dirPath): $e\n$s');
    }
  }

  /// The previous run's log, or null when there is none to read.
  static Future<String?> readPrevious() async {
    final dir = _dir;
    if (dir == null) return null;
    try {
      final previous = File(_path(dir, previousName));
      if (!await previous.exists()) return null;
      return await previous.readAsString();
    } catch (e, s) {
      debugPrint('CrashLog.readPrevious: $e\n$s');
      return null;
    }
  }

  /// Drops both runs' logs and the marker.
  static Future<void> clear() async {
    final dir = _dir;
    if (dir == null) return;
    try {
      await _file?.close();
      _file = null;
      for (final name in const [currentName, previousName, markerName]) {
        final file = File(_path(dir, name));
        if (await file.exists()) await file.delete();
      }
      _lastRunEndedBadly = false;
      final current = File(_path(dir, currentName));
      _file = await current.open(mode: FileMode.writeOnlyAppend);
      _written = 0;
      _truncated = false;
    } catch (e, s) {
      debugPrint('CrashLog.clear: $e\n$s');
    }
  }

  /// Reverts everything [handleErrors] and [attach] installed. Tests only.
  @visibleForTesting
  static Future<void> resetForTest() async {
    await _sub?.cancel();
    _sub = null;
    await _file?.close();
    _file = null;
    _dir = null;
    _pending.clear();
    _written = 0;
    _truncated = false;
    _lastRunEndedBadly = false;
    if (_installed) {
      FlutterError.onError = _prevFlutterOnError;
      PlatformDispatcher.instance.onError = _prevPlatformOnError;
      _prevFlutterOnError = null;
      _prevPlatformOnError = null;
      _installed = false;
    }
  }

  static void _onRecord(LogRecord record) {
    final buf = StringBuffer()
      ..write('[${record.time.toIso8601String()}]')
      ..write('[${record.loggerName}][${record.level.name}] ')
      ..write(record.message);
    if (record.error != null) buf.write(': ${record.error}');
    final trace = record.stackTrace;
    if (trace != null) buf.write('\n$trace');
    _writeLine(buf.toString());
  }

  /// Logged and marked. The mark is what the next launch reads.
  static void _recordUnhandled(String source, Object error, StackTrace? stack) {
    Loggers.app.severe('Unhandled ($source)', error, stack);
    _leaveMarker();
  }

  static void _writeLine(String line) {
    final file = _file;
    if (file == null) {
      // Bounded, and the newest is what is kept: an app that never reaches
      // [attach] must not grow a list until it dies of that instead, and when
      // the buffer does reach disk the lines nearest the failure are the ones
      // worth having. Same end as [DebugProvider] drops.
      if (_pending.length >= _maxPending) _pending.removeAt(0);
      _pending.add(line);
      return;
    }
    if (_truncated) return;

    try {
      final bytes = utf8.encode('$line\n');
      if (_written + bytes.length > maxBytes) {
        _truncated = true;
        file.writeStringSync('--- log full, further lines dropped ---\n');
        file.flushSync();
        return;
      }
      file.writeFromSync(bytes);
      file.flushSync();
      _written += bytes.length;
    } catch (e) {
      // A full disk, or a file the OS took away. Dropping the line is the only
      // option that does not turn logging into its own crash.
      debugPrint('CrashLog write: $e');
    }
  }

  static void _leaveMarker() {
    final dir = _dir;
    if (dir == null) return;
    try {
      File(_path(dir, markerName)).writeAsStringSync('');
    } catch (e) {
      debugPrint('CrashLog marker: $e');
    }
  }

  /// Reads the marker and removes it, so one crash is reported once.
  static Future<bool> _takeMarker(Directory dir) async {
    try {
      final marker = File(_path(dir, markerName));
      if (!await marker.exists()) return false;
      await marker.delete();
      return true;
    } catch (e) {
      debugPrint('CrashLog marker: $e');
      return false;
    }
  }

  static String _path(Directory dir, String name) =>
      dir.path.joinPath(name);
}
