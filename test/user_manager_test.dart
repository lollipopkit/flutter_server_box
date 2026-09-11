import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/data/service/user_manager.dart';

final class _QueueExec implements ServerExec {
  _QueueExec(List<ExecResult> results) : results = Queue.of(results);

  final Queue<ExecResult> results;
  final scripts = <String>[];

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
    return results.removeFirst();
  }
}

void main() {
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

  test('parses passwd and group catalogs', () {
    final catalog = UserManager.parse(listing);

    expect(catalog.currentUser, 'admin');
    expect(catalog.uidMin, 1000);
    expect(catalog.users, hasLength(4));
    expect(catalog.users.first.isRoot, isTrue);
    expect(catalog.users[1].loginDisabled, isTrue);

    final admin = catalog.users[2];
    expect(admin.comment, 'Admin User');
    expect(admin.primaryGroup, 'users');
    expect(admin.supplementaryGroups, ['docker']);
    expect(admin.isSystem(catalog.uidMin), isFalse);
  });

  test('list runs the portable catalog script', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: listing, stderr: ''),
    ]);

    final catalog = await UserManager.list(exec);

    expect(catalog.currentUser, 'admin');
    expect(exec.scripts, [UserManager.listScript]);
  });

  test('builds a quoted create script and sets the password through stdin', () {
    const draft = ServerUserDraft(
      name: 'deploy',
      comment: "Release operator's account",
      home: '/srv/deploy',
      shell: '/bin/bash',
      primaryGroup: 'users',
      supplementaryGroups: ['docker', 'wheel'],
      createHome: true,
      moveHome: false,
      system: false,
      password: 'correct horse battery staple',
    );

    final script = UserManager.createScript(draft);

    expect(
      script,
      contains("-c 'Release operator'\\''s account'"),
    );
    expect(script, startsWith('set -e\nuseradd '));
    expect(script, contains("-G 'docker,wheel' 'deploy'"));
    expect(script, contains("chpasswd <<'SrvBoxUserPassword'"));
    expect(script, contains('deploy:correct horse battery staple'));
  });

  test('edits only fields that changed', () {
    const original = ServerUser(
      name: 'deploy',
      uid: 1001,
      gid: 1000,
      comment: 'Deploy',
      home: '/home/deploy',
      shell: '/bin/sh',
      primaryGroup: 'users',
      supplementaryGroups: ['docker'],
    );
    const draft = ServerUserDraft(
      name: 'deploy',
      comment: 'Deploy',
      home: '/srv/deploy',
      shell: '/bin/bash',
      primaryGroup: 'users',
      supplementaryGroups: ['docker'],
      createHome: true,
      moveHome: true,
      system: false,
    );

    expect(
      UserManager.editScript(original, draft),
      "usermod -d '/srv/deploy' -m -s '/bin/bash' 'deploy'",
    );
  });

  test('rejects unsafe names and root deletion', () {
    const unsafe = ServerUserDraft(
      name: 'bad;touch /tmp/pwned',
      comment: '',
      home: '',
      shell: '',
      primaryGroup: '',
      supplementaryGroups: [],
      createHome: true,
      moveHome: false,
      system: false,
    );
    expect(() => UserManager.createScript(unsafe), throwsArgumentError);

    const root = ServerUser(
      name: 'root',
      uid: 0,
      gid: 0,
      comment: '',
      home: '/root',
      shell: '/bin/sh',
      primaryGroup: 'root',
      supplementaryGroups: [],
    );
    expect(
      () => UserManager.deleteScript(root, removeHome: false),
      throwsArgumentError,
    );
  });
}
