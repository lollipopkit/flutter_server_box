import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart' show ThemeBlobStore;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/lkc_log_sync.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/utils.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/res/misc.dart';

/// Theme packages kept apart from the backup on LK Cloud: `blob-<name>.age`
/// each, sealed with the backup password as the backup is. The name is the
/// package keyed by the account's sync key and the password
/// (`fl_sync::blob_name`): equal packages are kept once, homebase never
/// learns which theme it holds, and a package sealed again with a new
/// password is a new blob. The backup's entry names it.
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

  /// Installation id to the blob it is kept as, from when names were random.
  /// TODO: rm with [forgetNames] once no install can still hold it.
  static const _names = PrefProp<String>('lkc_theme_blobs');

  LkcSync? _sync;

  /// The blobs on homebase and when each was written, read once per backup.
  Map<String, DateTime?>? _listed;

  /// The blobs the backup being written names.
  final _used = <String>{};

  Future<LkcSync> get _client async => _sync ??= await Lkc.client.sync(Lkc.app);

  /// Removes what names were kept by before they were derived.
  static Future<void> forgetNames() => _names.remove();

  /// Before a backup is written.
  void begin() {
    _listed = null;
    _used.clear();
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
    final client = await _client;
    final user = Lkc.client.user.value;
    if (user == null) throw StateError('signed out');
    final pwd = await _password();
    final key = await LkcSyncKey.load(client, user.id);
    final name = '$_prefix${key.nameOf([...utf8.encode(pwd), 0, ...bytes])}.age';
    _used.add(name);
    if (listed.containsKey(name)) return name;
    final sealed = await AgeCryptor.encrypt(bytes, pwd);
    final dir = await Directory.systemTemp.createTemp('sb-theme-blob-');
    try {
      final file = File('${dir.path}/$name');
      await file.writeAsString(sealed);
      await client.upload(name: name, from: file.path);
    } on LkcSyncError catch (e) {
      // Put there meanwhile by another device: the same package.
      if (e.kind != LkcSyncErrorKind.changed) rethrow;
    } finally {
      await dir.delete(recursive: true);
    }
    listed[name] = DateTime.now();
    return name;
  }

  @override
  Future<Uint8List> get(String id, String name) async {
    final dir = await Directory.systemTemp.createTemp('sb-theme-blob-');
    try {
      final path = '${dir.path}/$name';
      final fetched = await (await _client).download(name: name, to: path);
      if (fetched.missing) throw StateError('Theme package $name is gone');
      return await AgeCryptor.decrypt(
        await File(path).readAsBytes(),
        await _password(),
      );
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

/// While LK Cloud is the sync destination and the app is in the foreground
/// (on a desktop, running), listens for other devices' writes of the backup
/// and syncs on each, and on every (re)connection, which may have missed some.
final class LkcSyncWatch {
  LkcSyncWatch({
    required Listenable user,
    required bool Function() signedIn,
    required Future<LkcSync> Function() open,
    required Future<void> Function() forget,
    required ValueListenable<bool> toggle,
    required VoidCallback onRemoteChange,
    void Function(int? seq)? onLog,
    Duration retryAfter = const Duration(seconds: 30),
    bool inBackground = false,
  }) : _user = user,
       _signedIn = signedIn,
       _open = open,
       _forget = forget,
       _toggle = toggle,
       _onRemoteChange = onRemoteChange,
       _onLog = onLog,
       _retryAfter = retryAfter,
       _inBackground = inBackground;

  final Listenable _user;
  final bool Function() _signedIn;
  final Future<LkcSync> Function() _open;
  final Future<void> Function() _forget;
  final ValueListenable<bool> _toggle;
  final VoidCallback _onRemoteChange;

  /// The log reached a seq, or (null) listening began again and may have
  /// missed some.
  final void Function(int? seq)? _onLog;

  /// After listening could not start, or ended while still signed in; twice
  /// as long after each failure in a row, up to 32 times, until connected.
  final Duration _retryAfter;
  Timer? _retry;
  var _failures = 0;

  /// Listening whatever the window: a desktop app runs on behind other windows
  /// and in the tray, and should be up to date when it comes back. A phone's
  /// system ends the connection in the background anyway.
  final bool _inBackground;

  StreamSubscription<LkcSyncEvent>? _sub;
  LkcSync? _sync;
  var _starting = false;
  AppLifecycleListener? _lifecycle;

  static LkcSyncWatch? _shared;

  static void init() {
    if (!Lkc.enabled || _shared != null) return;
    _shared = LkcSyncWatch(
      user: Lkc.client.user,
      // The user too: signing out clears it before the session is, and nothing
      // says so after.
      signedIn: () => Lkc.client.signedIn && Lkc.client.user.value != null,
      open: () => Lkc.client.sync(Lkc.app),
      forget: Lkc.client.forget,
      toggle: BakSyncer.lkcSync.listenable(),
      // Not held back: another device's write is the whole reason to sync,
      // and a sync already running takes it on when it ends. Only while LK
      // Cloud is where the backup syncs: another remote ranks above it.
      onRemoteChange: () {
        if (bakSync.remoteStorage is LkcRemoteStorage) {
          bakSync.syncSoon(milliDelay: 0, throttleMilli: 0);
        }
      },
      onLog: (seq) => unawaited(seq == null ? LkcLogSync.sync() : LkcLogSync.pull(seq)),
      inBackground: isDesktop,
    )..start();
  }

  void start() {
    if (_lifecycle != null) return;
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _update());
    _user.addListener(_update);
    _toggle.addListener(_update);
    _update();
  }

  Future<void> dispose() async {
    _lifecycle?.dispose();
    _lifecycle = null;
    _user.removeListener(_update);
    _toggle.removeListener(_update);
    await _stop();
  }

  bool get _wanted {
    final state = WidgetsBinding.instance.lifecycleState;
    // Inactive too: a desktop window out of focus is still in front of the
    // user, and on a phone it is a moment's overlay.
    final foreground =
        _inBackground ||
        state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    return _lifecycle != null && foreground && _toggle.value && _signedIn();
  }

  Future<void> _stop() async {
    _retry?.cancel();
    _retry = null;
    final sub = _sub;
    _sub = null;
    _sync?.stopListening();
    await sub?.cancel();
  }

  Future<void> _update() async {
    if (!_wanted) return _stop();
    if (_sub != null || _starting) return;
    _starting = true;
    try {
      final sync = _sync ??= await _open();
      // Changed meanwhile: the next change of state starts it.
      if (!_wanted) return;
      late final StreamSubscription<LkcSyncEvent> sub;
      sub = _sub = sync.listen().listen(
        _onEvent,
        onError: (Object e, StackTrace s) =>
            Loggers.app.warning('LK Cloud sync events', e, s),
        onDone: () {
          if (!identical(_sub, sub)) return;
          _sub = null;
          // Ended by homebase refusing the session: signed out here too,
          // which a later sign-in starts listening from.
          if (!_signedIn()) {
            unawaited(
              _forget().catchError(
                (Object e, StackTrace s) =>
                    Loggers.app.warning('LK Cloud sign-out', e, s),
              ),
            );
            return;
          }
          _retryLater();
        },
      );
    } catch (e, s) {
      Loggers.app.warning('LK Cloud sync events', e, s);
      _retryLater();
    } finally {
      _starting = false;
    }
  }

  void _retryLater() {
    _retry?.cancel();
    final wait = _retryAfter * (1 << min(_failures, 5));
    _failures++;
    _retry = Timer(wait, () {
      _retry = null;
      unawaited(_update());
    });
  }

  void _onEvent(LkcSyncEvent event) {
    if (event.lost case final why?) {
      Loggers.app.info('LK Cloud sync events: $why');
      return;
    }
    if (event.connected) _failures = 0;
    if (event.connected || event.name == Miscs.bakFileName) _onRemoteChange();
    if (event.connected) _onLog?.call(null);
    if (event.logSeq case final seq?) _onLog?.call(seq);
  }
}
