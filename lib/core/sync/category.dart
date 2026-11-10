import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmStores;
import 'package:flutter/foundation.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/data/store/picked_files.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_skills.dart';
import 'package:server_box/data/store/sync_themes.dart';

/// What the person chose to sync beside the records every sync carries
/// (servers, keys, snippets, …), each its own switch on this device. One
/// mapping for both syncs: the operation log ([of]) and the whole backup
/// ([BackupV2]'s sections, `ofSection`).
enum SyncCategory {
  /// The app's settings and the themes they select.
  settings,

  /// The Agent's providers, tool switches, permissions and memory.
  ai,

  /// Saved sudo passwords, AI provider keys, MCP headers, and the WebDAV the
  /// backup syncs to.
  secrets,

  /// SSH key passphrases. Apart from [secrets]: a device that keeps none
  /// neither sends nor takes them.
  passphrases,

  /// Imported fonts, background images and the Agent's skills.
  files,

  /// Benchmark results.
  benchmarks;

  /// This device's switch; every one but [passphrases] is on until turned
  /// off.
  PrefPropDefault<bool> get pref => switch (this) {
    settings => PrefProps.syncAppSettings,
    ai => const PrefPropDefault('sync_ai', true, updateLastUpdateTsOnSetProp: false),
    secrets => const PrefPropDefault('sync_secrets', true, updateLastUpdateTsOnSetProp: false),
    passphrases => const PrefPropDefault('sync_passphrases', true, updateLastUpdateTsOnSetProp: false),
    files => const PrefPropDefault('sync_files', true, updateLastUpdateTsOnSetProp: false),
    benchmarks => const PrefPropDefault('sync_benchmarks', true, updateLastUpdateTsOnSetProp: false),
  };

  /// Its group, as the engines ask it: the one place what decides [on] is
  /// said.
  SyncGroup get group => _groups[this]!;

  static final _groups = {
    for (final cat in values)
      cat: SyncGroup(
        name: cat.name,
        pref: cat.pref,
        collections: {for (final MapEntry(:key, :value) in _byCollection.entries) if (value == cat) key},
        // Passphrases also need this device to keep them.
        also: [if (cat == passphrases) Stores.setting.rememberKeyPassphrase.listenable()],
        extra: cat == passphrases ? () => Stores.setting.rememberKeyPassphrase.fetch() : null,
      ),
  };

  /// Whether this device syncs it now.
  bool get on => group.on;

  /// The switches that decide [on], to listen to.
  Listenable get changes => group.changes;

  /// The category of a record of collection [c] (see `SyncRecorder`); null
  /// for one every sync carries.
  static SyncCategory? of(String c) => _byCollection[c];

  /// The categories as fl_lib's [SyncGroups], which the engines ask. Before
  /// any sync runs.
  static void define() => SyncGroups.define([for (final cat in values) cat.group]);

  static final _byCollection = <String, SyncCategory>{
    'kv:${Stores.setting.name}': settings,
    SyncThemes.c: settings,
    PickedFiles.c: files,
    SyncSkills.c: files,
    BenchmarkStore.c: benchmarks,
    for (final store in [LlmStores.llm, LlmStores.tool, LlmStores.memory]) 'kv:${store.name}': ai,
    for (final store in [LlmStores.credential, LlmStores.mcpSecret, Stores.sudoPassword, Stores.syncRemote])
      'kv:${store.name}': secrets,
    'kv:${Stores.keyPassphrase.name}': passphrases,
  };

  /// The categories this device syncs now.
  static Set<SyncCategory> get onNow => {
    for (final c in values)
      if (c.on) c,
  };

  /// Whether records of [c] are sent and taken now.
  static bool carries(String c) => of(c)?.on ?? true;
}
