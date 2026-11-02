import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart'
    show ThemeBackup, ThemeBlobStore, ThemeHost, ThemeIconPacks, ThemePackages;
import 'package:flutter/foundation.dart';
import 'package:server_box/data/store/sync_recorder.dart';

/// Installed theme packages and icon packs as sync records (#1842):
/// `theme/<installation id>`, the op holding what [ThemeBackup] describes an
/// installation by (`bundled`, `store`) or, for one imported by hand, the
/// package itself (`pkg`, base64; past the log's inline size it goes as a
/// blob the op names).
///
/// Installations are files, not rows: what is installed and not yet stamped
/// is stamped before each send ([stamp]). Added only: a theme removed here
/// stays on the other devices, as the backup never removed one either.
abstract final class SyncThemes {
  static const c = 'theme';

  /// Where themes are installed, for a test's device: the app's own root
  /// when null.
  @visibleForTesting
  static String? root;

  static const _pkg = 'pkg';

  /// The name [_Carried] answers for a package it holds.
  static const _carried = 'op';

  /// Stamps each installation no record names yet: a theme installed here
  /// since the last send.
  static void stamp() {
    final ids = _installed();
    if (ids.isEmpty) return;
    final known = SyncRecorder.stampsOf([for (final id in ids) (c, id)]);
    for (final id in ids) {
      // Read in the send this runs before: no second send for it.
      if (!known.containsKey((c, id))) SyncRecorder.record(c, id, notify: false);
    }
  }

  /// Each installation's op value, read once per send or snapshot (only one
  /// that carries a theme record). Empty, logged, when the themes cannot be
  /// read: the rest of the send goes on without them.
  static Future<Map<String, Object?>> read() async {
    final carried = _Carried();
    try {
      final export = await ThemeBackup.export(rootDirectory: root, blobs: carried);
      return {
        for (final MapEntry(key: id, value: entry) in export.entries.entries)
          if (entry is Map<String, Object?>)
            id: switch (carried.bytes[id]) {
              final bytes? when entry['blob'] == _carried => {...entry..remove('blob'), _pkg: base64Encode(bytes)},
              _ => entry,
            },
      };
    } catch (e, s) {
      Loggers.app.warning('Sync read the themes', e, s);
      return const {};
    }
  }

  /// Installs the themes [ops] describe, each recorded at its op's stamp. A
  /// theme already here under the same manifest id at another version is
  /// kept, and the op's installation is held as it ([_aliasOf]). A theme that
  /// cannot be installed is logged and left.
  static Future<void> install(List<({String c, String id, String h, Object? d})> ops) async {
    for (final op in ops) {
      final d = op.d;
      // Added only: a removal elsewhere removes nothing here.
      if (d is! Map) continue;
      try {
        final entry = Map<String, Object?>.from(d);
        final carried = _Carried();
        if (entry.remove(_pkg) case final String pkg) {
          carried.bytes[op.id] = base64Decode(pkg);
          entry['blob'] = _carried;
        }
        final report = await ThemeBackup.restore({op.id: entry}, rootDirectory: root, blobs: carried);
        final local = report.installedAs[op.id];
        if (local == null) continue;
        if (local != op.id) _alias(op.id, local);
        SyncRecorder.receiving(op.h, () => SyncRecorder.record(c, op.id));
      } catch (e, s) {
        Loggers.app.warning('Sync skipped theme ${op.id}', e, s);
      }
    }
  }

  /// Points this device's own selection keys (`appThemePackage`,
  /// `appBackgroundPath`) at its copy of the theme the synced preset names,
  /// once that is installed here: what `ThemeBackup.reselect` does after a
  /// restore. Never falls back to the default while the theme is still on its
  /// way, as `ThemePackages.reconcileSelection` would: the fallback would be
  /// sent as an edit, over the other devices' choice.
  static void reselect() {
    final settings = ThemeHost.settings;
    final preset = settings.appThemePreset.fetch();
    if (ThemePackages.installationIdOf(preset) case final named?) {
      final id = _aliasOf(named) ?? named;
      final theme = ThemePackages.installed(id, variant: ThemePackages.variantOf(preset), rootDirectory: root);
      if (theme != null) {
        if (settings.appThemePackage.fetch() != id) settings.appThemePackage.put(id);
        final background = theme.backgroundPath ?? '';
        if (settings.appBackgroundPath.fetch() != background) settings.appBackgroundPath.put(background);
      }
    }
    // The icon pack is chosen by the synced key itself: one held here under
    // another installation is written there unstamped, so it is this
    // device's own and not sent over the others' choice.
    final pack = settings.appIconPack.fetch();
    if (_aliasOf(pack) case final local?) {
      settings.appIconPack.store.set(settings.appIconPack.key, local, updateLastUpdateTsOnSet: false);
    }
  }

  /// The installation this device holds another device's [id] as: the same
  /// theme at another version, kept when [install] met it.
  static String? _aliasOf(String id) =>
      SqliteDb.instance.select('SELECT v FROM sync_state WHERE k = ?;', ['alias:$c:$id']).firstOrNull?['v'] as String?;

  static void _alias(String id, String local) => SqliteDb.instance.execute(
    'INSERT INTO sync_state (k, v) VALUES (?, ?) ON CONFLICT (k) DO UPDATE SET v = excluded.v;',
    ['alias:$c:$id', local],
  );

  static List<String> _installed() => [
    for (final t in ThemePackages.listInstalled(rootDirectory: root)) t.installationId,
    for (final t in ThemeIconPacks.listInstalled(rootDirectory: root == null ? null : ThemeIconPacks.rootIn(root!))) t.installationId,
  ];
}

/// Holds packages in memory: what [ThemeBackup] would keep apart is carried
/// in the op instead.
final class _Carried implements ThemeBlobStore {
  final bytes = <String, Uint8List>{};

  @override
  Future<String> put(String id, Uint8List bytes) async {
    this.bytes[id] = bytes;
    return SyncThemes._carried;
  }

  @override
  Future<Uint8List> get(String id, String name) async =>
      bytes[id] ?? (throw StateError('Theme package $id was not carried'));
}
