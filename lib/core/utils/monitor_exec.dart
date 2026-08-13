import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// [ServerExec] over a `monitor` agent's HTTP API.
///
/// One request per command, on the same authenticated session the status poll
/// uses. There is no second channel to open because there is no connection to
/// multiplex — which is the whole reason this exists: a server reached only
/// over its agent has no `SSHClient` to hand the process list, systemd or the
/// container pages, and before this it could show a status page and nothing
/// else.
///
/// The agent runs the command as the account it runs as, and a panel login is
/// the only thing authorising it. It decides whether to offer that at all
/// (`remote_access.full_access`) and re-checks per request, so this is never
/// the thing granting access — it only asks.
class MonitorExec implements ServerExec {
  const MonitorExec(this.client);

  final MonitorHttpClient client;

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
  }) async {
    // The same shape [SshExec] gives it: with no [entry] the script is the
    // command and stdin is left to be stdin, so a sudo password never has to
    // be written into the command the agent records.
    final out = await client.exec(
      entry ?? script,
      stdin: entry == null ? stdin : '${stdin ?? ''}$script\n',
      env: env,
    );

    if (out.truncated) {
      Loggers.app.warning(
        'Monitor exec output was truncated by the agent at '
        '${out.stdout.length + out.stderr.length} bytes; what the caller '
        'parses is a prefix of: ${script.split('\n').first}',
      );
    }

    // A request carries no stream, so the callbacks fire once with everything.
    // Callers use them to watch for a line rather than to render progress —
    // `runWithSudo` looks for a rejected password — and that still works.
    final stderr = out.timedOut
        // Said in stderr because that is where the caller is already looking
        // for why a command produced nothing; the agent kills the process and
        // returns nothing else, so there is nothing here to pollute.
        ? libL10n.timeout
        : out.stderr;
    if (out.stdout.isNotEmpty) onStdout?.call(out.stdout);
    if (stderr.isNotEmpty) onStderr?.call(stderr);

    return ExecResult(
      exitCode: out.exitCode,
      stdout: out.stdout,
      stderr: stderr,
    );
  }
}
