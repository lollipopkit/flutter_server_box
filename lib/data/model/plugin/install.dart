import 'dart:convert';

/// One installed plugin, as the app records it. PLUGINS.md section 7.
///
/// The record, not the plugin: what was unpacked from the `.sbp` are files,
/// and this says which version of them is installed, where it came from, and
/// what the user agreed it may do.
///
/// **Not in a backup.** A backup is settings and records, not files, so a
/// restored record would name a directory that is not there — a plugin that
/// fails to load on every launch. What a backup carries is the plugin's
/// *data*, which survives until the plugin is installed again (PLUGINS.md
/// section 7's `plugins` field).
class PluginInstall {
  const PluginInstall({
    required this.id,
    required this.version,
    required this.granted,
    required this.installedAt,
    this.repo,
    this.enabled = true,
  });

  /// The manifest's reverse-DNS id, which everything else keys on.
  final String id;

  /// The installed version, as the manifest spells it.
  final String version;

  /// Which repository it came from. Null is bundled with the app; [devRepo] is
  /// a directory on the developer's machine.
  final String? repo;

  /// Whether the user has it switched on.
  ///
  /// Separate from being installed, so turning a plugin off keeps its
  /// configuration and its data — and keeps its place in whatever the user
  /// arranged, which is the thing an uninstall-and-reinstall loses.
  final bool enabled;

  /// The permissions the user agreed to, by name.
  ///
  /// What was *consented to*, never what the manifest asks for: an update that
  /// adds a permission must not be able to use it before the user has seen it
  /// (PLUGINS.md 6.2), and the two are intersected when the plugin is loaded.
  final Set<String> granted;

  final DateTime installedAt;

  /// [repo] for a plugin loaded from a directory on the developer's machine —
  /// no packaging, no signature, and marked as such wherever it is listed.
  static const devRepo = 'dev';

  /// Whether this came with the app rather than from a repository.
  bool get bundled => repo == null;

  bool get isDev => repo == devRepo;

  PluginInstall copyWith({
    String? version,
    String? repo,
    bool clearRepo = false,
    bool? enabled,
    Set<String>? granted,
    DateTime? installedAt,
  }) => PluginInstall(
    id: id,
    version: version ?? this.version,
    repo: clearRepo ? null : (repo ?? this.repo),
    enabled: enabled ?? this.enabled,
    granted: granted ?? this.granted,
    installedAt: installedAt ?? this.installedAt,
  );

  /// For anything that has to carry the record as text — a diagnostic, a
  /// developer tool. Not a backup: see the class doc.
  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    if (repo != null) 'repo': repo,
    'enabled': enabled,
    'granted': granted.toList()..sort(),
    'installedAt': installedAt.millisecondsSinceEpoch,
  };

  factory PluginInstall.fromJson(Map<String, dynamic> json) => PluginInstall(
    id: json['id'] as String,
    version: json['version'] as String? ?? '',
    repo: json['repo'] as String?,
    enabled: json['enabled'] as bool? ?? true,
    granted: parseGranted(json['granted']),
    installedAt: DateTime.fromMillisecondsSinceEpoch(
      json['installedAt'] as int? ?? 0,
    ),
  );

  /// The stored `granted` column, which is a JSON array.
  ///
  /// Anything else reads as no permissions rather than as a failure. A row
  /// this build cannot decode is one whose consent it cannot vouch for, and
  /// the safe reading of that is that nothing was consented to — the plugin
  /// then works with what it can do without permission, and asks again.
  static Set<String> parseGranted(Object? raw) {
    if (raw is List) return raw.whereType<String>().toSet();
    if (raw is! String || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toSet();
    } catch (_) {}
    return const {};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginInstall &&
          id == other.id &&
          version == other.version &&
          repo == other.repo &&
          enabled == other.enabled &&
          granted.length == other.granted.length &&
          granted.containsAll(other.granted) &&
          installedAt == other.installedAt;

  @override
  int get hashCode => Object.hash(id, version, repo, enabled, installedAt);

  @override
  String toString() => 'PluginInstall($id@$version, repo: $repo)';
}
