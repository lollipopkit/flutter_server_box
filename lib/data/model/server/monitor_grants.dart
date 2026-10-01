/// Why a grant is not usable, as a `monitor` agent says it — see
/// `docs/dev/monitor-permissions.md`.
enum MonitorGrantWhy {
  /// The account's role does not hold it: the agent's admin decides.
  notGranted,

  /// Held, but not over this connection: it needs HTTPS (or the agent's
  /// `allow_insecure` and this app's insecure toggle).
  insecureTransport,

  /// Held, but the machine side is not set up — the file API with no roots.
  notConfigured,

  /// A reason a later agent added. Read as "not usable" with no more said.
  unknown;

  static MonitorGrantWhy? fromWire(Object? value) => switch (value) {
    null => null,
    'not_granted' => notGranted,
    'insecure_transport' => insecureTransport,
    'not_configured' => notConfigured,
    _ => unknown,
  };
}

/// One grant as the agent answers it for the account this app logged in as.
class MonitorGrant {
  const MonitorGrant({required this.ok, this.why});

  final bool ok;

  /// Only when [ok] is false.
  final MonitorGrantWhy? why;

  static const denied = MonitorGrant(ok: false, why: MonitorGrantWhy.notGranted);

  factory MonitorGrant.fromJson(Object? json) {
    if (json is! Map) return denied;
    final ok = json['ok'] == true;
    return MonitorGrant(
      ok: ok,
      why: ok ? null : MonitorGrantWhy.fromWire(json['why']) ?? MonitorGrantWhy.unknown,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MonitorGrant && other.ok == ok && other.why == why;

  @override
  int get hashCode => Object.hash(ok, why);

  @override
  String toString() => ok ? 'ok' : 'denied(${why?.name})';
}

/// What `files` lets an account do.
enum MonitorFilesMode {
  /// List, stat, read.
  read,

  /// And write, mkdir, rename, chmod, remove.
  write;

  static MonitorFilesMode? fromWire(Object? value) => switch (value) {
    'read' => read,
    'write' => write,
    _ => null,
  };
}

/// The grants of `GET /api/v1/capabilities`, for the caller.
///
/// Absent from an agent older than roles, which answers with the
/// `remote_access` booleans alone — see `MonitorRemoteAccess`.
class MonitorGrants {
  const MonitorGrants({
    this.shell = MonitorGrant.denied,
    this.sshTerminal = MonitorGrant.denied,
    this.files = MonitorGrant.denied,
    this.filesMode,
    this.connect = MonitorGrant.denied,
    this.connectAllow = const [],
    this.listen = MonitorGrant.denied,
    this.listenPublic = false,
  });

  final MonitorGrant shell;
  final MonitorGrant sshTerminal;
  final MonitorGrant files;

  /// What [files] allows; null when the agent did not say, which is read as
  /// writable — the agent refuses a write it does not allow either way.
  final MonitorFilesMode? filesMode;

  final MonitorGrant connect;

  /// Where [connect] may reach; empty is anywhere.
  final List<String> connectAllow;

  final MonitorGrant listen;
  final bool listenPublic;

  /// Whether files are browsed without being changed.
  bool get filesReadOnly => files.ok && filesMode == MonitorFilesMode.read;

  factory MonitorGrants.fromJson(Map<String, dynamic> json) {
    Map? obj(String key) => json[key] is Map ? json[key] as Map : null;
    return MonitorGrants(
      shell: MonitorGrant.fromJson(json['shell']),
      sshTerminal: MonitorGrant.fromJson(json['ssh_terminal']),
      files: MonitorGrant.fromJson(json['files']),
      filesMode: MonitorFilesMode.fromWire(obj('files')?['mode']),
      connect: MonitorGrant.fromJson(json['connect']),
      connectAllow: [
        for (final entry in (obj('connect')?['allow'] as List?) ?? const [])
          if (entry is String) entry,
      ],
      listen: MonitorGrant.fromJson(json['listen']),
      listenPublic: obj('listen')?['public'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MonitorGrants &&
      other.shell == shell &&
      other.sshTerminal == sshTerminal &&
      other.files == files &&
      other.filesMode == filesMode &&
      other.connect == connect &&
      _sameList(other.connectAllow, connectAllow) &&
      other.listen == listen &&
      other.listenPublic == listenPublic;

  @override
  int get hashCode => Object.hash(
    shell,
    sshTerminal,
    files,
    filesMode,
    connect,
    Object.hashAll(connectAllow),
    listen,
    listenPublic,
  );

  @override
  String toString() =>
      'MonitorGrants(shell: $shell, sshTerminal: $sshTerminal, files: $files '
      '${filesMode?.name}, connect: $connect $connectAllow, listen: $listen '
      'public=$listenPublic)';
}

/// Who this app is logged in as on the agent.
class MonitorMe {
  const MonitorMe({
    required this.username,
    required this.role,
    required this.admin,
  });

  final String username;
  final String role;

  /// May manage accounts, roles and the agent's configuration.
  final bool admin;

  static MonitorMe? fromJson(Object? json) {
    if (json is! Map) return null;
    final username = json['username'];
    final role = json['role'];
    if (username is! String || role is! String) return null;
    return MonitorMe(username: username, role: role, admin: json['admin'] == true);
  }
}

/// A role's grants as an admin edits them: what is granted and with which
/// options, rather than whether it works over this connection.
class MonitorRoleGrants {
  const MonitorRoleGrants({
    this.shell = false,
    this.sshTerminal = false,
    this.files,
    this.connectAllow,
    this.listen,
  });

  final bool shell;
  final bool sshTerminal;

  /// Null is not granted.
  final MonitorFilesMode? files;

  /// Null is not granted; empty is anywhere.
  final List<String>? connectAllow;

  /// Null is not granted.
  final MonitorListenGrant? listen;

  factory MonitorRoleGrants.fromJson(Map<String, dynamic> json) {
    final files = json['files'];
    final connect = json['connect'];
    final listen = json['listen'];
    return MonitorRoleGrants(
      shell: json['shell'] == true,
      sshTerminal: json['ssh_terminal'] == true,
      files: files is Map
          ? MonitorFilesMode.fromWire(files['mode']) ?? MonitorFilesMode.read
          : null,
      connectAllow: connect is Map
          ? [
              for (final e in (connect['allow'] as List?) ?? const [])
                if (e is String) e,
            ]
          : null,
      listen: listen is Map ? MonitorListenGrant.fromJson(listen) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'shell': shell,
    'ssh_terminal': sshTerminal,
    'files': files == null ? null : {'mode': files!.name},
    'connect': connectAllow == null ? null : {'allow': connectAllow},
    'listen': listen?.toJson(),
  };

  MonitorRoleGrants copyWith({
    bool? shell,
    bool? sshTerminal,
    MonitorFilesMode? Function()? files,
    List<String>? Function()? connectAllow,
    MonitorListenGrant? Function()? listen,
  }) => MonitorRoleGrants(
    shell: shell ?? this.shell,
    sshTerminal: sshTerminal ?? this.sshTerminal,
    files: files == null ? this.files : files(),
    connectAllow: connectAllow == null ? this.connectAllow : connectAllow(),
    listen: listen == null ? this.listen : listen(),
  );
}

/// The options of a held `listen` grant.
class MonitorListenGrant {
  const MonitorListenGrant({this.public = false, this.ports});

  /// Non-loopback binds.
  final bool public;

  /// The range a forward may bind, or null for any.
  final (int, int)? ports;

  factory MonitorListenGrant.fromJson(Map json) {
    final ports = json['ports'];
    return MonitorListenGrant(
      public: json['public'] == true,
      ports: ports is List &&
              ports.length == 2 &&
              ports[0] is int &&
              ports[1] is int
          ? (ports[0] as int, ports[1] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'public': public,
    'ports': ports == null ? null : [ports!.$1, ports!.$2],
  };
}

/// A role, from `GET /api/v1/roles`.
class MonitorRole {
  const MonitorRole({
    required this.name,
    this.admin = false,
    this.builtin = false,
    this.grants = const MonitorRoleGrants(),
  });

  final String name;
  final bool admin;
  final bool builtin;
  final MonitorRoleGrants grants;

  /// What a role name may be — the agent's rule, so a form can say so first.
  static final namePattern = RegExp(r'^[a-z0-9_-]{1,32}$');

  factory MonitorRole.fromJson(Map<String, dynamic> json) => MonitorRole(
    name: json['name'] as String? ?? '',
    admin: json['admin'] == true,
    builtin: json['builtin'] == true,
    grants: MonitorRoleGrants.fromJson(
      (json['grants'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );

  /// The body of a create or an update: `admin` and `builtin` are the agent's
  /// to decide, and are sent as they were read.
  Map<String, dynamic> toJson() => {
    'name': name,
    'admin': admin,
    'grants': grants.toJson(),
  };

  MonitorRole copyWith({String? name, MonitorRoleGrants? grants}) => MonitorRole(
    name: name ?? this.name,
    admin: admin,
    builtin: builtin,
    grants: grants ?? this.grants,
  );
}

/// An account, from `GET /api/v1/users`.
class MonitorUser {
  const MonitorUser({
    required this.username,
    required this.role,
    this.createdAt,
    this.lastLogin,
  });

  final String username;
  final String role;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  factory MonitorUser.fromJson(Map<String, dynamic> json) => MonitorUser(
    username: json['username'] as String? ?? '',
    role: json['role'] as String? ?? '',
    createdAt: switch (json['created_at']) {
      final String at => DateTime.tryParse(at)?.toLocal(),
      _ => null,
    },
    lastLogin: switch (json['last_login']) {
      final String at => DateTime.tryParse(at)?.toLocal(),
      _ => null,
    },
  );
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
