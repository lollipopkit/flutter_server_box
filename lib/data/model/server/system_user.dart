final class ServerUser {
  const ServerUser({
    required this.name,
    required this.uid,
    required this.gid,
    required this.comment,
    required this.home,
    required this.shell,
    required this.supplementaryGroups,
    this.primaryGroup,
  });

  final String name;
  final int uid;
  final int gid;
  final String comment;
  final String home;
  final String shell;
  final String? primaryGroup;
  final List<String> supplementaryGroups;

  bool get isRoot => uid == 0;

  bool isSystem(int uidMin) => uid < uidMin;

  bool get loginDisabled {
    final executable = shell.split('/').last.toLowerCase();
    return executable == 'false' || executable == 'nologin';
  }
}

final class ServerUserCatalog {
  const ServerUserCatalog({
    required this.currentUser,
    required this.uidMin,
    required this.users,
  });

  final String currentUser;
  final int uidMin;
  final List<ServerUser> users;
}

final class ServerUserDraft {
  const ServerUserDraft({
    required this.name,
    required this.comment,
    required this.home,
    required this.shell,
    required this.primaryGroup,
    required this.supplementaryGroups,
    required this.createHome,
    required this.moveHome,
    required this.system,
    this.password,
  });

  final String name;
  final String comment;
  final String home;
  final String shell;
  final String primaryGroup;
  final List<String> supplementaryGroups;
  final bool createHome;
  final bool moveHome;
  final bool system;
  final String? password;
}

/// Whether an account can be logged into with a password.
enum ServerUserPasswordState { set, locked, none }

/// What `/etc/shadow`, `authorized_keys` and sudoers say about one account.
///
/// Every field is nullable and null means "not readable from here", never
/// "absent": all three sources are root-only on a normal system, and an
/// unprivileged session would otherwise report every account as having no
/// password and no keys.
final class ServerUserDetail {
  const ServerUserDetail({
    this.passwordState,
    this.passwordChanged,
    this.expires,
    this.neverExpires = false,
    this.sshKeyTypes,
    this.sudoRule,
  });

  final ServerUserPasswordState? passwordState;
  final DateTime? passwordChanged;

  /// Null when shadow was unreadable; absent-from-the-record is [neverExpires].
  final DateTime? expires;
  final bool neverExpires;

  /// Distinct key types in the account's `authorized_keys`, in file order.
  /// An empty list means the file was read and held none.
  final List<String>? sshKeyTypes;

  /// The right-hand side of the account's sudoers entry, e.g. `NOPASSWD: ALL`.
  final String? sudoRule;

  bool get isEmpty =>
      passwordState == null &&
      passwordChanged == null &&
      expires == null &&
      !neverExpires &&
      sshKeyTypes == null &&
      sudoRule == null;
}
