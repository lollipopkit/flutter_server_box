import 'dart:convert';

import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/plugin/repo_record.dart';

/// Where an installed plugin came from, which is what decides who may replace
/// it.
///
/// One stored column — a sentinel or a repository address — read here as a
/// total answer. It used to be a nullable URL, so three sources shared two
/// values: a `.sbp` the user picked was recorded exactly like one shipped with
/// the app, and the settings page called it "Bundled" although no build has
/// ever shipped a plugin. The store then had no way to tell that the copy it
/// was offering an update for was not one of its own.
enum PluginOrigin {
  /// A directory on the developer's machine, re-read on every refresh.
  dev,

  /// A `.sbp` the user opened. Nothing knows where it will come from next.
  file,

  /// A repository, which is the only origin an update can come from.
  repo,
}

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
    this.previous,
  });

  /// The manifest's reverse-DNS id, which everything else keys on.
  final String id;

  /// The installed version, as the manifest spells it.
  final String version;

  /// Where it came from: a repository's address, or one of the sentinels
  /// [devRepo] and [fileRepo]. Read through [origin] rather than compared.
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

  /// The record this one replaced, or null.
  ///
  /// **What makes an update undoable.** The files of the version before are
  /// kept beside the installed ones and this is the row that went with them —
  /// including `granted`, which is the part the directory cannot supply: it is
  /// what the user *agreed to*, and re-deriving it from the old manifest would
  /// grant whatever that version asked for.
  ///
  /// One level, never a chain. Two updates back is not a state anybody asked
  /// for, and keeping every version a plugin has ever been is a directory that
  /// only grows.
  final PluginInstall? previous;

  /// [repo] for a plugin loaded from a directory on the developer's machine —
  /// no packaging, no signature, and marked as such wherever it is listed.
  static const devRepo = 'dev';

  /// [repo] for a `.sbp` the user opened from a file picker.
  ///
  /// Neither sentinel can collide with a repository, which is always an
  /// absolute URL.
  static const fileRepo = 'file';

  /// Where it came from. See [PluginOrigin].
  PluginOrigin get origin => switch (repo) {
    devRepo => PluginOrigin.dev,
    fileRepo => PluginOrigin.file,
    // TODO: drop the null case once no install predates `fileRepo`. No build
    // has ever shipped a plugin, so a null column is a `.sbp` the user opened,
    // written when that had no name of its own.
    null => PluginOrigin.file,
    _ => PluginOrigin.repo,
  };

  bool get isDev => origin == PluginOrigin.dev;

  /// The repository this came from, or null when it came from somewhere a
  /// repository cannot update.
  String? get repoUrl => origin == PluginOrigin.repo ? repo : null;

  PluginInstall copyWith({
    String? id,
    String? version,
    String? repo,
    bool clearRepo = false,
    bool? enabled,
    Set<String>? granted,
    DateTime? installedAt,
    PluginInstall? previous,
    bool clearPrevious = false,
  }) => PluginInstall(
    id: id ?? this.id,
    version: version ?? this.version,
    repo: clearRepo ? null : (repo ?? this.repo),
    enabled: enabled ?? this.enabled,
    granted: granted ?? this.granted,
    installedAt: installedAt ?? this.installedAt,
    previous: clearPrevious ? null : (previous ?? this.previous),
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
    // Left out rather than nested: what is stored in `previous` is one record,
    // and a record carrying its own predecessor would let a chain build up
    // through repeated updates.
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
          installedAt == other.installedAt &&
          previous == other.previous;

  @override
  int get hashCode => Object.hash(id, version, repo, enabled, installedAt);

  @override
  String toString() => 'PluginInstall($id@$version, repo: $repo)';
}

extension PluginInstallX on PluginInstall {
  /// Where it came from, in one line, for a list to say so in.
  ///
  /// Here rather than in each page, because the settings list and the store row
  /// are answering the same question and reading a repository two different
  /// ways — one by address, one by name — reads as two different things.
  String get sourceLabel => switch (origin) {
    PluginOrigin.dev => l10n.pluginDev,
    PluginOrigin.file => l10n.pluginFromFile,
    PluginOrigin.repo => PluginRepoRecord.labelOfAddress(repo!),
  };
}
