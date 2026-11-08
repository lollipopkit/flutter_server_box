import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/data/res/terminal.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';

/// A file the person picked, and the setting that points at it.
final class _Role {
  const _Role(this.path, this.dir, this.prefix, {this.applied});

  /// The device-local path key: each device keeps its own copy.
  final SqlitePropDefault<String> Function() path;
  final String Function() dir;

  /// What a copy written here is named after, as the page that picks it
  /// names its own; null keeps the file's name (a terminal font's family).
  final String? prefix;

  /// After a copy came in, or the file went.
  final Future<void> Function(String path)? applied;
}

/// The files the settings point at, synced as records of their own (`file`,
/// by role): fonts and background images. A send stamps a role whose file
/// changed here ([stamp]); one that came in is written beside the others and
/// pointed at ([install]).
abstract final class PickedFiles {
  static const c = 'file';

  static final _roles = <String, _Role>{
    'terminalFont': _Role(
      () => Stores.setting.fontPath,
      () => Paths.font,
      null,
      applied: TerminalFont.load,
    ),
    'terminalBackground': _Role(() => Stores.setting.sshBgImage, () => Paths.img, 'ssh_bg_'),
    'appBackground': _Role(
      () => ThemeHost.settings.appCustomBackgroundPath,
      () => Paths.img,
      'app_bg_',
      applied: _reselectBackground,
    ),
    'appFont': _Role(
      () => ThemeHost.settings.appImportedFontPath,
      () => Paths.font,
      'app_ui_',
      applied: (_) => AppFont.loadStored(),
    ),
  };

  /// `path|size|ms`; null for a file that is not there.
  static String? _fingerprint(String path) {
    if (path.isEmpty) return null;
    final stat = File(path).statSync();
    if (stat.type != FileSystemEntityType.file) return null;
    return '$path|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
  }

  /// Stamps each role whose file changed here since it was last seen. One
  /// is gone only once its setting is cleared: a file missing under a path
  /// still set says nothing to the others.
  static void stamp() {
    final now = <String, String>{};
    final unknown = <String>{};
    for (final MapEntry(key: role, value: r) in _roles.entries) {
      final path = r.path().fetch();
      if (path.isEmpty) continue;
      if (_fingerprint(path) case final fingerprint?) {
        now[role] = fingerprint;
      } else {
        unknown.add(role);
      }
    }
    SyncRecorder.stampChanged(c, now, unknown: unknown);
  }

  /// [role]'s file as an op carries it, null when none is picked.
  static Future<Object?> read(String role) async {
    final r = _roles[role];
    if (r == null) return null;
    final path = r.path().fetch();
    final file = File(path);
    if (path.isEmpty || !await file.exists()) return null;
    return {'name': path.getFileName(), 'data': base64Encode(await file.readAsBytes())};
  }

  /// Writes the files [ops] carry and points the settings at them; a null
  /// op removes the role's file. Each recorded at its op's stamp.
  static Future<void> install(List<({String c, String id, String h, Object? d})> ops) async {
    for (final op in ops) {
      final r = _roles[op.id];
      if (r == null) continue;
      try {
        final prop = r.path();
        final old = prop.fetch();
        var path = '';
        if (op.d case {'name': final String name, 'data': final String data}) {
          final ext = _ext.firstMatch(name)?.group(0) ?? '';
          final fileName = switch (r.prefix) {
            final prefix? => '$prefix${DateTime.now().microsecondsSinceEpoch}$ext',
            null when _plainName.hasMatch(name) => name,
            null => 'font$ext',
          };
          path = r.dir().joinPath(fileName);
          await Directory(r.dir()).create(recursive: true);
          await File('$path.part').writeAsBytes(base64Decode(data), flush: true);
          await File('$path.part').rename(path);
        }
        prop.store.set(prop.key, path, updateLastUpdateTsOnSet: false);
        SyncRecorder.see(c, op.id, _fingerprint(path));
        SyncRecorder.receiving(op.h, () => SyncRecorder.record(c, op.id));
        if (old.isNotEmpty && old != path && File(old).parent.path == r.dir()) {
          await File(old).delete().catchError((Object _) => File(old));
        }
        await r.applied?.call(path);
      } catch (e, s) {
        Loggers.app.warning('Sync skipped file ${op.id}', e, s);
      }
    }
    if (ops.isNotEmpty) await RNodes.app.notify();
  }

  /// What a name another device sent may give a file here: nothing that
  /// leaves the directory.
  static final _ext = RegExp(r'\.[A-Za-z0-9]{1,8}$');
  static final _plainName = RegExp(r'^[^/\\\x00.][^/\\\x00]{0,127}$');

  /// The custom theme draws the custom background: pointed at the new copy
  /// while it is the one selected.
  static Future<void> _reselectBackground(String path) async {
    final settings = ThemeHost.settings;
    if (settings.appThemePreset.fetch() != ThemePackages.customPreset) return;
    settings.set(settings.appBackgroundPath.key, path, updateLastUpdateTsOnSet: false);
  }

  @visibleForTesting
  static Iterable<String> get roles => _roles.keys;
}
