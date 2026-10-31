import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart' show ThemeBlobStore;
import 'package:flutter/widgets.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/utils.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/res/misc.dart';

/// Theme packages kept apart from the backup on LK Cloud: `blob-<random>.age`
/// each, sealed with the backup password as the backup is. The name is
/// random so homebase never learns which theme it holds; the backup's entry
/// names it.
final class LkcThemeBlobs implements ThemeBlobStore {
  LkcThemeBlobs._();

  static final shared = LkcThemeBlobs._();

  /// Where a restore can fetch a kept package from: signed in, whatever the
  /// backup came from.
  static ThemeBlobStore? get available =>
      Lkc.enabled && Lkc.client.signedIn ? shared : null;

  static const _prefix = 'blob-';

  /// A blob no backup names is removed this long after it was written: a
  /// device may have just put one there for a write of the backup still to
  /// come.
  static const _grace = Duration(days: 1);

  /// Installation id to the blob it is kept as, as this device last wrote or
  /// read it. Device-local.
  static const _names = PrefProp<String>('lkc_theme_blobs');

  LkcSync? _sync;

  /// The blobs on homebase and when each was written, read once per backup.
  Map<String, DateTime?>? _listed;

  /// The blobs the backup being written names.
  final _used = <String>{};

  Future<LkcSync> get _client async => _sync ??= await Lkc.client.sync(Lkc.app);

  /// Blobs are sealed with the backup password: after it changes, none
  /// written before is reused.
  static Future<void> forgetNames() => _names.remove();

  /// Before a backup is written.
  void begin() {
    _listed = null;
    _used.clear();
  }

  Map<String, String> _read() {
    try {
      final raw = jsonDecode(_names.get() ?? '{}');
      if (raw is Map) return raw.cast<String, String>();
    } catch (_) {}
    return {};
  }

  Future<void> _remember(String id, String name) async {
    final names = _read()..[id] = name;
    await _names.set(jsonEncode(names));
  }

  Future<Map<String, DateTime?>> _list() async {
    final files = await (await _client).list();
    return {
      for (final f in files)
        if (f.name.startsWith(_prefix)) f.name: DateTime.tryParse(f.updatedAt),
    };
  }

  static Future<String> _password() async {
    final pwd = await SecureStoreProps.bakPwd.read();
    if (pwd == null || pwd.isEmpty) throw const RemoteBackupPasswordMissing();
    return pwd;
  }

  @override
  Future<String> put(String id, Uint8List bytes) async {
    final listed = _listed ??= await _list();
    final known = _read()[id];
    if (known != null && listed.containsKey(known)) {
      _used.add(known);
      return known;
    }
    final sealed = await AgeCryptor.encrypt(bytes, await _password());
    final rand = Random.secure();
    final name =
        '$_prefix${List.generate(16, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}.age';
    final dir = await Directory.systemTemp.createTemp('sb-theme-blob-');
    try {
      final file = File('${dir.path}/$name');
      await file.writeAsString(sealed);
      await (await _client).upload(name: name, from: file.path);
    } finally {
      await dir.delete(recursive: true);
    }
    listed[name] = DateTime.now();
    _used.add(name);
    await _remember(id, name);
    return name;
  }

  @override
  Future<Uint8List> get(String id, String name) async {
    final dir = await Directory.systemTemp.createTemp('sb-theme-blob-');
    try {
      final path = '${dir.path}/$name';
      final fetched = await (await _client).download(name: name, to: path);
      if (fetched.missing) throw StateError('Theme package $name is gone');
      final bytes = await AgeCryptor.decrypt(
        await File(path).readAsBytes(),
        await _password(),
      );
      await _remember(id, name);
      return bytes;
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// Once the backup naming [_used] is written: the blobs no backup names
  /// any more, past [_grace]. Best effort, the next backup tries again.
  Future<void> sweep() async {
    try {
      final sync = await _client;
      // What [put] listed is enough: a blob written since is within [_grace].
      final listed = _listed ?? await _list();
      final before = DateTime.now().subtract(_grace);
      final unused = [
        for (final MapEntry(key: name, value: at) in listed.entries)
          if (!_used.contains(name) && at != null && at.isBefore(before)) name,
      ];
      if (unused.isEmpty) return;
      // The versions LK Cloud keeps of the backup can be restored too.
      final kept = await _keptByVersions(sync);
      for (final name in unused) {
        if (!kept.contains(name)) await sync.delete(name: name);
      }
    } catch (e, s) {
      Loggers.app.warning('LK Cloud theme blobs sweep', e, s);
    }
  }

  /// The blobs the kept versions of the backup name. Throws when one cannot
  /// be read, so nothing is removed that one of them might name.
  Future<Set<String>> _keptByVersions(LkcSync sync) async {
    final names = <String>{};
    final pwd = await _password();
    final dir = await Directory.systemTemp.createTemp('sb-theme-blob-');
    try {
      final path = '${dir.path}/version';
      for (final v in await sync.versions(name: Miscs.bakFileName)) {
        final fetched = await sync.downloadVersion(
          name: Miscs.bakFileName,
          etag: v.etag,
          to: path,
        );
        // Gone since it was listed: nothing to restore from it.
        if (fetched.missing) continue;
        final plain = await BackupV2.unlock(await File(path).readAsBytes(), pwd);
        final (backup, _) = MergeableUtils.fromBytes(plain);
        if (backup is! BackupV2) continue;
        for (final entry in backup.themes.values) {
          if (entry case {'blob': final String name}) names.add(name);
        }
      }
    } finally {
      await dir.delete(recursive: true);
    }
    return names;
  }

}

/// While LK Cloud is the sync destination and the app is in the foreground,
/// listens for other devices' writes of the backup and syncs on each, and on
/// every (re)connection, which may have missed some.
abstract final class LkcSyncWatch {
  static StreamSubscription<LkcSyncEvent>? _sub;
  static LkcSync? _sync;
  static var _starting = false;
  static AppLifecycleListener? _lifecycle;
  static final _switch = BakSyncer.lkcSync.listenable();

  static void init() {
    if (!Lkc.enabled || _lifecycle != null) return;
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _update());
    Lkc.client.user.addListener(_update);
    _switch.addListener(_update);
    _update();
  }

  static bool get _wanted {
    final state = WidgetsBinding.instance.lifecycleState;
    final foreground = state == null || state == AppLifecycleState.resumed;
    return foreground && BakSyncer.lkcSync.get() && Lkc.client.signedIn;
  }

  static Future<void> _update() async {
    if (!_wanted) {
      final sub = _sub;
      _sub = null;
      _sync?.stopListening();
      await sub?.cancel();
      return;
    }
    if (_sub != null || _starting) return;
    _starting = true;
    try {
      final sync = _sync ??= await Lkc.client.sync(Lkc.app);
      // Changed meanwhile: the next change of state starts it.
      if (!_wanted) return;
      late final StreamSubscription<LkcSyncEvent> sub;
      sub = _sub = sync.listen().listen(
        _onEvent,
        onError: (Object e, StackTrace s) =>
            Loggers.app.warning('LK Cloud sync events', e, s),
        // Ended by homebase refusing the session: signed out here too, which
        // a later sign-in starts listening from.
        onDone: () {
          if (identical(_sub, sub)) _sub = null;
          if (!Lkc.client.signedIn) unawaited(Lkc.client.forget());
        },
      );
    } catch (e, s) {
      Loggers.app.warning('LK Cloud sync events', e, s);
    } finally {
      _starting = false;
    }
  }

  static void _onEvent(LkcSyncEvent event) {
    if (event.lost case final why?) {
      Loggers.app.info('LK Cloud sync events: $why');
      return;
    }
    if (event.connected || event.name == Miscs.bakFileName) {
      bakSync.syncSoon(milliDelay: 0);
    }
  }
}
