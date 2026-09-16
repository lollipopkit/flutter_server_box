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

  group('parseDetail', () {
    String out({
      String shadow = '',
      String status = '',
      String keys = '',
      String sudo = '',
    }) => [
      UserManager.detailShadowMarker,
      shadow,
      UserManager.detailStatusMarker,
      status,
      UserManager.detailKeysMarker,
      keys,
      UserManager.detailSudoMarker,
      sudo,
    ].join('\n');

    test('reads shadow rather than the locale-formatted commands', () {
      final detail = UserManager.parseDetail(
        out(shadow: r'lk:$y$j9T$abc:20355:0:99999:7:::'),
      );
      expect(detail.passwordState, ServerUserPasswordState.set);
      expect(
        detail.passwordChanged,
        DateTime.utc(2025, 9, 24),
      );
      expect(detail.neverExpires, true);
      expect(detail.expires, isNull);
    });

    // `!`, `!!` and `*` all mean "no password login". An empty field means no
    // password at all, which lets anyone in and must not read as locked.
    test('tells a locked password from an absent one', () {
      for (final hash in ['!', '!!', '*', r'!$y$abc']) {
        expect(
          UserManager.parseDetail(out(shadow: 'svc:$hash:20000:0:99999:7:::'))
              .passwordState,
          ServerUserPasswordState.locked,
          reason: hash,
        );
      }
      expect(
        UserManager.parseDetail(out(shadow: 'svc::20000:0:99999:7:::'))
            .passwordState,
        ServerUserPasswordState.none,
      );
    });

    test('an expiry date is a date, an empty field is never', () {
      final expiring = UserManager.parseDetail(
        out(shadow: 'temp:x:20000:0:99999:7::20500:'),
      );
      expect(expiring.expires, DateTime.utc(2026, 2, 16));
      expect(expiring.neverExpires, false);
    });

    test('falls back to passwd -S when shadow is unreadable', () {
      final detail = UserManager.parseDetail(
        out(status: 'lk L 09/28/2026 0 99999 7 -1'),
      );
      expect(detail.passwordState, ServerUserPasswordState.locked);
      expect(detail.passwordChanged, isNull);
    });

    test('collects distinct key types and skips comments and options', () {
      final detail = UserManager.parseDetail(
        out(
          keys: [
            '# work laptop',
            '',
            'ssh-ed25519 AAAAC3Nz lk@laptop',
            'no-pty,command="x" ssh-rsa AAAAB3Nz lk@box',
            'ssh-ed25519 AAAAC3Nz lk@phone',
            'ecdsa-sha2-nistp256 AAAAE2 lk@yubi',
          ].join('\n'),
        ),
      );
      expect(detail.sshKeyTypes, ['ed25519', 'rsa', 'ecdsa']);
    });

    // An empty list is "read it, there are none"; null is "could not read it".
    // Reporting the second as the first would tell the user an account with
    // keys has none.
    test('no keys file is null, an empty one is an empty list', () {
      expect(UserManager.parseDetail(out(keys: '')).sshKeyTypes, isEmpty);
      expect(
        UserManager.parseDetail(UserManager.detailShadowMarker).sshKeyTypes,
        isNull,
      );
    });

    test('takes the first sudoers rule and drops the host part', () {
      final detail = UserManager.parseDetail(
        out(
          sudo: [
            'Matching Defaults entries for lk on box:',
            '    env_reset, mail_badpass',
            '',
            'User lk may run the following commands on box:',
            '    (ALL : ALL) NOPASSWD: ALL',
          ].join('\n'),
        ),
      );
      expect(detail.sudoRule, 'NOPASSWD: ALL');
    });

    test('nothing readable is an empty detail, not a wrong one', () {
      final detail = UserManager.parseDetail(UserManager.detailShadowMarker);
      expect(detail.isEmpty, true);
      expect(detail.passwordState, isNull);
      expect(detail.sudoRule, isNull);
    });
  });
}
