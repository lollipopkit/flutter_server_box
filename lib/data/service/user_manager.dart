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

  static Future<ServerUserCatalog> list(ServerExec exec) async {
    final result = await exec.run(listScript);
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
    return '''$command
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
