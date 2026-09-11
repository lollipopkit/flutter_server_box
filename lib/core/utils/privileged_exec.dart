import 'package:server_box/data/model/server/server_exec.dart';

abstract final class PrivilegedExec {
  static const _passwordlessProbe = 'sudo -n true';
  static const _passwordlessEntry = 'sudo -n sh';
  static const _passwordEntry = "sudo -S -p '' sh";

  /// Runs [script] as root without ever offering the script itself to sudo as
  /// a possible password.
  ///
  /// A passwordless probe has to happen first. Passing [script] to `sudo sh`
  /// on the first attempt would put its first line on sudo's stdin; a machine
  /// that needs a password could consume that line before rejecting it. Once
  /// the probe succeeds, `sudo -n` is safe. When a password is supplied it is
  /// written before the script and sudo consumes exactly that first line.
  static Future<ExecResult> run(
    ServerExec exec,
    String script, {
    required bool isRoot,
    String? password,
  }) async {
    if (isRoot) return exec.run(script, entry: 'sh');
    if (password != null) {
      return exec.runWithSudo(
        script,
        password: password,
        entry: _passwordEntry,
      );
    }

    final probe = await exec.runWithSudo(_passwordlessProbe);
    if (!probe.succeeded) return probe;
    return exec.run(script, entry: _passwordlessEntry);
  }
}
