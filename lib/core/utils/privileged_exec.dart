import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/src/rust/api/exec_session.dart' show SudoEntry, sudoEntry;

abstract final class PrivilegedExec {
  static const _passwordlessProbe = 'true';

  // The shell the script is fed to, in each of the ways into root
  // (`sbm_parser::sudo`).
  static final _direct = sudoEntry(entry: SudoEntry.direct, body: 'sh');
  static final _withPassword = sudoEntry(entry: SudoEntry.sudoPassword, body: 'sh');
  static final _passwordless = sudoEntry(entry: SudoEntry.sudoNoPassword, body: 'sh');

  /// Runs [script] as root without ever offering the script itself to sudo as
  /// a possible password.
  ///
  /// A passwordless probe has to happen first. Passing [script] to `sudo sh`
  /// on the first attempt would put its first line on sudo's stdin; a machine
  /// that needs a password could consume that line before rejecting it. Once
  /// the probe succeeds, `sudo -n` is safe. When a password is supplied it is
  /// written before the script and sudo consumes exactly that first line.
  static Future<ExecResult> run(
    CommandExec exec,
    String script, {
    required bool isRoot,
    String? password,
  }) async {
    if (isRoot) return exec.run(script, entry: _direct);
    if (password != null) {
      return exec.runWithSudo(
        script,
        password: password,
        entry: _withPassword,
      );
    }

    final probe = await exec.runWithSudo(
      _passwordlessProbe,
      entry: _passwordless,
    );
    if (!probe.succeeded) return probe;
    return exec.run(script, entry: _passwordless);
  }
}
