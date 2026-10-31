import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/cron.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/service/cron_manager.dart';
import 'package:server_box/src/rust/api/cron.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

final class _QueueExec implements CommandExec {
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

/// A document as a listing hands it out.
CronDocument _parse(String raw) => CronDocument.fromFfi(
  ffi
      .cronReadListing(
        stdout: 'SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n$raw',
        stderr: '',
        exitCode: 0,
        succeeded: true,
      )
      .document,
);

void main() {
  setUpAll(initRustLibForTest);

  const source = '''# Keep this comment
MAILTO=ops@example.com
0 2 * * * /usr/local/bin/backup --quiet
@reboot /usr/local/bin/register
# ServerBox disabled: */5 * * * * /usr/local/bin/health-check
# 0 0 * * * this ordinary comment is not managed
''';

  test('edits, disables, adds, and removes jobs without losing other lines', () {
    final original = _parse(source);
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

    expect(exec.scripts, [ffi.cronListScript(), 'crontab -']);
    // The listing is a POSIX script and must reach `sh`: run as the command
    // it is parsed by the login shell, and fish refused `LC_ALL=C`. The save
    // is one command whose stdin is the document, so it has no entry.
    expect(exec.entries, ['sh', null]);
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

  test('reports a refused save in the machine\'s words', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 1, stdout: '', stderr: 'crontab: bad minute\n'),
      const ExecResult(exitCode: 1, stdout: '', stderr: ''),
    ]);
    final document = _parse('0 * * * * echo ok\n');

    await expectLater(
      CronManager.save(exec, document),
      throwsA(
        isA<CronManagerException>()
            .having((e) => e.message, 'message', 'crontab: bad minute')
            .having((e) => e.unavailable, 'unavailable', isFalse),
      ),
    );
    await expectLater(
      CronManager.save(exec, document),
      throwsA(
        isA<CronManagerException>().having(
          (e) => e.message,
          'message',
          'Unable to save scheduled tasks',
        ),
      ),
    );
  });

  test('refuses an edit naming a line that is no longer a job', () {
    final document = _parse(source);
    final stale = CronJob(
      lineIndex: 0,
      schedule: '0 0 * * *',
      command: 'x',
      enabled: true,
    );

    expect(() => document.remove(stale), throwsArgumentError);
    expect(
      CronDocument.validate(schedule: '@', command: 'x'),
      CronValidation.macro,
    );
  });
}
