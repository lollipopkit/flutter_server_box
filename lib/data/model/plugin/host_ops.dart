/// What the app can do on a plugin's behalf. PLUGINS.md section 4.3.
///
/// An interface rather than the app's own code called directly, and the reason
/// is what is worth testing: `PluginBridge` is the protocol — which JSON shape
/// means what, and which answer a malformed one gets — and that is checkable
/// only if the app underneath it can be replaced. The app's implementation is
/// `AppPluginHostOps`.
///
/// Nothing here checks a permission. The runtime turns an ungranted function
/// into a throwing stub before a plugin can call it and records a refusal
/// besides, so by the time a request reaches this it has already been allowed
/// — see `sbm_plugin::scope`.
library;

import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/model/server/server_exec.dart';

/// How a plugin's command ended.
enum PluginExecEnd {
  /// It ran to the end and the server reported an exit code.
  finished,

  /// The plugin asked for it to stop, through `sb.server.cancel`.
  cancelled,

  /// The `timeoutMs` the plugin gave ran out.
  ///
  /// The same mechanism as [cancelled] — the app stops waiting — and a
  /// separate value because they are different things to tell a user: one is
  /// what they asked for and the other is what they will want explained.
  timedOut,
}

/// What a command on a server answered.
///
/// A class rather than a record because most of it has an obvious default and
/// only [end] ever varies: an implementation that ran a command to the end
/// writes the three fields it already had.
class PluginExecResult {
  const PluginExecResult({
    required this.code,
    required this.stdout,
    required this.stderr,
    this.end = PluginExecEnd.finished,
    this.stoppedCommand = false,
  });

  final int code;
  final String stdout;
  final String stderr;

  final PluginExecEnd end;

  /// Whether the command was stopped **on the server**, or only stopped being
  /// waited for. Meaningless when [end] is [PluginExecEnd.finished].
  ///
  /// Carried rather than assumed because it is the transport's answer and not
  /// the caller's: an SSH channel signals the command, one HTTP request to an
  /// agent cannot — see [ExecCancelKind]. A plugin that told a user "stopped"
  /// on a machine still walking a filesystem would be wrong in the direction
  /// nobody checks.
  final bool stoppedCommand;

  /// The same shape [ExecCancelKind] states, for whoever has one in hand.
  static bool stoppedBy(ExecCancelKind kind) =>
      kind == ExecCancelKind.stopsCommand;
}

/// What a dialog answered. `values` is empty when it was cancelled.
typedef PluginPromptResult = ({bool cancelled, Map<String, String> values});

/// One field of a dialog.
class PluginPromptField {
  const PluginPromptField({
    required this.key,
    required this.label,
    this.secret = false,
    this.value,
  });

  final String key;
  final String label;
  final bool secret;

  /// What the box starts with.
  ///
  /// Never set for a `secret` field by a plugin that means it: pre-filling one
  /// puts a stored password on screen, which is what marking it secret was
  /// for. An untouched box then reads as "leave it as it was".
  final String? value;

  /// The same field with its label read in the user's language.
  ///
  /// The label is the only thing here the user sees. `value` is what goes in
  /// the box and comes back out — a crontab line, a path — and resolving it
  /// would mean a plugin's data changing on the way through.
  PluginPromptField translated(PluginL10n l10n) => PluginPromptField(
    key: key,
    label: l10n.resolve(label),
    secret: secret,
    value: value,
  );

  static PluginPromptField? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    if (key is! String || key.isEmpty) return null;
    return PluginPromptField(
      key: key,
      label: '${raw['label'] ?? key}',
      secret: raw['secret'] == true,
      value: raw['value'] is String ? raw['value'] as String : null,
    );
  }
}

/// What a request answered. `cert` is absent where there was no TLS.
typedef PluginFetchResult = ({
  int status,
  Map<String, String> headers,
  String body,
  String bodyEncoding,
  Map<String, Object?>? cert,
});

/// One server, as a plugin is allowed to see it.
///
/// A name and nothing else. An address, a user name and a port are what a
/// plugin would need to reach a machine behind the app's back, and no
/// permission grants them — `sb.server.exec` is how a plugin reaches a server,
/// and it goes through the app.
typedef PluginServerSummary = ({String id, String name});

abstract interface class PluginHostOps {
  /// Runs [script] on [serverId], which the bridge resolved from a handle the
  /// host itself issued.
  ///
  /// [timeout] and [cancel] are the same mechanism and the answer says which
  /// one fired: both stop the app waiting, and what that does to the command
  /// on the server is the transport's to report — see [PluginExecResult.end]
  /// and [PluginExecResult.stoppedCommand]. Neither is an exception, because a
  /// run that was stopped has an outcome worth carrying rather than a failure
  /// to raise.
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
    Future<void>? cancel,
  });

  /// One HTTP request, or — with [probeCert] — a handshake that sends nothing
  /// and answers with the certificate.
  ///
  /// [pinSha256] is the whole trust decision: absent refuses every
  /// certificate, since the alternative is trusting whatever answers the first
  /// time a request is made, and by then the request carries a password. The
  /// address list and the `probeCert` rules are the runtime's and have already
  /// been checked (`sbm_plugin::scope`).
  Future<PluginFetchResult> fetch({
    required String url,
    required String method,
    Map<String, String> headers,
    String? body,
    String bodyEncoding,
    String? pinSha256,
    bool probeCert,
    Duration? timeout,
  });

  /// Every server the user has, in the order the server tab shows them.
  ///
  /// For a surface bound to no one machine — a tab. Gated by `server.list`,
  /// which is deliberately not part of `server.exec`: exec acts on a machine
  /// the user pointed at, and this hands over the whole list with nobody
  /// choosing.
  Future<List<PluginServerSummary>> listServers();

  /// Opens a terminal on [serverId] with [cmd] typed into it.
  ///
  /// [run] sends it; the default does not, so the user reads the line before
  /// it runs and can edit it. A plugin that wants the output rather than the
  /// session has [exec] — this is for the commands a person should watch.
  Future<void> openTerminal(String serverId, {String? cmd, bool run = false});

  /// [kind] is `info`, `success`, `warn` or `error`.
  void toast(String text, String kind);

  /// Raises a dialog and waits for it.
  ///
  /// [fields] is the shorthand — a list of text boxes — and [node] is the
  /// general case: a tree drawn by the same renderer as any other surface, so
  /// a plugin's dialog is built out of the same controls as its page. Give one
  /// or the other; a [node] wins.
  ///
  /// [strings] is the plugin's own translations, for the [node]'s sake: the
  /// bridge resolves the title and the field labels before they get here, but
  /// a tree is resolved as it is drawn.
  ///
  /// [sheet] raises it from the bottom instead, which is what a form on a phone
  /// wants — the keyboard has somewhere to go.
  Future<PluginPromptResult> prompt({
    required String title,
    String? message,
    List<PluginPromptField> fields = const [],
    String? confirm,
    PluginNode? node,
    PluginL10n strings = PluginL10n.empty,
    bool sheet = false,
  });

  /// The server the user chose, or null if they did not choose one.
  Future<String?> pickServer();

  Future<String?> clipboardRead();

  Future<void> clipboardWrite(String text);

  Future<void> openServer(String serverId);

  /// [tab] is an `AppTab` name.
  Future<void> goTab(String tab);

  /// Records that something happened, never what.
  ///
  /// [name] comes from the plugin, so the app keeps it and the level and
  /// decides what else is safe to keep. A plugin that puts a value in the name
  /// has published it, which is why the interface has nowhere else to put one.
  void crumb(String pluginId, String name, String level);
}
