/// The machine's SMB and NFS shares as `sbm_parser::shares` reports them.
final class SmbShare {
  const SmbShare({
    required this.name,
    required this.path,
    required this.comment,
    required this.readOnly,
    required this.guest,
    required this.users,
    required this.timeMachine,
    required this.recycle,
    required this.managed,
  });

  factory SmbShare.fromJson(Map<String, Object?> json) => SmbShare(
    name: json['name'] as String,
    path: json['path'] as String,
    comment: json['comment'] as String?,
    readOnly: json['read_only'] as bool,
    guest: json['guest'] as bool,
    users: (json['users'] as List).cast<String>(),
    timeMachine: json['time_machine'] as bool? ?? false,
    recycle: json['recycle'] as bool? ?? false,
    managed: json['managed'] as bool,
  );

  final String name;
  final String path;
  final String? comment;
  final bool readOnly;
  final bool guest;
  final List<String> users;
  final bool timeMachine;
  final bool recycle;
  final bool managed;

  Map<String, Object?> toJson() => {
    'name': name,
    'path': path,
    'comment': comment,
    'read_only': readOnly,
    'guest': guest,
    'users': users,
    'time_machine': timeMachine,
    'recycle': recycle,
    'managed': managed,
  };
}

final class NfsClient {
  const NfsClient({
    required this.host,
    required this.readOnly,
    required this.squash,
    required this.options,
  });

  factory NfsClient.fromJson(Map<String, Object?> json) => NfsClient(
    host: json['host'] as String,
    readOnly: json['read_only'] as bool,
    squash: json['squash'] as String? ?? 'root',
    options: (json['options'] as List? ?? const []).cast<String>(),
  );

  final String host;
  final bool readOnly;
  final String squash;
  final List<String> options;

  Map<String, Object?> toJson() => {
    'host': host,
    'read_only': readOnly,
    'squash': squash,
    'options': options,
  };
}

final class NfsExport {
  const NfsExport({required this.path, required this.clients, required this.managed});

  factory NfsExport.fromJson(Map<String, Object?> json) => NfsExport(
    path: json['path'] as String,
    clients: [
      for (final client in json['clients'] as List)
        NfsClient.fromJson(client as Map<String, Object?>),
    ],
    managed: json['managed'] as bool,
  );

  final String path;
  final List<NfsClient> clients;
  final bool managed;

  Map<String, Object?> toJson() => {
    'path': path,
    'clients': [for (final client in clients) client.toJson()],
    'managed': managed,
  };
}

final class SmbConnection {
  const SmbConnection({required this.share, required this.user, required this.machine, required this.since});

  factory SmbConnection.fromJson(Map<String, Object?> json) => SmbConnection(
    share: json['share'] as String,
    user: json['user'] as String?,
    machine: json['machine'] as String,
    since: json['since'] as String?,
  );

  final String share;
  final String? user;
  final String machine;
  final String? since;
}

final class ShareConnections {
  const ShareConnections({required this.smb, required this.nfs});

  factory ShareConnections.fromJson(Map<String, Object?> json) => ShareConnections(
    smb: [
      for (final item in json['smb'] as List)
        SmbConnection.fromJson(item as Map<String, Object?>),
    ],
    nfs: (json['nfs'] as List).cast<String>(),
  );

  final List<SmbConnection> smb;
  final List<String> nfs;
}

final class SharesView {
  const SharesView({
    required this.tools,
    required this.smbActive,
    required this.nfsActive,
    required this.smb,
    required this.nfs,
  });

  factory SharesView.fromJson(Map<String, Object?> json) => SharesView(
    tools: (json['tools'] as List).cast<String>(),
    smbActive: json['smb_active'] as bool,
    nfsActive: json['nfs_active'] as bool,
    smb: [
      for (final item in json['smb'] as List)
        SmbShare.fromJson(item as Map<String, Object?>),
    ],
    nfs: [
      for (final item in json['nfs'] as List)
        NfsExport.fromJson(item as Map<String, Object?>),
    ],
  );

  final List<String> tools;
  final bool smbActive;
  final bool nfsActive;
  final List<SmbShare> smb;
  final List<NfsExport> nfs;
}
