import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/core/service/native_exit.dart';
import 'package:server_box/core/utils/ssh_file_backend.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';

/// The text a user pastes into an issue after a crash.
///
/// Markdown, because that is where it is going. The log is fenced so that a
/// stack trace keeps its line breaks, and the environment is a list because it
/// is the part that gets read first and the part reporters most often leave
/// out — every one of the three open crash reports named a version and none
/// named the same thing twice.
///
/// **Not claimed to be anonymous.** Crumbs go through [Redact], but the log
/// also holds records this app has been writing for years, and some of those
/// format a server name into the message. Saying "redacted" about the whole
/// file would be false, and a user who believed it would post something they
/// would not have. The dialog shows the text and says to read it; this is why.
abstract final class CrashReport {
  /// How much of the log goes in.
  ///
  /// From the *end*: the lines nearest the crash are the ones worth having,
  /// and a report starting at launch and stopping halfway is the wrong half.
  /// Also keeps the text small enough to render in a dialog — the file itself
  /// is allowed to be twenty times this.
  static const maxLogChars = 24 * 1024;

  /// The kept report's filename, beside the logs it is made from.
  static const savedName = 'crash_report.md';

  /// Where the previous run's report waits for somebody to go and read it.
  ///
  /// **It has to be kept, because nothing prompts for it any more.** The toast
  /// this replaced was raised on the one launch that read the marker, and that
  /// was the only moment the report existed: `app.log.1` is the *previous*
  /// run's log, so the launch after next overwrites the crashed run's with an
  /// ordinary one. A row in Settings the user reaches whenever they get round
  /// to it needs the report to still be there when they do.
  ///
  /// Null before [CrashLog.attach] has run, which is the same window in which
  /// there is no log to build one from.
  static String? get savedPath => CrashLog.dirPath?.joinPath(savedName);

  /// Whether an unhandled error is something *this app* got wrong.
  ///
  /// It gates the marker, and the marker raises a dialog on the next launch
  /// asking the user to file a report — so what goes in it has to be something
  /// a report could act on. A machine that is off, a link that dropped, a
  /// server that answers the sftp subsystem with the output of a login script:
  /// those are conditions of the world. The user watched them fail, the
  /// failure is in the log either way, and being asked at the next launch to
  /// report the network is the kind of noise that teaches people to dismiss
  /// the dialog without reading it — including the time it is real.
  ///
  /// Narrow on purpose, and not an excuse. An error that reaches the zone
  /// handler at all is a routing bug: something failed to hand it to the page
  /// that asked, which is what the file browser's error view is for. This only
  /// decides whether to interrupt the user about it.
  static bool isAppFault(Object error) {
    // Both are wrappers with the original inside, and it is the original that
    // says where the failure came from.
    if (error is SftpUnavailable) return isAppFault(error.cause);
    if (error is AsyncError) return isAppFault(error.error);

    // The whole `dart:io` family: a socket that would not open, a TLS
    // handshake that failed, a process that would not start, a file the OS
    // refused. `FileSystemException` is in there too, and included
    // deliberately — a disk that is full or a directory that is not ours reads
    // exactly like a path this app got wrong, and of the two only one is worth
    // waking someone about.
    if (error is IOException) return false;
    if (error is TimeoutException) return false;

    // Neither implements `Exception`, so neither is covered above.
    if (error is SSHError || error is SftpError) return false;
    if (error is DioException) return false;

    return true;
  }

  /// Builds the report from the previous run's log.
  static Future<String> build() async => compose(
    log: await CrashLog.readPrevious(),
    build: BuildData.build,
    os: '${Pfs.type.name} ${Platform.operatingSystemVersion}',
    locale: Platform.localeName,
    identifiers: knownIdentifiers(Stores.server.fetch()),
    previousExit: NativeExitReport.lastExit,
    previousExitTrace: NativeExitReport.lastExitTrace,
  );

  /// Keeps the previous run's report, and sends the part that may be sent.
  ///
  /// Called once at launch, after `NativeExitReport.collect` has had its say
  /// about how the process died and after `DiagnosticsUpload.sync` has put the
  /// sink in — the first decides whether there is anything to report, the
  /// second decides whether it goes anywhere.
  ///
  /// **The two halves go to different places on purpose.** The report holds
  /// the previous run's log, and the log stays on the device at every level:
  /// `crashCollectNoneTip` and `crashCollectBasicTip` both say so, and the log
  /// is the one thing this app writes that nobody has audited for what it
  /// might name — see the note on this class. So the file is written for the
  /// user to read and copy, and what is uploaded is the error alone.
  static Future<void> collect() async {
    await keep();
    report();
  }

  /// Writes the report, and waits for nothing to do it.
  ///
  /// **Separate from [report] because only one of the two needs the upload
  /// sink.** Chained behind `DiagnosticsUpload.sync`, this waited on
  /// `Sentry.init` and two analytics clients — network-capable work the line
  /// starting them says must not hold up startup. Somebody on `full` with a
  /// slow endpoint who went straight to Settings → Privacy found no row: the
  /// file was not written yet, and `saved()` is a future that page's build
  /// captured rather than a listenable, so it did not appear until they left
  /// and came back.
  static Future<void> keep() async {
    if (!CrashLog.lastRunEndedBadly) return;
    final path = savedPath;
    if (path == null) return;
    try {
      // Replaces rather than accumulates. The newest crash is the one worth
      // reporting, and a directory of them is a disclosure risk that grows
      // on its own.
      await File(path).writeAsString(await build());
    } catch (e, s) {
      Loggers.app.warning('Could not keep the crash report', e, s);
    }
  }

  /// Files the error, which needs a sink and so has to come after one.
  static void report() {
    if (!CrashLog.lastRunEndedBadly) return;
    _reportPrevious();
  }

  /// The kept report, or null when nothing has crashed since it was last read.
  static Future<String?> saved() async {
    final path = savedPath;
    if (path == null) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e, s) {
      Loggers.app.warning('Could not read the kept crash report', e, s);
      return null;
    }
  }

  /// Takes the kept report off the device.
  ///
  /// Offered because it is the user's log and they should be able to be rid of
  /// it without waiting for the next crash to overwrite it — which is the only
  /// other thing that ever does.
  static Future<void> dropSaved() async {
    final path = savedPath;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e, s) {
      Loggers.app.warning('Could not drop the kept crash report', e, s);
    }
  }

  /// Files the error the previous run died on, without the log around it.
  ///
  /// Two things keep this from reporting a crash twice. [CrashLog.lastRunError]
  /// is null for a crash a sink already uploaded live — see
  /// [CrashLog.uploadsNow] — and it is null for one the platform reported,
  /// which `NativeExitReport.reportPending` sends on its own path. What is
  /// left is the case neither reaches: an error early in startup, before there
  /// was a sink to hand it to. That was previously reported by nobody, and it
  /// is the class of failure a user can say least about.
  static void _reportPrevious() {
    if (!DiagnosticsUpload.level.uploads) return;
    final detail = CrashLog.lastRunError;
    if (detail == null) return;

    // Split rather than sent whole: a backend groups by the error's text, and
    // a stack folded into it would file every occurrence as its own issue.
    final split = detail.indexOf('\n');
    final message = split == -1 ? detail : detail.substring(0, split);
    final stack = split == -1 ? null : detail.substring(split + 1).trim();
    Diag.error(
      PreviousRunError(message),
      stack == null || stack.isEmpty ? null : StackTrace.fromString(stack),
      'previous run',
    );
  }

  /// Every string this install knows to be the user's, and what replaces it.
  ///
  /// Precise rather than pattern-based, which is the whole point. A regex for
  /// "things that look like a host" both misses — a machine called `nas` is
  /// not a pattern — and overreaches, since a package name in a stack trace
  /// looks like a domain. The app holds the actual records, so it can replace
  /// exactly the strings that came out of them.
  ///
  /// This is what makes the log readable in the Logs page and safe in a
  /// report: the two readers want opposite things, and the split belongs here
  /// rather than at the point the line was written.
  ///
  /// Numbered rather than hashed. A reader following one server through a log
  /// needs to see the same token twice; they do not need it to mean anything.
  @visibleForTesting
  static Map<String, String> knownIdentifiers(List<Spi> servers) {
    final out = <String, String>{};
    for (var i = 0; i < servers.length; i++) {
      final spi = servers[i];
      final n = i + 1;
      _addIdentifier(out, spi.name, '<server-$n>');
      _addIdentifier(out, spi.ssh?.ip, '<host-$n>');
      _addIdentifier(out, spi.ssh?.user, '<user-$n>');
      _addIdentifier(out, spi.monitorHttp?.addr, '<agent-$n>');
    }
    return out;
  }

  /// Too short to substitute safely is left alone: a two-character name occurs
  /// inside ordinary words, and replacing it would corrupt the log rather than
  /// redact it. Such a name identifies little in any case.
  static void _addIdentifier(
    Map<String, String> out,
    String? value,
    String replacement,
  ) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.length < 3) return;
    out[trimmed] = replacement;
  }

  @visibleForTesting
  static String compose({
    required String? log,
    required int build,
    required String os,
    required String locale,
    Map<String, String> identifiers = const {},
    Map<String, String>? previousExit,
    String? previousExitTrace,
    int maxLogChars = maxLogChars,
  }) {
    final buf = StringBuffer()
      ..writeln('### Environment')
      ..writeln()
      ..writeln('- App: $build')
      ..writeln('- OS: $os')
      ..writeln('- Locale: $locale');

    // The platform's account of how the previous run ended, which is the one
    // fact a report assembled only from the previous run's log cannot contain:
    // a native crash leaves nothing behind in the run it kills, and the record
    // of it arrives on the next launch — into a different file.
    if (previousExit != null && previousExit.isNotEmpty) {
      final fields = previousExit.entries
          .map((e) => '${e.key} ${e.value}')
          .join(', ');
      buf.writeln('- Previous exit: $fields');
    }
    buf.writeln();

    // Before the log, because it describes the failure while the log only
    // leads up to it — and because it is the part a reader wants first. It is
    // not in the log at all: the platform hands it over on the launch after
    // the crash, into a file this report does not read.
    if (previousExitTrace != null && previousExitTrace.trim().isNotEmpty) {
      buf.writeln('### Previous exit trace');
      buf.writeln();
      buf.writeln('```');
      buf.writeln(_substitute(previousExitTrace.trimRight(), identifiers));
      buf.writeln('```');
      buf.writeln();
    }

    if (log == null || log.trim().isEmpty) {
      // Says so rather than showing an empty fence. An empty log is itself
      // information — it means the run died before anything was written, which
      // points at startup.
      buf.writeln('### Log');
      buf.writeln();
      buf.writeln('_No log was kept for the previous run._');
      return buf.toString();
    }

    var body = _substitute(log, identifiers);
    var truncated = false;
    if (body.length > maxLogChars) {
      body = body.substring(body.length - maxLogChars);
      truncated = true;
      // Whole lines only: cutting by character count lands mid-line, and a
      // half stack frame at the top reads as corruption.
      final firstBreak = body.indexOf('\n');
      if (firstBreak != -1) body = body.substring(firstBreak + 1);
    }

    buf.writeln('### Log');
    buf.writeln();
    if (truncated) buf.writeln('_Earlier lines omitted._');
    buf.writeln('```');
    buf.writeln(body.trimRight());
    buf.writeln('```');
    return buf.toString();
  }

  /// Applies [identifiers] in a single pass, longest match first.
  ///
  /// One pass, and that is the point rather than an optimisation. Replacing
  /// key by key means each pass can match inside a placeholder an earlier pass
  /// wrote: with servers named `prod-server` and `server`, the first becomes
  /// `<server-1>`, and the second's pass then rewrites the `server` inside it
  /// into `<<server-2>-1>`. The same happens to anything named `host`, `user`
  /// or `agent`. A scan over the original text can only match the original
  /// text.
  ///
  /// Longest first is still needed, for a different overlap: a machine called
  /// `db` and one called `db-prod` both match at the same position, and the
  /// short one winning would leave `<server-1>-prod` — still disclosing
  /// `-prod`, and no longer showing that two lines named different machines.
  /// Alternation in a Dart regex is ordered, so sorting decides it.
  static String _substitute(String text, Map<String, String> identifiers) {
    if (identifiers.isEmpty) return text;
    final keys = identifiers.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(keys.map(RegExp.escape).join('|'));
    return text.replaceAllMapped(
      pattern,
      (m) => identifiers[m[0]] ?? m[0]!,
    );
  }
}

/// An error the previous run died on, replayed on this one.
///
/// A type of its own rather than the original error rebuilt, because the
/// original is a *string* by the time it gets here — the marker holds text,
/// not an object — and handing a backend a bare string would file it under
/// whatever class that string happened to name. Wrapping says plainly that
/// this is a report about another run, which is the difference between "the
/// app crashed" and "the app crashed while starting up last time".
///
/// The message is the error's own text, so a backend groups these the way it
/// groups the live reports of the same failure. Mirrors [NativeExitError],
/// which does the same job for a death outside Dart.
final class PreviousRunError implements Exception {
  const PreviousRunError(this.message);

  /// The first line of what the marker kept: the error, without its stack.
  final String message;

  @override
  String toString() => 'Previous run: $message';
}
