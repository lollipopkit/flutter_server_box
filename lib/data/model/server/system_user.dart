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

  /// `sbm_parser::users::SystemUser` as serde writes it.
  factory ServerUser.fromJson(Map<String, Object?> json) => ServerUser(
    name: json['name'] as String,
    uid: json['uid'] as int,
    gid: json['gid'] as int,
    comment: json['comment'] as String,
    home: json['home'] as String,
    shell: json['shell'] as String,
    primaryGroup: json['primary_group'] as String?,
    supplementaryGroups: (json['supplementary_groups'] as List).cast<String>(),
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'uid': uid,
    'gid': gid,
    'comment': comment,
    'home': home,
    'shell': shell,
    'primary_group': primaryGroup,
    'supplementary_groups': supplementaryGroups,
  };

  bool get isRoot => uid == 0;

  bool isSystem(int uidMin) => uid < uidMin;

  bool get loginDisabled {
    final executable = shell.split('/').last.toLowerCase();
    return executable == 'false' || executable == 'nologin';
  }
}

final class ServerGroup {
  const ServerGroup({
    required this.name,
    required this.gid,
    required this.members,
  });

  final String name;
  final int gid;
  final List<String> members;

  /// `sbm_parser::users::SystemGroup` as serde writes it.
  factory ServerGroup.fromJson(Map<String, Object?> json) => ServerGroup(
    name: json['name'] as String,
    gid: json['gid'] as int,
    members: (json['members'] as List).cast<String>(),
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'gid': gid,
    'members': members,
  };

  bool get isRoot => gid == 0 || name == 'root';

  bool isSystem(int gidMin) => gid < gidMin;
}

final class ServerUserCatalog {
  const ServerUserCatalog({
    required this.currentUser,
    required this.uidMin,
    required this.gidMin,
    required this.users,
    required this.groups,
  });

  /// `sbm_parser::users::UserCatalog` as serde writes it.
  factory ServerUserCatalog.fromJson(Map<String, Object?> json) =>
      ServerUserCatalog(
        currentUser: json['current_user'] as String,
        uidMin: json['uid_min'] as int,
        gidMin: json['gid_min'] as int? ?? 1000,
        users: [
          for (final user in json['users'] as List)
            ServerUser.fromJson(user as Map<String, Object?>),
        ],
        groups: [
          for (final group in json['groups'] as List? ?? const [])
            ServerGroup.fromJson(group as Map<String, Object?>),
        ],
      );

  final String currentUser;
  final int uidMin;
  final int gidMin;
  final List<ServerUser> users;
  final List<ServerGroup> groups;

  Map<String, Object?> toJson() => {
    'current_user': currentUser,
    'uid_min': uidMin,
    'gid_min': gidMin,
    'users': [for (final user in users) user.toJson()],
    'groups': [for (final group in groups) group.toJson()],
  };

  ServerGroup? findGroup(String name) {
    for (final group in groups) {
      if (group.name == name) return group;
    }
    return null;
  }

  /// Accounts whose primary gid is [group], sorted. Not the supplementary
  /// member list on the group itself.
  List<String> primaryMembersOf(ServerGroup group) {
    final names = [
      for (final user in users)
        if (user.gid == group.gid || user.primaryGroup == group.name) user.name,
    ]..sort();
    return names;
  }
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

  /// `sbm_parser::users::UserDraft` as serde reads it.
  Map<String, Object?> toJson() => {
    'name': name,
    'comment': comment,
    'home': home,
    'shell': shell,
    'primary_group': primaryGroup,
    'supplementary_groups': supplementaryGroups,
    'create_home': createHome,
    'move_home': moveHome,
    'system': system,
    'password': password,
  };
}

final class ServerGroupDraft {
  const ServerGroupDraft({
    required this.name,
    required this.members,
    required this.system,
  });

  final String name;
  final List<String> members;
  final bool system;

  /// `sbm_parser::users::GroupDraft` as serde reads it.
  Map<String, Object?> toJson() => {
    'name': name,
    'members': members,
    'system': system,
  };
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

  /// `sbm_parser::users::UserDetail` as serde writes it. Its instants are
  /// shadow's day counts, which are UTC midnights.
  factory ServerUserDetail.fromJson(Map<String, Object?> json) {
    DateTime? instant(Object? millis) => millis is int
        ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        : null;
    return ServerUserDetail(
      passwordState: switch (json['password_state']) {
        'set' => ServerUserPasswordState.set,
        'locked' => ServerUserPasswordState.locked,
        'none' => ServerUserPasswordState.none,
        _ => null,
      },
      passwordChanged: instant(json['password_changed_millis']),
      expires: instant(json['expires_millis']),
      neverExpires: json['never_expires'] as bool? ?? false,
      sshKeyTypes: (json['ssh_key_types'] as List?)?.cast<String>(),
      sudoRule: json['sudo_rule'] as String?,
    );
  }

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
