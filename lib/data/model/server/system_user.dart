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
