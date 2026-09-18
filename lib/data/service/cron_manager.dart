import 'package:server_box/data/model/server/cron.dart';
import 'package:server_box/data/model/server/cron_schedule.dart';
import 'package:server_box/data/model/server/server_exec.dart';

final class CronManagerException implements Exception {
  const CronManagerException(this.message, {this.unavailable = false});

  final String message;
  final bool unavailable;

  @override
  String toString() => message;
}

abstract final class CronManager {
  static const userMarker = 'SrvBoxCron.User\t';
  static const clockMarker = 'SrvBoxCron.Clock\t';
  static const bodyMarker = 'SrvBoxCron.Body';

  /// The clock line is `date +'%s %z'` and is allowed to fail: a `date`
  /// without `%z` prints it back literally, which [parse] reads as nothing
  /// said. Cron matches an expression against the server's wall clock, so the
  /// offset is what lets the page name a next run the server agrees with.
  static const listScript = r'''
LC_ALL=C
export LC_ALL
command -v crontab >/dev/null 2>&1 || {
  printf 'crontab is not installed\n' >&2
  exit 127
}
printf 'SrvBoxCron.User\t'
id -un || exit $?
printf 'SrvBoxCron.Clock\t%s\n' "$(date +'%s %z' 2>/dev/null)"
printf 'SrvBoxCron.Body\n'
crontab -l
''';

  /// Handed to `sh` rather than run as the command: without an entry the
  /// script is parsed by the account's login shell, and fish rejects
  /// `LC_ALL=C` and `|| { ... }` outright — which the page reported as
  /// "crontab is not available" with fish's own diagnostic under it.
  static Future<CronCatalog> list(ServerExec exec) async {
    final result = await exec.run(listScript, entry: 'sh');
    final error = result.stderr.trim();
    final hasNoCrontab = result.exitCode == 1 && isNoCrontab(error);
    if (!result.succeeded && !hasNoCrontab) {
      final detail = error.isEmpty ? result.stdout.trim() : error;
      throw CronManagerException(
        detail.isEmpty ? 'Unable to list scheduled tasks' : detail,
        unavailable: result.exitCode == 127,
      );
    }
    return parse(result.stdout);
  }

  /// Whether `crontab -l` exiting 1 meant "this account has no crontab yet".
  ///
  /// That is the state of every server before its first job, and it has to be
  /// an empty document the user can add to, not an error. Each implementation
  /// says it differently and all of them exit 1, the same as a real failure:
  /// vixie and cronie print `no crontab for NAME`, BSD's prefixes it with
  /// `crontab: `, and busybox's `-l` is a `cat` of the spool file, so Alpine
  /// and OpenWrt say `crontab: can't open 'NAME': No such file or directory`.
  /// dcron prints the first form but exits 0, so it never gets
  /// here. Anything else — the spool directory missing, a permission refusal
  /// — is reported as what it said.
  static bool isNoCrontab(String stderr) {
    final line = stderr.trim().toLowerCase();
    if (line.contains('no crontab for ')) return true;
    return line.startsWith("crontab: can't open '") &&
        line.endsWith('no such file or directory');
  }

  static CronCatalog parse(String output) {
    final normalized = output.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final bodyStart = normalized.indexOf('$bodyMarker\n');
    if (bodyStart < 0) {
      throw const CronManagerException('Invalid crontab response');
    }
    final header = normalized.substring(0, bodyStart);
    final userLine = header.split('\n').firstWhere(
      (line) => line.startsWith(userMarker),
      orElse: () => '',
    );
    if (userLine.isEmpty) {
      throw const CronManagerException('Unable to determine the current user');
    }
    final user = userLine.substring(userMarker.length).trim();
    if (user.isEmpty) {
      throw const CronManagerException('Unable to determine the current user');
    }
    final clockLine = header
        .split('\n')
        .firstWhere((line) => line.startsWith(clockMarker), orElse: () => '');
    final clock = clockLine.isEmpty
        ? null
        : CronClock.tryParse(clockLine.substring(clockMarker.length));
    final body = normalized.substring(bodyStart + bodyMarker.length + 1);
    return CronCatalog(
      user: user,
      document: CronDocument.parse(body),
      clock: clock,
    );
  }

  static Future<void> save(ServerExec exec, CronDocument document) async {
    final result = await exec.run('crontab -', stdin: document.render());
    if (result.succeeded) return;
    final detail = result.combined.trim();
    throw CronManagerException(
      detail.isEmpty ? 'Unable to save scheduled tasks' : detail,
      unavailable: result.exitCode == 127,
    );
  }
}
