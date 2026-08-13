import 'dart:async';

/// What a command left behind.
class ExecResult {
  const ExecResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// Null where the source cannot report one — a shell that was closed rather
  /// than exited.
  final int? exitCode;
  final String stdout;
  final String stderr;

  /// Both streams in the order a terminal would have shown them. Most callers
  /// want this: they are parsing what a command printed, not auditing which
  /// file descriptor it used.
  String get combined => stderr.isEmpty ? stdout : '$stdout$stderr';

  bool get succeeded => exitCode == 0 || (exitCode == null && stderr.isEmpty);
}

typedef OnExecOutput = void Function(String chunk);

/// Running one command on a server and collecting what it printed.
///
/// The pages that list processes, units and containers, and the ones that run
/// a snippet or power the machine down, all want the same thing: a command
/// goes out, its output comes back. None of them wants an interactive shell —
/// that is `ShellBackend` — and none of them should have to know that SSH is
/// what happens to provide it. Reaching for `ServerState.client` made every
/// one of them know, which is why a server reached over its monitor agent
/// could only ever show a status page: there was no `SSHClient` to hand them,
/// and nothing else they could have been given.
///
/// The seam is here rather than at `SSHClient` because "run this and tell me
/// what it said" is a smaller promise than SSH makes, and it is the whole of
/// what these callers need. Anything that genuinely needs more — a byte
/// stream for SFTP or a forwarded port — asks for that instead, and gets it
/// from somewhere that can promise it.
abstract interface class ServerExec {
  /// Runs [script] and collects its output.
  ///
  /// [entry] is the interpreter it is fed to, defaulting to a POSIX shell
  /// reading the script on stdin — which is how a multi-line script survives
  /// quoting. [stdin] is written before that input closes, and is how a sudo
  /// password gets in without a terminal to type it into.
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
  });
}
