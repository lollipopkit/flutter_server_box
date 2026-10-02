import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/data/service/user_manager.dart';
import 'package:server_box/src/rust/api/users.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

/// The app's half of the accounts page: running what `sbm_parser::users`
/// builds and carrying what it parses. The rules themselves — the catalog, the
/// detail, the commands and what is refused — are asserted in Rust, by
/// `crates/sbm_parser/tests/user_compat.rs`, which holds this file's former
/// cases.
final class _QueueExec implements ServerExec {
  _QueueExec(List<ExecResult> results) : results = Queue.of(results);

  final Queue<ExecResult> results;
  final scripts = <String>[];
  final entries = <String?>[];

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
    return results.removeFirst();
  }
}

void main() {
  setUpAll(initRustLibForTest);

  const listing = '''
SrvBoxUsers.Current\tadmin
SrvBoxUsers.UidMin\t1000
SrvBoxUsers.Passwd
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
admin:x:1000:1000:Admin User:/home/admin:/bin/bash
deploy:x:1001:1000:Deploy:/srv/deploy:/bin/sh
SrvBoxUsers.Group
root:x:0:
users:x:1000:admin
docker:x:998:admin,deploy
''';

  const admin = ServerUser(
    name: 'admin',
    uid: 1000,
    gid: 1000,
    comment: '',
    home: '/home/admin',
    shell: '/usr/bin/fish',
    primaryGroup: 'users',
    supplementaryGroups: ['docker'],
  );

  ServerUserDraft draft({
    String name = 'deploy',
    String comment = '',
    String? password,
  }) => ServerUserDraft(
    name: name,
    comment: comment,
    home: '/srv/deploy',
    shell: '/bin/bash',
    primaryGroup: 'users',
    supplementaryGroups: const ['docker'],
    createHome: true,
    moveHome: false,
    system: false,
    password: password,
  );

  test('list runs the Rust script through sh and reads its catalog', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: listing, stderr: ''),
    ]);

    final catalog = await UserManager.list(exec);

    expect(exec.scripts, [ffi.usersListScript()]);
    // Through `sh`, not the login shell: the script has an `if`, which fish
    // does not read.
    expect(exec.entries, ['sh']);
    expect(catalog.currentUser, 'admin');
    expect(catalog.uidMin, 1000);
    expect(catalog.users.map((user) => user.name), [
      'root',
      'daemon',
      'admin',
      'deploy',
    ]);
    final read = catalog.users[2];
    expect(read.comment, 'Admin User');
    expect(read.primaryGroup, 'users');
    expect(read.supplementaryGroups, ['docker']);
    expect(catalog.users.first.isRoot, isTrue);
    expect(catalog.users[1].loginDisabled, isTrue);
  });

  test('a listing that fails or names no current user is refused', () async {
    final failed = _QueueExec([
      const ExecResult(exitCode: 1, stdout: '', stderr: 'getent: denied'),
    ]);
    await expectLater(
      UserManager.list(failed),
      throwsA(
        isA<UserManagerException>().having(
          (e) => e.message,
          'message',
          'getent: denied',
        ),
      ),
    );

    await expectLater(
      UserManager.parse('SrvBoxUsers.Passwd\n'),
      throwsA(
        isA<UserManagerException>().having(
          (e) => e.message,
          'message',
          'Unable to determine the current user',
        ),
      ),
    );
  });

  test('an account crosses to Rust and back unchanged', () async {
    // What the detail script is built from is the JSON this side writes.
    expect(UserManager.detailScript(admin), contains("'/home/admin"));
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: '', stderr: ''),
    ]);
    await UserManager.detail(exec, admin);
    expect(exec.scripts, [UserManager.detailScript(admin)]);
    expect(exec.entries, ['sh']);
  });

  test('a detail reads its instants as UTC days and keeps null apart from empty', () async {
    final detail = await UserManager.parseDetail('''
SrvBoxUserDetail.Shadow
admin:\$6\$hash:20000:0:99999:7::20100:
SrvBoxUserDetail.Status
SrvBoxUserDetail.Keys
SrvBoxUserDetail.KeysRead
SrvBoxUserDetail.Sudo
''');
    expect(detail.passwordState, ServerUserPasswordState.set);
    expect(detail.passwordChanged, DateTime.utc(2024, 10, 4));
    expect(detail.expires, DateTime.utc(2025, 1, 12));
    expect(detail.neverExpires, isFalse);
    // The keys file was read and held nothing: an empty list, not "unknown".
    expect(detail.sshKeyTypes, isEmpty);

    final unreadable = await UserManager.parseDetail('');
    expect(unreadable.isEmpty, isTrue);
    expect(unreadable.sshKeyTypes, isNull);
  });

  test('a refusal reads as the message the form has always shown', () {
    expect(UserManager.validateDraft(draft()), isNull);
    expect(
      UserManager.validateDraft(draft(name: 'Bad Name')),
      'Invalid user name',
    );
    expect(
      UserManager.validateDraft(draft(password: 'a\nb')),
      'Password cannot contain line breaks',
    );
    expect(UserManager.validName('deploy'), isTrue);
    expect(UserManager.validName('-rf'), isFalse);
  });

  test('a command Rust refuses is an ArgumentError, as it was', () {
    expect(
      () => UserManager.createScript(draft(name: 'Bad Name')),
      throwsA(
        isA<ArgumentError>().having((e) => e.message, 'message', 'Invalid user name'),
      ),
    );
    expect(
      () => UserManager.editScript(admin, draft(name: 'renamed')),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'Renaming is not supported',
        ),
      ),
    );
    const root = ServerUser(
      name: 'root',
      uid: 0,
      gid: 0,
      comment: '',
      home: '/root',
      shell: '/bin/bash',
      supplementaryGroups: [],
    );
    expect(
      () => UserManager.deleteScript(root, removeHome: false),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'The root user cannot be deleted',
        ),
      ),
    );
  });

  test('a draft reaches Rust whole', () {
    // Every field the form fills in has to arrive: one dropped by the JSON
    // would be a command that silently ignores what the user typed.
    final script = UserManager.createScript(
      draft(comment: "Release operator's account", password: 'secret'),
    );
    expect(script, contains('useradd'));
    expect(script, contains('-m'));
    expect(script, contains(r"'Release operator'\''s account'"));
    expect(script, contains("-d '/srv/deploy'"));
    expect(script, contains("-s '/bin/bash'"));
    expect(script, contains("-g 'users'"));
    expect(script, contains("-G 'docker'"));
    expect(script, contains("chpasswd <<'SrvBoxUserPassword'\ndeploy:secret\n"));
  });
}
