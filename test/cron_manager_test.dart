import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/cron.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/service/cron_manager.dart';

final class _QueueExec implements ServerExec {
  _QueueExec(List<ExecResult> results) : results = Queue.of(results);

  final Queue<ExecResult> results;
  final scripts = <String>[];
  final stdins = <String?>[];

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async {
    scripts.add(script);
    stdins.add(stdin);
    return results.removeFirst();
  }
}

void main() {
  const source = '''# Keep this comment
MAILTO=ops@example.com
0 2 * * * /usr/local/bin/backup --quiet
@reboot /usr/local/bin/register
# ServerBox disabled: */5 * * * * /usr/local/bin/health-check
# 0 0 * * * this ordinary comment is not managed
''';

  test('parses jobs while preserving comments and environment lines', () {
    final document = CronDocument.parse(source);

    expect(document.jobs, hasLength(3));
    expect(document.jobs[0].schedule, '0 2 * * *');
    expect(document.jobs[0].command, '/usr/local/bin/backup --quiet');
    expect(document.jobs[1].schedule, '@reboot');
    expect(document.jobs[2].enabled, isFalse);
    expect(document.lines[0], '# Keep this comment');
    expect(document.lines[1], 'MAILTO=ops@example.com');
  });

  test('edits, disables, adds, and removes jobs without losing other lines', () {
    final original = CronDocument.parse(source);
    final edited = original.upsert(
      original: original.jobs.first,
      schedule: '30 3 * * *',
      command: '/usr/local/bin/backup',
      enabled: true,
    );
    final disabled = edited.setEnabled(edited.jobs[1], false);
    final added = disabled.upsert(
      schedule: '@daily',
      command: '/usr/local/bin/report',
      enabled: true,
    );
    final removed = added.remove(added.jobs[2]);

    expect(removed.lines[0], '# Keep this comment');
    expect(removed.lines[1], 'MAILTO=ops@example.com');
    expect(removed.render(), contains('30 3 * * * /usr/local/bin/backup\n'));
    expect(
      removed.render(),
      contains('# ServerBox disabled: @reboot /usr/local/bin/register\n'),
    );
    expect(removed.render(), contains('@daily /usr/local/bin/report\n'));
  });

  test('validates schedules and rejects line injection', () {
    expect(
      CronDocument.validate(schedule: '* * * *', command: 'echo short'),
      isNotNull,
    );
    expect(
      CronDocument.validate(schedule: '@reboot', command: 'echo okay'),
      isNull,
    );
    expect(
      CronDocument.validate(
        schedule: '* * * * *',
        command: 'echo okay\nrm -rf /',
      ),
      isNotNull,
    );
  });

  test('lists an empty crontab and saves the complete document on stdin', () async {
    final exec = _QueueExec([
      const ExecResult(
        exitCode: 0,
        stdout: 'SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n',
        stderr: '',
      ),
      const ExecResult(exitCode: 0, stdout: '', stderr: ''),
    ]);

    final catalog = await CronManager.list(exec);
    expect(catalog.user, 'admin');
    expect(catalog.document.jobs, isEmpty);

    final document = catalog.document.upsert(
      schedule: '0 * * * *',
      command: '/usr/local/bin/hourly',
      enabled: true,
    );
    await CronManager.save(exec, document);

    expect(exec.scripts, [CronManager.listScript, 'crontab -']);
    expect(exec.stdins.last, '0 * * * * /usr/local/bin/hourly\n');
  });

  test('reports a missing crontab implementation', () async {
    final exec = _QueueExec([
      const ExecResult(
        exitCode: 127,
        stdout: '',
        stderr: 'crontab is not installed',
      ),
    ]);

    await expectLater(
      CronManager.list(exec),
      throwsA(
        isA<CronManagerException>().having(
          (error) => error.unavailable,
          'unavailable',
          isTrue,
        ),
      ),
    );
  });
}
