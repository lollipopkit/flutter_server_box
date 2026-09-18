import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/cron.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/service/cron_manager.dart';

final class _QueueExec implements ServerExec {
  _QueueExec(List<ExecResult> results) : results = Queue.of(results);

  final Queue<ExecResult> results;
  final scripts = <String>[];
  final entries = <String?>[];
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
    entries.add(entry);
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

  test('keeps every line it does not manage as a preserved one', () {
    final document = CronDocument.parse(source);

    expect(document.preserved, [
      '# Keep this comment',
      'MAILTO=ops@example.com',
      '# 0 0 * * * this ordinary comment is not managed',
    ]);
    // A disabled task is a task, not a comment: it is in the list with its
    // switch off, and showing it twice would offer two ways to change it.
    expect(
      document.preserved,
      isNot(contains(contains('/usr/local/bin/health-check'))),
    );
  });

  test('reads the clock the listing reported', () async {
    final exec = _QueueExec([
      const ExecResult(
        exitCode: 0,
        stdout:
            'SrvBoxCron.User\tadmin\n'
            'SrvBoxCron.Clock\t1772000000 -0500\n'
            'SrvBoxCron.Body\n',
        stderr: '',
      ),
    ]);

    final catalog = await CronManager.list(exec);

    expect(catalog.clock?.offset, const Duration(hours: -5));
  });

  // The clock is what makes a next run the server's rather than the phone's,
  // and it is the one part of the listing that is allowed to fail: a `date`
  // without `%z` prints it back literally, and a build older than the marker
  // does not print the line at all. Either way the page falls back to this
  // device's timezone instead of showing a time from a failed parse.
  test('treats a clock it cannot read as one the server did not say', () async {
    final exec = _QueueExec([
      const ExecResult(
        exitCode: 0,
        stdout:
            'SrvBoxCron.User\tadmin\n'
            'SrvBoxCron.Clock\t1772000000 %z\n'
            'SrvBoxCron.Body\n',
        stderr: '',
      ),
      const ExecResult(
        exitCode: 0,
        stdout: 'SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n',
        stderr: '',
      ),
    ]);

    expect((await CronManager.list(exec)).clock, isNull);
    expect((await CronManager.list(exec)).clock, isNull);
  });

  test('validates schedules and rejects line injection', () {
    expect(
      CronDocument.validate(schedule: '* * * *', command: 'echo short'),
      CronValidation.fieldCount,
    );
    expect(
      CronDocument.validate(schedule: '@reboot', command: 'echo okay'),
      isNull,
    );
    // A line break would split one task into two lines of the file, the
    // second of which crond reads as a schedule of its own.
    expect(
      CronDocument.validate(
        schedule: '* * * * *',
        command: 'echo okay\nrm -rf /',
      ),
      CronValidation.lineBreak,
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
    // The listing is a POSIX script and must reach `sh`: run as the command
    // it is parsed by the login shell, and fish refused `LC_ALL=C`. The save
    // is one command whose stdin is the document, so it has no entry.
    expect(exec.entries, ['sh', null]);
    expect(exec.stdins.last, '0 * * * * /usr/local/bin/hourly\n');
  });

  test('treats the expected no-crontab stderr as an empty document', () async {
    final exec = _QueueExec([
      const ExecResult(
        exitCode: 1,
        stdout: 'SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n',
        stderr: 'no crontab for admin\n',
      ),
    ]);

    final catalog = await CronManager.list(exec);

    expect(catalog.user, 'admin');
    expect(catalog.document.lines, isEmpty);
  });

  // Every crontab exits 1 for an account with no crontab, the same as for a
  // real failure, and each says it differently. Reading any of them as an
  // error leaves the page unable to add the first job.
  test('reads each implementation\'s "no crontab" message as empty', () {
    // vixie, cronie
    expect(CronManager.isNoCrontab('no crontab for admin'), isTrue);
    // BSD, macOS
    expect(CronManager.isNoCrontab('crontab: no crontab for admin'), isTrue);
    // busybox: `-l` is a cat of the spool file
    expect(
      CronManager.isNoCrontab(
        "crontab: can't open 'admin': No such file or directory",
      ),
      isTrue,
    );

    // A spool directory that is not there, or one this account may not read,
    // is a failure to show.
    expect(
      CronManager.isNoCrontab(
        "crontab: can't change directory to '/etc/crontabs': "
        'No such file or directory',
      ),
      isFalse,
    );
    expect(
      CronManager.isNoCrontab("crontab: can't open 'admin': Permission denied"),
      isFalse,
    );
    expect(CronManager.isNoCrontab(''), isFalse);
  });

  test('treats busybox\'s missing spool file as an empty document', () async {
    final exec = _QueueExec([
      const ExecResult(
        exitCode: 1,
        stdout: 'SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n',
        stderr: "crontab: can't open 'admin': No such file or directory\n",
      ),
    ]);

    final catalog = await CronManager.list(exec);

    expect(catalog.user, 'admin');
    expect(catalog.document.lines, isEmpty);
  });

  test('does not include successful crontab warnings in the document', () async {
    final exec = _QueueExec([
      const ExecResult(
        exitCode: 0,
        stdout: 'SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n0 * * * * echo ok\n',
        stderr: 'warning: legacy syntax\n',
      ),
    ]);

    final catalog = await CronManager.list(exec);

    expect(catalog.document.jobs, hasLength(1));
    expect(catalog.document.render(), '0 * * * * echo ok\n');
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
