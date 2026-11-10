import 'dart:async';

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
      _call(() => ffi.snippetExpand(script: script, context: _context(spi)));

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
    final steps = _call(() => ffi.snippetPlan(script: script, context: _context(spi)));

    // That one ran, and whether it was parameterised — never the script, the
    // name or the server. `interactive` is a snippet typed in pieces, which is
    // a different feature from pasting a fixed command and the one worth
    // knowing is used before it is maintained.
    Diag.crumb(
      SbDiag.snippet,
      'run',
      data: {
        'interactive': steps.every((s) => s is ffi.Step_Text) ? 'no' : 'yes',
      },
    );

    for (final step in steps) {
      switch (step) {
        case ffi.Step_Text(:final text):
          terminal.textInput(text);
        case ffi.Step_Combo(:final ctrl, :final alt, :final key, :final rest):
          final ok = terminal.charInput(key.codeUnitAt(0), ctrl: ctrl, alt: alt);
          if (!ok) Loggers.app.warning('Failed to input: $key');
          terminal.textInput(rest);
        case ffi.Step_Sleep(:final seconds):
          await Future.delayed(Duration(seconds: seconds.toInt()));
          if (alive != null && !alive()) return;
        case ffi.Step_Enter(:final times):
          for (var i = 0; i < times; i++) {
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
  static ffi.SnippetContext _context(Spi? spi) {
    final ssh = spi?.ssh;
    return ffi.SnippetContext(
      host: ssh?.ip,
      port: ssh?.port.toString(),
      user: ssh?.user,
      pwd: ssh?.pwd,
      id: spi?.id,
      name: spi?.name,
    );
  }

  static T _call<T>(T Function() run) {
    try {
      return run();
    } on ffi.PlanError catch (e) {
      throw SnippetException(switch (e) {
        ffi.PlanError_Unanswerable(:final key) => 'This server has no value for \${$key}',
      });
    }
  }
}
