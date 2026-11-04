part of 'log.dart';

/// A folder only this app writes to, on WebDAV or iCloud: where
/// [SegmentSync] keeps its files. Its [putBlob] writes over one there.
abstract interface class SyncFiles implements SyncBlobStore {
  /// [body] as [name], in place of one there.
  Future<void> write(String name, Uint8List body);
}

/// The operation-log sync where nothing orders writes (WebDAV, iCloud): each
/// device writes only its own files, so no write races another device's.
///
/// - `seg-<device>-<n>.age`: a batch of ops, n from 1 up, never written
///   again.
/// - `snap-<device>.age`: the device's state, and how far it had read each
///   device's segments (`covers`).
/// - `op-<device>-<name>.age`: the record of a large op the device stamped.
///
/// A device reads each other device's segments after the last it read; one
/// gone (removed once covered) or not here yet while later ones are is read
/// from a snapshot covering it. It removes its own segments once every
/// snapshot covers them, or once one does and they are [_segmentMax] old.
final class SegmentSync extends SyncEngine {
  SegmentSync(this._files, SyncSeal seal, {super.write, super.carries, super.stamp}) : super(_files, seal, _at);

  final SyncFiles _files;

  /// The snapshots read to close a gap, and when each was written: one not
  /// written again since is not read again while the gap stays.
  final _snapshotsRead = <String, DateTime?>{};

  static const _at = 'seg.';

  /// Segments read or written after which this device writes its snapshot
  /// again; and how many of its own it keeps before looking which to remove.
  static const compactEvery = 32;

  /// How long a segment no key here opens stops the read of its device: one
  /// sealed to another device's key, made at the same time as this one's
  /// before either reached the other, opens once the keys are merged
  /// ([SyncSeal.refresh]). Past it, the segment is passed over.
  static const _unreadableMax = Duration(days: 7);

  /// Past this, a segment one snapshot covers is removed though another does
  /// not: a device gone for good holds none back for ever.
  static const _segmentMax = Duration(days: 30);

  /// How often this device's segments are looked at for removal: each look
  /// reads the other devices' snapshots.
  static const _collectEvery = Duration(hours: 6);

  static const _storeKey = 'store';
  static const _cursorKey = 'cur.';
  static const _nKey = 'n';
  static const _sentKey = 'sent';
  static const _joinedKey = 'joined';
  static const _sinceKey = 'since';
  static const _snappedKey = 'snapped';
  static const _collectedKey = 'collected';

  static final _segment = RegExp(r'^seg-([0-9a-f]{16})-(\d+)\.age$');
  static final _snapshot = RegExp(r'^snap-([0-9a-f]{16})\.age$');

  static String _segmentName(String device, int n) => 'seg-$device-$n.age';
  static String _snapshotName(String device) => 'snap-$device.age';

  String get _mine => SyncRecorder.deviceHexOf(SyncRecorder.device);

  /// Named by the stamp, its device first: only that device removes it, and
  /// it has seen the op ([_sweepBlobs]). Not by the key, which a merge with
  /// another device's changes ([SyncSeal.refresh]): a segment written before
  /// still names it. The stamp says no more than the segment's own name.
  @override
  String _blobName(String h) => '${SyncEngine._blobPrefix}${h.substring(16)}-${h.substring(0, 16)}.age';

  @override
  String get _sweepPrefix => '${SyncEngine._blobPrefix}$_mine-';

  int _int(String k) => int.tryParse(_get(k) ?? '') ?? 0;

  int _cursor(String device) => _int('$_cursorKey$device');

  /// Reads what other devices wrote, then writes what this one has: written
  /// even when a device's segments cannot be read on (a newer build's).
  Future<void> sync() => _serial(() async {
    _refreshed = false;
    final listed = _Listing.of(await _files.blobs(''));
    Object? unread;
    StackTrace? trace;
    try {
      await _pull(listed);
    } catch (e, s) {
      unread = e;
      trace = s;
    }
    await _push(listed);
    if (unread != null) Error.throwWithStackTrace(unread, trace!);
    if (_int(_sinceKey) >= compactEvery) await _writeSnapshot();
    await _collect(listed);
  });

  /// [forget], after the run going on.
  Future<void> reset() => _serial(() async => forget());

  Future<void> _pull(_Listing listed) async {
    final mine = _mine;
    final read = {
      for (final MapEntry(key: d, value: at) in listed.snapshots.entries)
        if (_snapshotsRead.containsKey(d) && _snapshotsRead[d] == at) d,
    };
    while (true) {
      final gaps = [
        for (final MapEntry(key: device, value: ns) in listed.segments.entries)
          if (device != mine && _gap(ns.keys, _cursor(device))) device,
      ];
      if (gaps.isEmpty) break;
      // The device's own covers what it wrote; another's may cover it too.
      final next =
          gaps.where((d) => listed.snapshots.containsKey(d) && !read.contains(d)).firstOrNull ??
          listed.snapshots.keys.where((d) => d != mine && !read.contains(d)).firstOrNull;
      if (next == null) break;
      read.add(next);
      await _readSnapshot(next);
      _snapshotsRead[next] = listed.snapshots[next];
    }
    for (final MapEntry(key: device, value: ns) in listed.segments.entries) {
      if (device == mine) continue;
      for (var n = _cursor(device) + 1; ns.containsKey(n); n++) {
        if (!await _readSegment(device, n, ns[n])) break;
      }
    }
  }

  /// The segment after [cursor] is not there, and a later one is.
  static bool _gap(Iterable<int> ns, int cursor) => !ns.contains(cursor + 1) && ns.any((n) => n > cursor + 1);

  Future<void> _readSnapshot(String device) async {
    final name = _snapshotName(device);
    final sealed = await _files.getBlob(name);
    if (sealed == null) return;
    final Uint8List plain;
    try {
      plain = await _open(sealed);
    } on Object catch (e) {
      // Read again next time, while the gap it would close is there.
      Loggers.app.warning('Sync could not open $name', e);
      return;
    }
    final parsed = SyncEngine._parse(plain, name);
    if (parsed == null) return;
    final mine = _mine;
    await _apply(parsed.ops, {
      for (final MapEntry(key: d, value: n) in _coversOf(parsed.json).entries)
        if (d != mine && n > _cursor(d)) '$_cursorKey$d': '$n',
    });
  }

  /// Whether the read goes on past segment [n] of [device], written [at].
  Future<bool> _readSegment(String device, int n, DateTime? at) async {
    final name = _segmentName(device, n);
    final sealed = await _files.getBlob(name);
    // Removed meanwhile: the next sync reads a snapshot covering it.
    if (sealed == null) return false;
    List<SyncOp>? ops;
    try {
      ops = SyncEngine._parse(await _open(sealed), name)?.ops;
    } on FormatException catch (e) {
      // Sealed to no key here; anything else (the network, the password)
      // stops the read, to be tried again.
      if (at == null || DateTime.now().difference(at) < _unreadableMax) {
        Loggers.app.warning('Sync waits for a key that opens $name', e);
        return false;
      }
      Loggers.app.warning('Sync skipped unreadable $name', e);
    }
    await _apply(ops, {'$_cursorKey$device': '$n', _sinceKey: '${_int(_sinceKey) + 1}'});
    return true;
  }

  static Map<String, int> _coversOf(Map<String, dynamic> json) {
    final covers = json['covers'];
    if (covers is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in covers.entries)
        if (key is String && value is int) key: value,
    };
  }

  Future<void> _push(_Listing listed) async {
    final store = _get(_storeKey);
    // Joining a store (the first time, or another one): every record goes,
    // whoever stamped it, so what this device holds reaches the others.
    final joining = _get(_joinedKey) != store;
    _stamp();
    final all = joining ? SyncRecorder.all() : SyncRecorder.pending(_get(_sentKey) ?? '');
    final (:ops, :complete) = await _opsOf([for (final r in all) if (_carries(r.c)) r]);
    // A record that could not be read stops the send just before it, so it
    // and what follows are read again next time.
    final stamped = complete ? all : [for (final r in all) if (r.hlc.compareTo(ops.lastOrNull?.h ?? '') <= 0) r];
    final mine = _mine;
    var last = _get(_sentKey) ?? '';
    var n = [_int(_nKey), ...?listed.segments[mine]?.keys].reduce(max);
    for (final chunk in await _batches(ops)) {
      for (final op in chunk.ops) {
        if (op.h.substring(16) == mine && op.h.compareTo(last) > 0) last = op.h;
      }
      // Kept once written: a write that failed is listed next time if it
      // landed (this device's own files list as written), and its number is
      // passed; else written again under it, leaving no gap.
      await _files.write(_segmentName(mine, ++n), chunk.body);
      _put({_nKey: '$n', _sentKey: last, _sinceKey: '${_int(_sinceKey) + 1}'});
    }
    // Past what was left out too, so it is not looked at again.
    final newest = stamped
        .map((r) => r.hlc)
        .where((h) => h.substring(16) == mine)
        .fold(last, (a, h) => h.compareTo(a) > 0 ? h : a);
    if (newest != last) _put({_sentKey: newest});
    if (joining && complete) _put({_joinedKey: store});
  }

  /// Writes this device's snapshot: what it holds, and how far it read.
  Future<void> _writeSnapshot() async {
    if (_get(SyncEngine._partialKey) != null) {
      Loggers.app.info('Sync snapshot left to a device holding every record');
      return;
    }
    _stamp();
    final (:ops, :complete) = await _opsOf([for (final r in SyncRecorder.all()) if (_carries(r.c)) r]);
    if (!complete) {
      Loggers.app.info('Sync snapshot left: a record could not be read');
      return;
    }
    final mine = _mine;
    final covers = {
      for (final row in SqliteDb.instance.select('SELECT k, v FROM sync_state WHERE k LIKE ?;', ['$_at$_cursorKey%']))
        (row['k'] as String).substring('$_at$_cursorKey'.length): int.parse(row['v'] as String),
      mine: _int(_nKey),
    };
    await _files.write(_snapshotName(mine), await _seal.seal(SyncEngine._encode(ops, {'covers': covers})));
    _put({_sinceKey: null, _snappedKey: '${covers[mine]}'});
    await _sweepBlobs({for (final op in ops) ?SyncEngine._blobOf(op.d)});
  }

  /// Removes this device's segments the snapshots cover, all but the last
  /// (what tells a device that read up to it that nothing is missing).
  /// Best effort.
  Future<void> _collect(_Listing listed) async {
    final mine = _mine;
    final own = listed.segments[mine];
    if (own == null || own.length < compactEvery) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _int(_collectedKey) < _collectEvery.inMilliseconds) return;
    _put({_collectedKey: '$now'});
    try {
      final snapped = int.tryParse(_get(_snappedKey) ?? '');
      final covered = [
        ?snapped,
        for (final device in listed.snapshots.keys)
          if (device != mine || snapped == null) await _coverOf(device, mine),
      ];
      if (covered.isEmpty) return;
      final all = covered.reduce(min);
      final any = covered.reduce(max);
      final last = own.keys.reduce(max);
      final old = DateTime.now().subtract(_segmentMax);
      for (final MapEntry(key: n, value: at) in own.entries) {
        if (n >= last || n > any) continue;
        if (n <= all || (at != null && at.isBefore(old))) await _files.deleteBlob(_segmentName(mine, n));
      }
    } catch (e, s) {
      Loggers.app.warning('Sync segments removal', e, s);
    }
  }

  /// How far [device]'s snapshot covers [of]'s segments; 0 when it cannot be
  /// read.
  Future<int> _coverOf(String device, String of) async {
    final name = _snapshotName(device);
    try {
      final sealed = await _files.getBlob(name);
      if (sealed == null) return 0;
      final parsed = SyncEngine._parse(await _open(sealed), name);
      return parsed == null ? 0 : _coversOf(parsed.json)[of] ?? 0;
    } on Object catch (e) {
      Loggers.app.warning('Sync could not read $name', e);
      return 0;
    }
  }

  /// Forgets what was read and sent: the next sync reads every device anew
  /// and joins again. For another store, or what is carried changing.
  static void forget() =>
      SqliteDb.instance.execute('DELETE FROM sync_state WHERE k LIKE ? AND k != ?;', ['$_at%', '$_at$_storeKey']);

  /// The files of [store] from now on: another store's are forgotten.
  static void bind(String store) {
    if (SyncEngine._stateAt(_at, _storeKey) == store) return;
    forget();
    SyncEngine._setStateAt(_at, {_storeKey: store});
  }
}

/// A [SegmentSync] folder's files, by kind.
final class _Listing {
  _Listing.of(List<({String name, DateTime? at})> files) {
    for (final f in files) {
      if (SegmentSync._segment.firstMatch(f.name) case final m?) {
        (segments[m[1]!] ??= {})[int.parse(m[2]!)] = f.at;
      } else if (SegmentSync._snapshot.firstMatch(f.name) case final m?) {
        snapshots[m[1]!] = f.at;
      }
    }
  }

  /// Each device's segments, by number, and when each was written.
  final segments = <String, Map<int, DateTime?>>{};
  final snapshots = <String, DateTime?>{};
}
