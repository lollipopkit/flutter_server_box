/// What a `monitor` agent's `POST /api/v1/exec` reports about one command.
///
/// Kept as its own type rather than mapped straight onto `ExecResult` because
/// two of these fields have no equivalent over SSH: the agent caps both output
/// and running time, and a caller parsing the result deserves to know when it
/// is looking at a prefix rather than an answer.
class MonitorExecOutput {
  /// Null when the process was killed rather than exiting — the timeout, or a
  /// signal.
  final int? exitCode;
  final String stdout;
  final String stderr;

  /// Either stream hit the agent's size cap, so what is here is a prefix.
  final bool truncated;

  /// The agent's time limit elapsed and it killed the command.
  final bool timedOut;

  const MonitorExecOutput({
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.truncated = false,
    this.timedOut = false,
  });

  factory MonitorExecOutput.fromJson(Map<String, dynamic> json) {
    return MonitorExecOutput(
      exitCode: (json['exit_code'] as num?)?.toInt(),
      stdout: json['stdout'] as String? ?? '',
      stderr: json['stderr'] as String? ?? '',
      truncated: json['truncated'] == true,
      timedOut: json['timed_out'] == true,
    );
  }

  @override
  String toString() =>
      'MonitorExecOutput(exitCode: $exitCode, stdout: ${stdout.length}B, '
      'stderr: ${stderr.length}B, truncated: $truncated, '
      'timedOut: $timedOut)';
}
