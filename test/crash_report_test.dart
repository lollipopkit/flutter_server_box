import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/crash_report.dart';

import 'helpers/spi_fixture.dart';

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
    Map<String, String> identifiers = const {},
    int maxLogChars = CrashReport.maxLogChars,
  }) => CrashReport.compose(
    log: log,
    build: build,
    os: os,
    locale: locale,
    identifiers: identifiers,
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

  /// The log has two readers wanting opposite things: in the Logs page the
  /// user needs to see which machine, and in an issue nobody may. Substitution
  /// is what separates them, and it is precise rather than pattern-based
  /// because the app holds the actual records.
  group('identifiers', () {
    test('a server name, host and user are all replaced', () {
      final ids = CrashReport.knownIdentifiers([
        spiFixture(name: 'prod-db', id: 'a', ip: '10.1.2.3', user: 'deploy'),
      ]);

      final report = composed(
        log: 'Connect to prod-db failed\n'
            'ProxyCommand for deploy@10.1.2.3:22',
        identifiers: ids,
      );

      expect(report, isNot(contains('prod-db')));
      expect(report, isNot(contains('10.1.2.3')));
      expect(report, isNot(contains('deploy')));
      expect(report, contains('<server-1>'));
      expect(report, contains('<host-1>'));
      expect(report, contains('<user-1>'));
    });

    test('the same server reads as the same token throughout', () {
      // A reader following one machine through a log needs to see the token
      // twice. It does not need to mean anything beyond that.
      final ids = CrashReport.knownIdentifiers([
        spiFixture(name: 'alpha', id: 'a', ip: '10.0.0.1'),
        spiFixture(name: 'beta', id: 'b', ip: '10.0.0.2'),
      ]);

      final report = composed(
        log: 'alpha connect\nbeta connect\nalpha timeout',
        identifiers: ids,
      );

      expect('<server-1>'.allMatches(report).length, 2);
      expect('<server-2>'.allMatches(report).length, 1);
    });

    test('an overlapping name is replaced longest first', () {
      // `db` inside `db-prod`: replacing the short one first would leave
      // `<server-1>-prod`, which still discloses `-prod` and has lost the fact
      // that the two lines named different machines.
      final ids = CrashReport.knownIdentifiers([
        spiFixture(name: 'db', id: 'a'),
        spiFixture(name: 'db-prod', id: 'b'),
      ]);

      final report = composed(log: 'db-prod failed', identifiers: ids);

      expect(report, contains('<server-2>'));
      expect(report, isNot(contains('prod')));
    });

    test('a name too short to substitute safely is left alone', () {
      // Two characters occur inside ordinary words, so replacing them would
      // corrupt the log rather than redact it — and such a name discloses
      // little in any case.
      final ids = CrashReport.knownIdentifiers([spiFixture(name: 'a', id: 'x')]);

      expect(ids.values, isNot(contains('<server-1>')));
      expect(
        composed(log: 'a failure happened', identifiers: ids),
        contains('a failure happened'),
      );
    });

    test('substitution happens before truncation, not after', () {
      // Otherwise the tail kept is measured against unredacted text, and which
      // lines survive depends on the length of names being removed.
      final ids = CrashReport.knownIdentifiers([
        spiFixture(name: 'secret-host', id: 'a'),
      ]);
      final log = [for (var i = 0; i < 200; i++) 'secret-host line $i'].join('\n');

      final report = composed(log: log, identifiers: ids, maxLogChars: 400);

      expect(report, isNot(contains('secret-host')));
      expect(report, contains('<server-1>'));
    });
  });
}
