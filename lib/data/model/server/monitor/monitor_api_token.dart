/// Command rules for `run_command` on the Monitor MCP server, used both in the
/// global MCP policy and on individual API tokens (#1681).
class MonitorMcpCommandPolicy {
  const MonitorMcpCommandPolicy({
    this.mode = modeAllowAll,
    this.allow = const [],
    this.deny = const [],
  });

  static const modeAllowAll = 'allow_all';
  static const modeAllowlist = 'allowlist';

  final String mode;
  final List<String> allow;
  final List<String> deny;

  bool get isDefault =>
      mode == modeAllowAll && allow.isEmpty && deny.isEmpty;

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'allow': allow,
    'deny': deny,
  };

  static MonitorMcpCommandPolicy fromJson(Object? raw) {
    if (raw is! Map) return const MonitorMcpCommandPolicy();
    final map = raw.cast<String, dynamic>();
    return MonitorMcpCommandPolicy(
      mode: map['mode'] as String? ?? modeAllowAll,
      allow: (map['allow'] as List?)?.whereType<String>().toList() ?? const [],
      deny: (map['deny'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// Global MCP permission ceiling (`GET/PUT /api/v1/api-tokens/policy`).
class MonitorMcpPolicy {
  const MonitorMcpPolicy({
    required this.scopes,
    required this.commands,
    this.configScopes = MonitorApiToken.allScopes,
  });

  final List<String> scopes;
  final MonitorMcpCommandPolicy commands;
  final List<String> configScopes;

  static MonitorMcpPolicy fromJson(Map<String, dynamic> json) =>
      MonitorMcpPolicy(
        scopes:
            (json['scopes'] as List?)?.whereType<String>().toList() ??
            MonitorApiToken.allScopes,
        commands: MonitorMcpCommandPolicy.fromJson(json['commands']),
        configScopes:
            (json['config_scopes'] as List?)?.whereType<String>().toList() ??
            MonitorApiToken.allScopes,
      );
}

/// An API token an MCP client signs in to a Monitor with
/// (`GET /api/v1/api-tokens`, #1681). The Monitor keeps only a BLAKE3 digest:
/// only a token just minted carries a secret value, and only once.
class MonitorApiToken {
  const MonitorApiToken({
    required this.id,
    required this.name,
    required this.scopes,
    required this.commands,
    required this.createdAt,
    required this.expiresAt,
    this.expired = false,
    this.lastUsedAt,
    this.lastUsedIp,
  });

  final int id;
  final String name;
  final List<String> scopes;
  final MonitorMcpCommandPolicy commands;
  final String createdAt;
  final String expiresAt;
  final bool expired;
  final String? lastUsedAt;
  final String? lastUsedIp;

  static const scopeRead = 'read';
  static const scopeFsRead = 'fs_read';
  static const scopeFsWrite = 'fs_write';
  static const scopeExec = 'exec';
  static const scopeProcess = 'process';
  static const scopeService = 'service';
  static const scopeContainer = 'container';
  static const scopeCron = 'cron';
  static const scopeVirt = 'virt';
  static const scopeStacks = 'stacks';
  static const scopePower = 'power';

  static const allScopes = [
    scopeRead,
    scopeFsRead,
    scopeFsWrite,
    scopeExec,
    scopeProcess,
    scopeService,
    scopeContainer,
    scopeCron,
    scopeVirt,
    scopeStacks,
    scopePower,
  ];

  static MonitorApiToken fromJson(Map<String, dynamic> json) => MonitorApiToken(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    scopes: (json['scopes'] as List?)?.whereType<String>().toList() ?? const [],
    commands: MonitorMcpCommandPolicy.fromJson(json['commands']),
    createdAt: json['created_at'] as String? ?? '',
    expiresAt: json['expires_at'] as String? ?? '',
    expired: json['expired'] as bool? ?? false,
    lastUsedAt: json['last_used_at'] as String?,
    lastUsedIp: json['last_used_ip'] as String?,
  );

  static List<MonitorApiToken> listFrom(Object? data) => [
    for (final row in (data as List? ?? const []).whereType<Map>())
      MonitorApiToken.fromJson(row.cast<String, dynamic>()),
  ];
}
