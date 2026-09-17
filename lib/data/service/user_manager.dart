import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/system_user.dart';

final class UserManagerException implements Exception {
  const UserManagerException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class UserManager {
  static const currentMarker = 'SrvBoxUsers.Current\t';
  static const uidMinMarker = 'SrvBoxUsers.UidMin\t';
  static const passwdMarker = 'SrvBoxUsers.Passwd';
  static const groupMarker = 'SrvBoxUsers.Group';

  static const listScript = r'''
set -e
printf 'SrvBoxUsers.Current\t'
id -un
printf 'SrvBoxUsers.UidMin\t'
awk '$1 == "UID_MIN" { print $2; found=1; exit } END { if (!found) print 1000 }' /etc/login.defs 2>/dev/null || printf '1000\n'
printf 'SrvBoxUsers.Passwd\n'
if command -v getent >/dev/null 2>&1; then
  getent passwd
else
  cat /etc/passwd
fi
printf 'SrvBoxUsers.Group\n'
if command -v getent >/dev/null 2>&1; then
  getent group
elif [ -r /etc/group ]; then
  cat /etc/group
fi
''';

  static const detailShadowMarker = 'SrvBoxUserDetail.Shadow';
  static const detailStatusMarker = 'SrvBoxUserDetail.Status';
  static const detailKeysMarker = 'SrvBoxUserDetail.Keys';
  static const detailSudoMarker = 'SrvBoxUserDetail.Sudo';

  /// Written only when `authorized_keys` was actually read. Its absence is
  /// what tells "could not read it" from "read it, there were none" — a
  /// distinction `|| true` used to swallow, reporting an unreadable file as an
  /// account with no keys at all.
  static const detailKeysReadMarker = 'SrvBoxUserDetail.KeysRead';

  /// Prints the key-type token of each line and nothing else.
  ///
  /// `authorized_keys` is written by whoever owns the account, and the section
  /// markers above travel as plain text on the same stream. Passing its lines
  /// through meant an unprivileged user could put `SrvBoxUserDetail.Sudo` in
  /// their own file and fabricate the sudo rule this page then displayed. A
  /// token matching this pattern cannot collide with a marker.
  static const _keyTypeFilter =
      r"awk '{ for (i = 1; i <= NF; i++) "
      r"if ($i ~ /^(ssh-|ecdsa-|sk-)/) { print $i; break } }'";

  /// Reads what `/etc/shadow`, `authorized_keys` and sudoers hold for one
  /// account.
  ///
  /// Every command is allowed to fail. All three are root-only on a normal
  /// system, and the page this feeds shows what it could read rather than
  /// asking for a password: looking at an account is not an action taken on
  /// it.
  ///
  /// `getent shadow` rather than `passwd -S` or `chage -l`, whose dates are
  /// written in the server's locale. Shadow's third and eighth fields are days
  /// since the epoch, which need no parsing rule that differs by language.
  static String detailScript(ServerUser user) {
    if (!validName(user.name)) {
      throw const UserManagerException('Invalid user name');
    }
    final name = shellSingleQuote(user.name);
    final keys = shellSingleQuote('${user.home}/.ssh/authorized_keys');
    return [
      "printf '$detailShadowMarker\\n'",
      'getent shadow $name 2>/dev/null || true',
      "printf '$detailStatusMarker\\n'",
      'passwd -S $name 2>/dev/null || true',
      "printf '$detailKeysMarker\\n'",
      'if [ -r $keys ]; then',
      "printf '$detailKeysReadMarker\\n'",
      '$_keyTypeFilter $keys 2>/dev/null',
      'fi',
      "printf '$detailSudoMarker\\n'",
      'sudo -nlU $name 2>/dev/null || true',
      '',
    ].join('\n');
  }

  /// Handed to `sh`, like [list]: the script has an `if`, and the account's
  /// login shell — which is what runs a command given without an entry — may
  /// be fish, which does not read one.
  static Future<ServerUserDetail> detail(
    ServerExec exec,
    ServerUser user,
  ) async {
    final result = await exec.run(detailScript(user), entry: 'sh');
    return parseDetail(result.stdout);
  }

  static ServerUserDetail parseDetail(String output) {
    const markers = {
      detailShadowMarker,
      detailStatusMarker,
      detailKeysMarker,
      detailSudoMarker,
    };
    final sections = <String, List<String>>{};
    var section = '';
    for (final rawLine in output.replaceAll('\r\n', '\n').split('\n')) {
      final line = rawLine.trimRight();
      if (markers.contains(line)) {
        section = line;
        sections[section] = [];
        continue;
      }
      if (section.isEmpty) continue;
      sections[section]!.add(line);
    }

    ServerUserPasswordState? state;
    DateTime? changed;
    DateTime? expires;
    var neverExpires = false;

    final shadow = sections[detailShadowMarker]?.firstWhere(
      (line) => line.contains(':'),
      orElse: () => '',
    );
    if (shadow != null && shadow.isNotEmpty) {
      final fields = shadow.split(':');
      if (fields.length >= 2) state = _passwordState(fields[1]);
      if (fields.length >= 3) changed = _daysToDate(fields[2]);
      if (fields.length >= 8) {
        final raw = fields[7].trim();
        // Empty is the only thing that means never. A field that will not
        // parse - zero, negative, garbage - means the record could not be
        // read, and "Never" is the wrong half of that to guess: it is a claim
        // about an account's expiry made from no evidence.
        neverExpires = raw.isEmpty;
        if (!neverExpires) expires = _daysToDate(raw);
      }
    } else {
      // `passwd -S` answers P / L / NP without the hash, and a shell is
      // sometimes allowed it for its own account.
      final status = sections[detailStatusMarker]?.firstWhere(
        (line) => line.trim().isNotEmpty,
        orElse: () => '',
      );
      final fields = status?.trim().split(RegExp(r'\s+')) ?? const <String>[];
      if (fields.length >= 2) {
        state = switch (fields[1].toUpperCase()) {
          'P' => ServerUserPasswordState.set,
          'L' => ServerUserPasswordState.locked,
          'NP' => ServerUserPasswordState.none,
          _ => null,
        };
      }
    }

    List<String>? keyTypes;
    final keyLines = sections[detailKeysMarker];
    if (keyLines != null &&
        keyLines.isNotEmpty &&
        keyLines.first.trim() == detailKeysReadMarker) {
      keyTypes = <String>[];
      for (final line in keyLines.skip(1)) {
        final type = _sshKeyType(line);
        if (type != null && !keyTypes.contains(type)) keyTypes.add(type);
      }
    }

    String? sudoRule;
    for (final line in sections[detailSudoMarker] ?? const <String>[]) {
      final match = RegExp(r'^\s*\(([^)]*)\)\s*(.+)$').firstMatch(line);
      if (match == null) continue;
      sudoRule = match.group(2)!.trim();
      break;
    }

    return ServerUserDetail(
      passwordState: state,
      passwordChanged: changed,
      expires: expires,
      neverExpires: neverExpires,
      sshKeyTypes: keyTypes,
      sudoRule: sudoRule,
    );
  }

  /// `!`, `!!` and `*` are the three ways a distribution writes "cannot log in
  /// with a password". An empty field is no password at all, which is a very
  /// different thing and must not read as locked.
  static ServerUserPasswordState _passwordState(String hash) {
    final value = hash.trim();
    if (value.isEmpty) return ServerUserPasswordState.none;
    if (value == '*' || value.startsWith('!')) {
      return ServerUserPasswordState.locked;
    }
    return ServerUserPasswordState.set;
  }

  static DateTime? _daysToDate(String raw) {
    final days = int.tryParse(raw.trim());
    if (days == null || days <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      days * Duration.millisecondsPerDay,
      isUtc: true,
    );
  }

  /// The type field of one `authorized_keys` line, skipping the options that
  /// may precede it. Comments, blank lines and anything unrecognised answer
  /// null.
  static String? _sshKeyType(String line) {
    final value = line.trim();
    if (value.isEmpty || value.startsWith('#')) return null;
    for (final token in value.split(RegExp(r'\s+'))) {
      final type = token.toLowerCase();
      if (type.startsWith('sk-ssh-')) return 'sk-${type.substring(7)}';
      if (type.startsWith('sk-ecdsa-')) return 'sk-ecdsa';
      if (type.startsWith('ssh-')) return type.substring(4);
      if (type.startsWith('ecdsa-')) return 'ecdsa';
    }
    return null;
  }

  /// Handed to `sh` rather than run as the command. Without an entry the
  /// script is parsed by the account's login shell, and fish stops at the
  /// first `if ...; then` — so the page showed fish's diagnostic where the
  /// user list should have been. The create, edit and delete scripts already
  /// reach `sh` through `PrivilegedExec`.
  static Future<ServerUserCatalog> list(ServerExec exec) async {
    final result = await exec.run(listScript, entry: 'sh');
    if (!result.succeeded) {
      final detail = result.combined.trim();
      throw UserManagerException(
        detail.isEmpty ? 'Unable to list system users' : detail,
      );
    }
    return parse(result.stdout);
  }

  static ServerUserCatalog parse(String output) {
    String? currentUser;
    var uidMin = 1000;
    final passwd = <List<String>>[];
    final groupsByGid = <int, String>{};
    final supplementary = <String, List<String>>{};
    var section = '';

    for (final rawLine in output.replaceAll('\r\n', '\n').split('\n')) {
      final line = rawLine.trimRight();
      if (line.startsWith(currentMarker)) {
        currentUser = line.substring(currentMarker.length).trim();
        continue;
      }
      if (line.startsWith(uidMinMarker)) {
        uidMin = int.tryParse(line.substring(uidMinMarker.length).trim()) ?? 1000;
        continue;
      }
      if (line == passwdMarker) {
        section = passwdMarker;
        continue;
      }
      if (line == groupMarker) {
        section = groupMarker;
        continue;
      }
      if (line.isEmpty) continue;

      if (section == passwdMarker) {
        final fields = line.split(':');
        if (fields.length >= 7 &&
            int.tryParse(fields[2]) != null &&
            int.tryParse(fields[3]) != null) {
          passwd.add(fields);
        }
      } else if (section == groupMarker) {
        final fields = line.split(':');
        if (fields.length < 4) continue;
        final gid = int.tryParse(fields[2]);
        if (gid == null) continue;
        groupsByGid[gid] = fields[0];
        for (final member in fields[3].split(',')) {
          final name = member.trim();
          if (name.isEmpty) continue;
          supplementary.putIfAbsent(name, () => []).add(fields[0]);
        }
      }
    }

    if (currentUser == null || currentUser.isEmpty) {
      throw const UserManagerException('Unable to determine the current user');
    }

    final users = passwd.map((fields) {
      final name = fields[0];
      final gid = int.parse(fields[3]);
      final primaryGroup = groupsByGid[gid];
      final extraGroups = List<String>.from(
        supplementary[name] ?? const <String>[],
      );
      if (primaryGroup != null) extraGroups.remove(primaryGroup);
      extraGroups.sort();
      return ServerUser(
        name: name,
        uid: int.parse(fields[2]),
        gid: gid,
        comment: fields[4],
        home: fields[5],
        shell: fields[6],
        primaryGroup: primaryGroup,
        supplementaryGroups: extraGroups,
      );
    }).toList()
      ..sort((a, b) {
        final uidOrder = a.uid.compareTo(b.uid);
        return uidOrder == 0 ? a.name.compareTo(b.name) : uidOrder;
      });

    return ServerUserCatalog(
      currentUser: currentUser,
      uidMin: uidMin,
      users: users,
    );
  }

  static bool validName(String name) {
    return RegExp(r'^[a-z_][a-z0-9_.-]*\$?$').hasMatch(name);
  }

  static String? validateDraft(ServerUserDraft draft) {
    if (!validName(draft.name)) return 'Invalid user name';
    if (_hasLineBreak(draft.comment) ||
        _hasLineBreak(draft.home) ||
        _hasLineBreak(draft.shell) ||
        _hasLineBreak(draft.primaryGroup)) {
      return 'User fields cannot contain line breaks';
    }
    if (draft.primaryGroup.isNotEmpty && !validName(draft.primaryGroup)) {
      return 'Invalid primary group';
    }
    if (draft.supplementaryGroups.any((group) => !validName(group))) {
      return 'Invalid supplementary group';
    }
    if (draft.password case final password?
        when password.contains('\n') ||
            password.contains('\r') ||
            password.contains('\u0000')) {
      return 'Password cannot contain line breaks';
    }
    return null;
  }

  static String createScript(ServerUserDraft draft) {
    _validateOrThrow(draft);
    final args = <String>['useradd'];
    if (draft.system) args.add('-r');
    args.add(draft.createHome ? '-m' : '-M');
    if (draft.comment.isNotEmpty) {
      args.addAll(['-c', shellSingleQuote(draft.comment)]);
    }
    if (draft.home.isNotEmpty) {
      args.addAll(['-d', shellSingleQuote(draft.home)]);
    }
    if (draft.shell.isNotEmpty) {
      args.addAll(['-s', shellSingleQuote(draft.shell)]);
    }
    if (draft.primaryGroup.isNotEmpty) {
      args.addAll(['-g', shellSingleQuote(draft.primaryGroup)]);
    }
    if (draft.supplementaryGroups.isNotEmpty) {
      args.addAll([
        '-G',
        shellSingleQuote(draft.supplementaryGroups.join(',')),
      ]);
    }
    args.add(shellSingleQuote(draft.name));

    return _withPassword(args.join(' '), draft.name, draft.password);
  }

  static String editScript(ServerUser original, ServerUserDraft draft) {
    _validateOrThrow(draft);
    if (draft.name != original.name) {
      throw ArgumentError.value(draft.name, 'name', 'Renaming is not supported');
    }

    final args = <String>['usermod'];
    if (draft.comment != original.comment) {
      args.addAll(['-c', shellSingleQuote(draft.comment)]);
    }
    if (draft.home.isNotEmpty && draft.home != original.home) {
      args.addAll(['-d', shellSingleQuote(draft.home)]);
      if (draft.moveHome) args.add('-m');
    }
    if (draft.shell.isNotEmpty && draft.shell != original.shell) {
      args.addAll(['-s', shellSingleQuote(draft.shell)]);
    }
    if (draft.primaryGroup.isNotEmpty &&
        draft.primaryGroup != original.primaryGroup) {
      args.addAll(['-g', shellSingleQuote(draft.primaryGroup)]);
    }
    if (!_sameStrings(
      draft.supplementaryGroups,
      original.supplementaryGroups,
    )) {
      args.addAll([
        '-G',
        shellSingleQuote(draft.supplementaryGroups.join(',')),
      ]);
    }
    if (args.length > 1) args.add(shellSingleQuote(original.name));

    final command = args.length == 1 ? ':' : args.join(' ');
    return _withPassword(command, original.name, draft.password);
  }

  static String deleteScript(ServerUser user, {required bool removeHome}) {
    if (user.isRoot) {
      throw ArgumentError.value(user.name, 'user', 'The root user cannot be deleted');
    }
    if (!validName(user.name)) {
      throw ArgumentError.value(user.name, 'user', 'Invalid user name');
    }
    return [
      'userdel',
      if (removeHome) '-r',
      shellSingleQuote(user.name),
    ].join(' ');
  }

  static String _withPassword(
    String command,
    String user,
    String? password,
  ) {
    if (password == null || password.isEmpty) return command;
    return '''set -e
$command
chpasswd <<'SrvBoxUserPassword'
$user:$password
SrvBoxUserPassword''';
  }

  static void _validateOrThrow(ServerUserDraft draft) {
    final error = validateDraft(draft);
    if (error != null) throw ArgumentError(error);
  }

  static bool _hasLineBreak(String value) {
    return value.contains('\n') ||
        value.contains('\r') ||
        value.contains('\u0000');
  }

  static bool _sameStrings(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
