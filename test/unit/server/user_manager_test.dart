import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/data/service/user_manager.dart';

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
    // Through `sh`, not the login shell: the script has an `if`, which fish
    // does not read.
    expect(exec.entries, ['sh']);
  });

  test('detail reads the account through sh as well', () async {
    const user = ServerUser(
      name: 'admin',
      uid: 1000,
      gid: 1000,
      comment: '',
      home: '/home/admin',
      shell: '/usr/bin/fish',
      supplementaryGroups: [],
    );
    final exec = _QueueExec([
      const ExecResult(
        exitCode: 0,
        stdout: 'SrvBoxUserDetail.Shadow\n',
        stderr: '',
      ),
    ]);

    await UserManager.detail(exec, user);

    expect(exec.scripts, [UserManager.detailScript(user)]);
    expect(exec.entries, ['sh']);
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
    /// [keysRead] false leaves the read-marker out, which is what the script
    /// does when `authorized_keys` could not be opened.
    String out({
      String shadow = '',
      String status = '',
      String keys = '',
      String sudo = '',
      bool keysRead = true,
    }) => [
      UserManager.detailShadowMarker,
      shadow,
      UserManager.detailStatusMarker,
      status,
      UserManager.detailKeysMarker,
      if (keysRead) UserManager.detailKeysReadMarker,
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

    // Empty is the only thing that means never. Anything that will not parse
    // means the record could not be read, and answering Never there would be
    // a claim about an account's expiry made from no evidence.
    test('an unreadable expiry field is not never', () {
      for (final field in ['0', '-1', 'garbage']) {
        final detail = UserManager.parseDetail(
          out(shadow: 'temp:x:20000:0:99999:7::$field:'),
        );
        expect(detail.neverExpires, false, reason: field);
        expect(detail.expires, isNull, reason: field);
      }
    });

    test('falls back to passwd -S when shadow is unreadable', () {
      final detail = UserManager.parseDetail(
        out(status: 'lk L 09/28/2026 0 99999 7 -1'),
      );
      expect(detail.passwordState, ServerUserPasswordState.locked);
      expect(detail.passwordChanged, isNull);
    });

    // The script's awk pass has already reduced each line to its type token,
    // which is what keeps the file's free-form contents off this stream.
    test('collects distinct key types in file order', () {
      final detail = UserManager.parseDetail(
        out(
          keys: [
            'ssh-ed25519',
            'ssh-rsa',
            'ssh-ed25519',
            'ecdsa-sha2-nistp256',
            '',
          ].join('\n'),
        ),
      );
      expect(detail.sshKeyTypes, ['ed25519', 'rsa', 'ecdsa']);
    });

    // An empty list is "read it, there are none"; null is "could not read it".
    // Reporting the second as the first would tell the user that an account
    // with keys has none.
    test('an unread keys file is null, an empty one is an empty list', () {
      expect(UserManager.parseDetail(out(keys: '')).sshKeyTypes, isEmpty);
      expect(
        UserManager.parseDetail(out(keysRead: false)).sshKeyTypes,
        isNull,
      );
      expect(
        UserManager.parseDetail(UserManager.detailShadowMarker).sshKeyTypes,
        isNull,
      );
    });

    // The file belongs to the account being looked at, and the markers travel
    // as plain text on the same stream. Reducing each line to a token that
    // cannot spell one is what stops its owner fabricating the sudo rule this
    // page displays.
    test('the script never lets a keys line reach the parser whole', () {
      const user = ServerUser(
        name: 'lk',
        uid: 1000,
        gid: 1000,
        comment: '',
        home: '/home/lk',
        shell: '/bin/bash',
        supplementaryGroups: [],
      );
      final script = UserManager.detailScript(user);

      expect(script, contains(r'if ($i ~ /^(ssh-|ecdsa-|sk-)/)'));
      expect(script, contains("if [ -r '/home/lk/.ssh/authorized_keys' ]"));
      // The read has to report its own failure rather than be swallowed.
      expect(script, isNot(contains('authorized_keys\' 2>/dev/null || true')));
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
