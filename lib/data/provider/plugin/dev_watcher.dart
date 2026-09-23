/// Reloading a plugin the moment its files change. PLUGINS.md 8.2.
///
/// **The development loop is the whole point of a development directory.** A
/// plugin loaded from one is re-read on every refresh — but nothing refreshed,
/// so the loop was: edit, build, quit the app, start it again, navigate back to
/// the page. This watches those directories and refreshes when one moves, so it
/// is: edit, build, look.
///
/// It is Flutter's hot *restart* rather than hot reload, and honestly so: the
/// plugin's state lives in its QuickJS instance, and there is nothing to carry
/// across a new script. `PluginSurfaceView` already swaps its instance when the
/// source it was given changes, so the surfaces follow from the refresh.
///
/// Polled rather than watched. `Directory.watch` reports differently on each
/// platform and misses an atomic replace on some of them — which is exactly how
/// a bundler writes its output — and the cost here is a `stat` per file per
/// second, on a machine where somebody is editing a plugin.
library;

import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/data/res/store.dart';

class PluginDevWatcher {
  PluginDevWatcher({required this.installer});

  final PluginInstaller installer;

  Timer? _timer;

  /// What each watched file looked like when it was last read.
  final _seen = <String, DateTime>{};

  /// A second, which is below what anybody notices and above what a rebuild
  /// takes to finish writing.
  static const interval = Duration(seconds: 1);

  /// The files a change to which is worth re-reading a plugin for.
  ///
  /// The script and the manifest, and the translations because a new key is
  /// exactly the kind of edit somebody makes and then wonders why the row still
  /// says `l10n.something`.
  static List<File> filesOf(String dir) => [
    File(dir.joinPath(PluginPackage.sourceName)),
    File(dir.joinPath(PluginPackage.manifestName)),
    ...(Directory(dir.joinPath('l10n')).existsSync()
        ? Directory(dir.joinPath('l10n'))
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
        : const <File>[]),
  ];

  /// Starts watching, if there is anything to watch.
  ///
  /// Desktop only, because a development directory is: a phone has no place a
  /// developer edits files in. Idempotent, so a caller that is not sure whether
  /// it has already started may call it again — which is what an install does.
  void start() {
    if (!isDesktop || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _seen.clear();
  }

  /// Re-reads every development plugin if any of their files has moved.
  ///
  /// One refresh for the whole tick rather than one per plugin: a rebuild
  /// writes several files, and a refresh per file would reload the same plugin
  /// three times while it is half-written.
  Future<void> _tick() async {
    final dirs = Stores.setting.pluginDevDirs.fetch();
    if (dirs.isEmpty) {
      // Nothing to watch. Kept running rather than stopped: a directory added
      // while the app is up is the case this exists for.
      _seen.clear();
      return;
    }

    var moved = false;
    final live = <String>{};
    for (final dir in dirs) {
      for (final file in filesOf(dir)) {
        live.add(file.path);
        final at = _mtimeOf(file);
        // A file that is being written is not a change yet — its mtime moves
        // again the moment it is closed, so the next tick catches it.
        if (_seen[file.path] != at) {
          // The first tick learns what is there; only a *later* change is one.
          if (_seen.containsKey(file.path)) moved = true;
          if (at == null) {
            _seen.remove(file.path);
          } else {
            _seen[file.path] = at;
          }
        }
      }
    }
    // A file that has gone — a locale deleted, a build cleaned — is a change
    // too, and forgetting it is what would make it look like one for ever.
    _seen.removeWhere((path, _) => !live.contains(path));

    if (!moved) return;
    try {
      await installer.refresh();
      Loggers.app.info('Plugin development directory changed; reloaded');
    } catch (e, s) {
      // A half-written bundle is a plugin that will not parse, and the next
      // tick reads the finished one. Never fatal: this is a convenience for
      // somebody who is editing.
      Loggers.app.warning('Reloading a development plugin', e, s);
    }
  }

  static DateTime? _mtimeOf(File file) {
    try {
      return file.existsSync() ? file.lastModifiedSync() : null;
    } catch (_) {
      // Being replaced as it was read. The next tick sees the new one.
      return null;
    }
  }
}
