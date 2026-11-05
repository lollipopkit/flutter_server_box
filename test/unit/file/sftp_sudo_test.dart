import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/file/backend/sftp_sudo.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/sudo_error.dart';

import '../../helpers/rust_lib_helper.dart';
import '../../helpers/spi_fixture.dart';

/// Sudo as the server would run it: [good] is the password it accepts, and a
/// script carrying it prints [stdout] and exits with [exitCode].
final class _Server {
  _Server({this.stdout = '', this.exitCode = 0});

  static const good = 'good';
  final String stdout;
  final int exitCode;
  final scripts = <String>[];

  Future<SudoExecResult> exec(String script) async {
    scripts.add(script);
    final accepted = script.contains(good);
    return SudoExecResult(
      ExecResult(
        exitCode: accepted ? exitCode : 1,
        stdout: accepted ? stdout : '',
        stderr: accepted ? '' : 'Sorry, try again.',
      ),
      rejected: !accepted,
    );
  }
}

void main() {
  setUpAll(initRustLibForTest);

  late _Server server;
  late List<String?> answers;
  late int asked;
  var remember = false;

  SftpSudoHelper helper() => SftpSudoHelper(
    spi: spiFixture(name: 'box', id: 'box', ip: '10.0.0.1', user: 'alice'),
    exec: server.exec,
    askPassword: () async {
      asked++;
      return answers.isEmpty ? null : answers.removeAt(0);
    },
    rememberPwd: () => remember,
  );

  setUp(() {
    server = _Server(stdout: 'ok\n');
    answers = [];
    asked = 0;
    remember = false;
  });

  test('a password accepted the first time runs the command once', () async {
    answers = ['good'];

    expect(await helper().runAsRoot('true'), 'ok\n');
    expect(asked, 1);
    expect(server.scripts, hasLength(1));
  });

  test('a refused password is asked for again, not reused', () async {
    remember = true;
    answers = ['bad', 'good'];
    final h = helper();

    expect(await h.runAsRoot('true'), 'ok\n');
    expect(asked, 2);
    expect(server.scripts, hasLength(2));
    // The accepted one is what is remembered.
    await h.runAsRoot('true');
    expect(asked, 2);
    expect(server.scripts.last, contains('good'));
  });

  test('refused twice is SudoRejected, and nothing is remembered', () async {
    remember = true;
    answers = ['bad', 'worse', 'good'];
    final h = helper();

    await expectLater(h.runAsRoot('true'), throwsA(isA<SudoRejected>()));
    expect(asked, 2);
    await h.runAsRoot('true');
    expect(asked, 3);
  });

  test('a cancelled prompt is SudoCancelled and runs nothing', () async {
    await expectLater(helper().runAsRoot('true'), throwsA(isA<SudoCancelled>()));
    expect(server.scripts, isEmpty);
  });

  test('a command that fails as root is SftpSudoFailed with its output', () async {
    server = _Server(stdout: 'mv: cannot move\n', exitCode: 1);
    answers = ['good'];

    await expectLater(
      helper().runAsRoot('mv a b'),
      throwsA(
        isA<SftpSudoFailed>().having((e) => e.output, 'output', 'mv: cannot move'),
      ),
    );
  });

  test('a size it cannot read is a failure, never 0', () async {
    server = _Server(stdout: 'stat: weird\n');
    answers = ['good'];

    await expectLater(
      helper().getFileSize('/etc/shadow'),
      throwsA(isA<SftpSudoFailed>()),
    );
  });

  test('a size it can read is the size', () async {
    server = _Server(stdout: '1234\n');
    answers = ['good'];

    expect(await helper().getFileSize('/etc/shadow'), 1234);
  });

  test('the password is kept only when remembering is on', () async {
    answers = ['good', 'good'];
    final h = helper();

    await h.runAsRoot('true');
    await h.runAsRoot('true');
    expect(asked, 2);

    remember = true;
    answers = ['good'];
    asked = 0;
    final kept = helper();
    await kept.runAsRoot('true');
    await kept.runAsRoot('true');
    expect(asked, 1);
    kept.clearCache();
    h.clearCache();
  });

  group('finishUploadAsRoot', () {
    test('moves the staged file into place', () async {
      final moved = await helper().finishUploadAsRoot(
        '/tmp/staged',
        '/etc/x',
        staged: Future.value(true),
        password: 'good',
      );

      expect(moved, isTrue);
      expect(server.scripts.single, contains('/etc/x'));
    });

    test('a cancelled transfer moves nothing and removes the staging copy', () async {
      final moved = await helper().finishUploadAsRoot(
        '/tmp/staged',
        '/etc/x',
        staged: Future.value(false),
        password: 'good',
      );

      expect(moved, isFalse);
      expect(server.scripts.single, isNot(contains('/etc/x')));
      expect(server.scripts.single, contains('/tmp/staged'));
    });

    test('a failed transfer is rethrown after removing the staging copy', () async {
      await expectLater(
        helper().finishUploadAsRoot(
          '/tmp/staged',
          '/etc/x',
          staged: Future.error(StateError('dropped')),
          password: 'good',
        ),
        throwsA(isA<StateError>()),
      );
      expect(server.scripts.single, isNot(contains('/etc/x')));
    });
  });
}
