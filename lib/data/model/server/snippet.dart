import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/src/rust/api/snippet.dart' as ffi;
import 'package:xterm/core.dart';

part 'snippet.g.dart';
part 'snippet.freezed.dart';

@freezed
abstract class Snippet with _$Snippet {
  const factory Snippet({
    /// Generated. A snippet used to be keyed by [name], so renaming one was a
    /// delete and an insert — and `snippetOrder` still pointed at the old name.
    required String id,
    required String name,
    required String script,
    List<String>? tags,
    String? note,

    /// Server ids on which this snippet runs automatically.
    List<String>? autoRunOn,
  }) = _Snippet;

  /// A record written before snippets had ids gets one here.
  ///
  /// Safe to generate rather than derive: nothing references a snippet. Its
  /// `autoRunOn` names *servers*, and `snippetOrder` is a list of names.
  factory Snippet.fromJson(Map<String, dynamic> json) => _$SnippetFromJson({
    ...json,
    if ((json['id'] as String?)?.isNotEmpty != true) 'id': ShortId.generate(),
  });

  static const example = Snippet(
    id: 'example',
    name: 'example',
    script: 'echo hello',
    tags: ['tag'],
    note: 'note',
    autoRunOn: ['server_id'],
  );
}

/// A snippet the server it was run for cannot answer.
final class SnippetException implements Exception {
  const SnippetException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The macros are `sbm_parser::snippet`'s — the expansion the monitor agent's
/// panel uses too. This extension only says what the app knows about a server
/// and carries out the steps Rust answers with.
extension SnippetX on Snippet {
  /// Whether this script names something only a server has.
  ///
  /// `${host}`, `${user}` and the rest are answered from a [Spi]. A terminal on
  /// this device has none, so a snippet that asks for one is not a snippet it
  /// can run.
  bool get needsServer => ffi.snippetUsesServerContext(script: script);

  /// The script as one command on [spi], for running rather than typing:
  /// `${sleep}`, `${ctrl+…}` and the other terminal macros stay as written.
  String fmtWithSpi(Spi? spi) =>
      _call(() => ffi.snippetExpand(script: script, contextJson: _context(spi)));

  /// Types this snippet into [terminal]. A placeholder can wait (`${sleep N}`);
  /// after each wait the rest is typed only while [alive] says the shell it
  /// began in is still the one [terminal] writes to — a reconnect or a switch
  /// to tmux replaces it, and the rest was not written for that one.
  ///
  /// Throws a [SnippetException], before typing anything, for a placeholder
  /// [spi] cannot answer — a password on a key-authenticated server, say.
  Future<void> runInTerm(
    Terminal terminal,
    Spi? spi, {
    bool autoEnter = false,
    bool Function()? alive,
  }) async {
    final json = _call(
      () => ffi.snippetPlan(script: script, contextJson: _context(spi)),
    );
    final steps = (jsonDecode(json) as List).cast<Map<String, Object?>>();

    // That one ran, and whether it was parameterised — never the script, the
    // name or the server. `interactive` is a snippet typed in pieces, which is
    // a different feature from pasting a fixed command and the one worth
    // knowing is used before it is maintained.
    Diag.crumb(
      SbDiag.snippet,
      'run',
      data: {
        'interactive': steps.every((s) => s['type'] == 'text') ? 'no' : 'yes',
      },
    );

    for (final step in steps) {
      switch (step['type']) {
        case 'text':
          terminal.textInput(step['text'] as String);
        case 'combo':
          final key = step['key'] as String;
          final ok = terminal.charInput(
            key.codeUnitAt(0),
            ctrl: step['ctrl'] == true,
            alt: step['alt'] == true,
          );
          if (!ok) Loggers.app.warning('Failed to input: $key');
          terminal.textInput(step['rest'] as String);
        case 'sleep':
          await Future.delayed(Duration(seconds: step['seconds'] as int));
          if (alive != null && !alive()) return;
        case 'enter':
          for (var i = 0; i < (step['times'] as int); i++) {
            terminal.keyInput(TerminalKey.enter);
          }
      }
    }

    if (autoEnter) terminal.keyInput(TerminalKey.enter);
  }

  /// The six `${…}` a server answers, for the editor's help text.
  static List<String> get serverKeys =>
      [for (final key in ffi.snippetServerKeys()) '\${$key}'];

  /// What [spi] can answer. An absent key is a value the app does not have —
  /// no SSH credential, or one without a password — and a script that asks
  /// for it is refused rather than run with a hole in it.
  static String _context(Spi? spi) {
    if (spi == null) return '{}';
    final ssh = spi.ssh;
    return jsonEncode({
      if (ssh != null) ...{
        'host': ssh.ip,
        'port': ssh.port.toString(),
        'user': ssh.user,
        'pwd': ?ssh.pwd,
      },
      'id': spi.id,
      'name': spi.name,
    });
  }

  static String _call(String Function() run) {
    try {
      return run();
    } on ffi.SnippetFfiError catch (e) {
      throw SnippetException(switch (e.code) {
        'unanswerable' => 'This server has no value for \${${e.key}}',
        _ => e.code,
      });
    }
  }
}
