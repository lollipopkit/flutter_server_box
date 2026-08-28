import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
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

  /// Builds the report from the previous run's log.
  static Future<String> build() async => compose(
    log: await CrashLog.readPrevious(),
    build: BuildData.build,
    os: '${Pfs.type.name} ${Platform.operatingSystemVersion}',
    locale: Platform.localeName,
    identifiers: knownIdentifiers(Stores.server.fetch()),
  );

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
    int maxLogChars = maxLogChars,
  }) {
    final buf = StringBuffer()
      ..writeln('### Environment')
      ..writeln()
      ..writeln('- App: $build')
      ..writeln('- OS: $os')
      ..writeln('- Locale: $locale')
      ..writeln();

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

  /// Applies [identifiers], longest match first.
  ///
  /// The ordering is not cosmetic: a server called `db` and one called
  /// `db-prod` overlap, and replacing the short one first leaves
  /// `<server-1>-prod` — which still says there is a `-prod` and has lost the
  /// fact that the two lines named different machines.
  static String _substitute(String text, Map<String, String> identifiers) {
    if (identifiers.isEmpty) return text;
    final keys = identifiers.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    var out = text;
    for (final key in keys) {
      out = out.replaceAll(key, identifiers[key]!);
    }
    return out;
  }
}
