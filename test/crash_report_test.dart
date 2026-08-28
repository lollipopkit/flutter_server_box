import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/crash_report.dart';

/// This text is what a user pastes into an issue, and it is assembled once,
/// after a crash, on a device nobody can reach. Getting the truncation
/// backwards would produce a report that is the right length and the wrong
/// half, which nothing downstream would flag.
void main() {
  String composed({
    String? log,
    int build = 1538,
    String os = 'android 16',
    String locale = 'zh_CN',
    int maxLogChars = CrashReport.maxLogChars,
  }) => CrashReport.compose(
    log: log,
    build: build,
    os: os,
    locale: locale,
    maxLogChars: maxLogChars,
  );

  test('leads with the environment, which is what reporters leave out', () {
    final report = composed(log: 'something');

    expect(report, contains('- App: 1538'));
    expect(report, contains('- OS: android 16'));
    expect(report, contains('- Locale: zh_CN'));
    expect(
      report.indexOf('### Environment'),
      lessThan(report.indexOf('### Log')),
    );
  });

  test('says there was no log rather than showing an empty fence', () {
    // An empty log is itself information: it means the run died before
    // anything was written, which points at startup.
    for (final empty in [null, '', '   \n  ']) {
      final report = composed(log: empty);
      expect(report, contains('No log was kept'));
      expect(report, isNot(contains('```')));
    }
  });

  test('keeps the end of the log, which is the end nearest the crash', () {
    final log = [
      for (var i = 0; i < 400; i++) 'line $i ${'-' * 60}',
    ].join('\n');

    final report = composed(log: log, maxLogChars: 1024);

    expect(report, contains('line 399'));
    expect(report, isNot(contains('line 0 ')));
    expect(report, contains('Earlier lines omitted'));
  });

  test('a truncated log starts on a line boundary', () {
    // Cutting by character count lands mid-line, and half a stack frame at the
    // top of a report reads as corruption rather than as truncation.
    final log = [for (var i = 0; i < 200; i++) 'prefix-$i-suffix'].join('\n');

    final report = composed(log: log, maxLogChars: 200);
    final fenced = report.split('```')[1].trim();

    expect(fenced.split('\n').first, startsWith('prefix-'));
  });

  test('a log within the limit is not marked truncated', () {
    final report = composed(log: 'one line', maxLogChars: 1024);

    expect(report, contains('one line'));
    expect(report, isNot(contains('Earlier lines omitted')));
  });

  test('the log is fenced, so a stack trace keeps its line breaks', () {
    final report = composed(log: 'at foo\n  at bar\n  at baz');

    expect(report, contains('```\nat foo\n  at bar\n  at baz\n```'));
  });
}
