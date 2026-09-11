import 'package:server_box/data/model/server/cron.dart';
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
  static const bodyMarker = 'SrvBoxCron.Body';

  static const listScript = r'''
LC_ALL=C
export LC_ALL
command -v crontab >/dev/null 2>&1 || {
  printf 'crontab is not installed\n' >&2
  exit 127
}
printf 'SrvBoxCron.User\t'
id -un || exit $?
printf 'SrvBoxCron.Body\n'
cron_output=$(crontab -l 2>&1)
cron_status=$?
if [ "$cron_status" -eq 0 ]; then
  if [ -n "$cron_output" ]; then printf '%s\n' "$cron_output"; fi
elif [ "$cron_status" -eq 1 ] && printf '%s' "$cron_output" | grep -qi '^no crontab for '; then
  :
else
  printf '%s\n' "$cron_output" >&2
  exit "$cron_status"
fi
''';

  static Future<CronCatalog> list(ServerExec exec) async {
    final result = await exec.run(listScript);
    if (!result.succeeded) {
      final detail = result.combined.trim();
      throw CronManagerException(
        detail.isEmpty ? 'Unable to list scheduled tasks' : detail,
        unavailable: result.exitCode == 127,
      );
    }
    return parse(result.stdout);
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
    final body = normalized.substring(bodyStart + bodyMarker.length + 1);
    return CronCatalog(user: user, document: CronDocument.parse(body));
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
