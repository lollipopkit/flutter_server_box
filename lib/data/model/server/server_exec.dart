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
  /// [script] is handed to the server's own shell as the command to run, so it
  /// may be a pipeline or several lines. [stdin] is written to it — a real
  /// input stream, which is how a sudo password gets in without a terminal to
  /// type it into, and the reason a password never has to be written into the
  /// command where a log or a process list would see it.
  ///
  /// [entry] is for the other shape: something that reads a script on *its*
  /// stdin rather than running one, which is what installing the status script
  /// is (`mkdir -p; cat > path; chmod`). Then [entry] is the command and
  /// [stdin] followed by [script] is what it reads.
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
  });
}

/// A sudo password the server rejected, told apart from any other failure.
///
/// `sudo` says so on stderr and then exits non-zero like everything else, so
/// without reading what it said a wrong password is indistinguishable from the
/// command itself failing — and the caller has no reason to ask for a new one.
const _sudoRejected = [
  'Sorry, try again.',
  'incorrect password attempt',
  'a password is required',
];

extension ServerExecSudo on ServerExec {
  /// Runs [script] with [password] on its stdin, reporting a rejected sudo
  /// password as exit code 2.
  ///
  /// The password goes here rather than into the command `sudo -S` is part of,
  /// which is what `sudo -S` reading stdin is for. Written into the command it
  /// would end up wherever that command is recorded — the agent's audit log,
  /// the machine's process list, a debug log — and none of those are places a
  /// password should be recoverable from.
  ///
  /// Null when the caller has no password to offer, which is the case where
  /// the far side is expected to allow the command without one.
  Future<ExecResult> runWithSudo(
    String script, {
    String? password,
    String? entry,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
  }) async {
    var rejected = false;
    final result = await run(
      script,
      entry: entry,
      // A newline of its own: `sudo -S` reads one line and stops, and a
      // password the user did not end with Enter would otherwise hang it.
      stdin: password == null ? null : '$password\n',
      onStdout: onStdout,
      onStderr: (chunk) {
        onStderr?.call(chunk);
        if (_sudoRejected.any(chunk.contains)) rejected = true;
      },
    );
    if (!rejected) return result;
    return ExecResult(
      exitCode: 2,
      stdout: result.stdout,
      stderr: result.stderr,
    );
  }
}
