import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/ssh/key_passphrase.dart';
import 'package:server_box/core/sync/category.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/data/store/store_reload.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:server_box/data/store/sync_records.dart';
import 'package:server_box/data/store/sync_themes.dart';

part 'segment.dart';

/// Whether records of collection [c] are synced now: see [SyncCategory].
bool syncCarries(String c) => SyncCategory.carries(c);

/// A record's change as the log carries it: `fl_sync::Op`.
typedef SyncOp = ({String c, String id, String h, Object? d});

/// Where large records are kept beside the log (`op-<name>.age`).
abstract interface class SyncBlobStore {
  /// [body] kept as [name] beside the log; already there is done.
  Future<void> putBlob(String name, Uint8List body);

  /// The blob [name], null when it is gone.
  Future<Uint8List?> getBlob(String name);

  /// The blobs whose name starts with [prefix], and when each was written.
  Future<List<({String name, DateTime? at})>> blobs(String prefix);

  Future<void> deleteBlob(String name);
}

/// Where the log is kept (LK Cloud's `/v2/sync/{app}/log`).
abstract interface class SyncLogTransport implements SyncBlobStore {
  /// Appends [body] once per [key]: the seq given, of which log, and whether
  /// a snapshot is due.
  Future<({String log, int seq, bool compact})> append(String key, Uint8List body);

  /// The batches after [after] of [log], or [SyncLogPage.compacted].
  Future<SyncLogPage> read(int after, String? log);

  /// [body] as the snapshot up to [seq]; false when one at or past it is
  /// there already.
  Future<bool> putSnapshot(int seq, Uint8List body);

  /// The snapshot, null before there is one.
  Future<({String log, int seq, Uint8List body})?> snapshot();
}

final class SyncLogPage {
  const SyncLogPage({required this.log, required this.batches, required this.more, this.compacted = false});

  /// The batches after the cursor are gone, or it was of another log: the
  /// snapshot is read, then the log after it.
  const SyncLogPage.compacted({this.log}) : batches = const [], more = false, compacted = true;

  final String? log;
  final List<(int, Uint8List)> batches;
  final bool more;
  final bool compacted;
}

/// The log takes no more batches until a snapshot covers them
/// (`409 sync_log_full`).
final class SyncLogFull implements Exception {
  const SyncLogFull();
}

/// A batch written by a newer build, in a format this one does not read:
/// the log is not read past it until this build is updated.
final class SyncLogTooNew implements Exception {
  const SyncLogTooNew(this.version);

  final Object? version;

  @override
  String toString() => 'SyncLogTooNew: batch version $version';
}

/// What batches and snapshots are sealed with: the account's sync key.
abstract interface class SyncSeal {
  Future<Uint8List> seal(Uint8List plain);
  Future<Uint8List> open(Uint8List sealed);

  /// A name for [data] only holders of the key can derive (`fl_sync::blob_name`).
  String nameOf(List<int> data);

  /// Looks again for the account's key, after something did not [open]:
  /// whether a newer one was found (the key was replaced elsewhere).
  Future<bool> refresh();
}

/// What the operation-log syncs share, whatever keeps the log: reading the
/// records as ops (a large one as a blob), sealing them in batches, and
/// applying the ops other devices sent that win. State in `sync_state`
/// under the engine's [_prefix]; one run at a time.
abstract base class SyncEngine {
  SyncEngine(
    this._blobs,
    this._seal,
    this._prefix, {
    FutureOr<void> Function(List<SyncOp> won)? write,
    bool Function(String c)? carries,
    void Function()? stamp,
  }) : _write = write ?? SyncAnnounce.write,
       _carriesNow = carries ?? _all,
       _stamp = stamp ?? _stampFiles;

  final SyncBlobStore _blobs;

  /// Where this engine's keys are in `sync_state`: `log.`, `seg.`.
  final String _prefix;

  /// Stamps what changed without a write that stamps it (an installed
  /// theme, a picked file), before what is pending is read.
  final void Function() _stamp;

  final SyncSeal _seal;

  /// Writes the ops that won and tells the app.
  final FutureOr<void> Function(List<SyncOp> won) _write;

  /// Whether records of collection `c` are sent and taken (the settings only
  /// while the user syncs them).
  final bool Function(String c) _carriesNow;

  /// [_carriesNow] as each run first asked it: a category switched during a
  /// run is taken by the next (a [reset] follows), so a snapshot this one
  /// writes keeps what it was passing on.
  Map<String, bool>? _carried;

  bool _carries(String c) => _carried == null ? _carriesNow(c) : _carried!.putIfAbsent(c, () => _carriesNow(c));

  static bool _all(String _) => true;

  static void _stampFiles() {
    SyncThemes.stamp();
    for (final kind in SyncRecords.kinds.values) {
      kind.stamp?.call();
    }
  }

  /// What a batch's sealed bytes may be, under homebase's 256 KiB.
  static const batchMax = 250 << 10;

  /// A record larger than this (as JSON) goes as a blob the op names
  /// (`{"$blob": name}`), so a batch keeps many records.
  static const inlineMax = 64 << 10;

  static const _blobKey = r'$blob';
  static const _blobPrefix = 'op-';

  /// A blob nothing names is removed this long after it was written: a
  /// batch being sent now may name it.
  static const _blobGrace = Duration(days: 1);

  /// 2: the Agent's stores, the secrets, picked files, skills and
  /// benchmarks are records too. A build reading 1 only would compact them
  /// away, so it stops at a 2 instead ([SyncLogTooNew]); 1 is still read.
  static const _version = 2;

  /// Set by builds that dropped what they did not carry, which then wrote no
  /// snapshot. What is not carried is now kept as it came ([_pass]).
  /// TODO: remove once no install has the row.
  static const _partialKey = 'partial';

  /// Whether this engine's last read stopped at a newer build's batch: this
  /// device reads no further until updated. Shown on the backup page; one
  /// per engine, as LK Cloud's and the files' run apart.
  ValueNotifier<bool> get _tooNew;

  /// Runs [read], noting whether it stopped at a newer build's batch.
  Future<void> _reading(Future<void> Function() read) async {
    try {
      await read();
      _tooNew.value = false;
    } on SyncLogTooNew {
      _tooNew.value = true;
      rethrow;
    }
    // Read past: what could not be written then is tried again.
    if (_carries(BenchmarkStore.c)) Stores.benchmark.retry();
    if (_carries(SyncThemes.c)) await SyncThemes.retry();
  }

  Future<void> _running = Future.value();

  Future<void> _serial(Future<void> Function() run) {
    final next = _running.then((_) async {
      _carried = {};
      try {
        await run();
      } finally {
        _carried = null;
      }
    });
    _running = next.catchError((Object _) {});
    return next;
  }

  /// [records] (the oldest first) as ops; [complete] false when one could not
  /// be read ([SyncRecords.unread]): the ops are those before it.
  Future<({List<SyncOp> ops, bool complete})> _opsOf(List<({String c, String id, String hlc})> records) async {
    final read = SyncRecords.reader();
    final send = _sender();
    final ops = <SyncOp>[];
    for (final r in records) {
      final d = await read(r.c, r.id);
      if (identical(d, SyncRecords.unread)) return (ops: ops, complete: false);
      if (identical(d, SyncRecords.silent)) continue;
      // A theme is added only: one removed here says nothing to the others.
      if (d == null && r.c == SyncThemes.c) continue;
      ops.add(await send((c: r.c, id: r.id, h: r.hlc, d: d)));
    }
    return (ops: ops, complete: true);
  }

  /// An op as it is sent: one larger than [inlineMax] as a blob it names,
  /// sealed under the key now.
  Future<SyncOp> Function(SyncOp op) _sender() {
    Set<String>? there;
    return (op) async {
      final json = utf8.encode(jsonEncode(op.d));
      if (json.length <= inlineMax) return op;
      // Named by the op's stamp alone: a snapshot carrying the same op names
      // the batch's blob, whatever this build makes of the record now, so the
      // sweep keeps what a batch still names.
      final name = _blobName(op.h);
      there ??= {for (final b in await _blobs.blobs(_blobPrefix)) b.name};
      if (!there!.contains(name)) {
        await _blobs.putBlob(name, await _seal.seal(Uint8List.fromList(gzip.encode(json))));
        there!.add(name);
      }
      return (c: op.c, id: op.id, h: op.h, d: {_blobKey: name});
    };
  }

  /// The blob of the op stamped [h]: named by the stamp alone.
  String _blobName(String h) => '$_blobPrefix${_seal.nameOf(utf8.encode(h))}.age';

  /// The blobs [_sweepBlobs] may remove.
  String get _sweepPrefix => _blobPrefix;

  static String? _blobOf(Object? d) =>
      d is Map && d.length == 1 && d[_blobKey] is String ? d[_blobKey] as String : null;

  /// Removes the blobs the snapshot just written does not name, past
  /// [_blobGrace]. A batch the snapshot covers may name one still: then its
  /// op lost to a later one of its record (the snapshot holds the op that
  /// won, and names that one's blob), which a device reading the batch
  /// reads after it, so the op is passed over (see [_resolve]). Best effort.
  Future<void> _sweepBlobs(Set<String> named) async {
    try {
      final before = DateTime.now().subtract(_blobGrace);
      for (final blob in await _blobs.blobs(_sweepPrefix)) {
        if (named.contains(blob.name) || (blob.at?.isAfter(before) ?? true)) continue;
        await _blobs.deleteBlob(blob.name);
      }
    } catch (e, s) {
      Loggers.app.warning('Sync blobs sweep', e, s);
    }
  }

  /// [ops] with each blob an op names read in; an op whose blob is gone is
  /// left out (a later op of its record has replaced it).
  Future<List<SyncOp>> _resolve(List<SyncOp> ops) async {
    final out = <SyncOp>[];
    for (final op in ops) {
      final name = _blobOf(op.d);
      if (name == null) {
        out.add(op);
        continue;
      }
      final sealed = await _blobs.getBlob(name);
      if (sealed == null) {
        Loggers.app.warning('Sync passed over ${op.c}/${op.id}: its blob is gone');
        continue;
      }
      try {
        out.add((c: op.c, id: op.id, h: op.h, d: jsonDecode(utf8.decode(gzip.decode(await _open(sealed))))));
      } on Object catch (e) {
        // As an unreadable batch is (see [_decode]): nothing here reads it.
        Loggers.app.warning('Sync passed over ${op.c}/${op.id}: its blob is unreadable', e);
      }
    }
    return out;
  }

  /// The newest of [ops] for each record: no blob is read for an op a later
  /// one of the same read replaces.
  static List<SyncOp> _newest(List<SyncOp> ops) {
    final newest = <(String, String), SyncOp>{};
    for (final op in ops) {
      final had = newest[(op.c, op.id)];
      if (had == null || op.h.compareTo(had.h) > 0) newest[(op.c, op.id)] = op;
    }
    return newest.values.toList();
  }

  /// [ops] of what this device does not sync now, read in ([_resolve]), the
  /// newest of each record: a snapshot written here carries them on, so the
  /// log keeps them whatever this device syncs. Their content, not a blob's
  /// name: a key rotated here seals them again.
  void _pass(List<SyncOp> ops) {
    if (ops.isEmpty) return;
    SqliteStore.transact(() {
      for (final op in ops) {
        SqliteDb.instance.execute(
          'INSERT INTO sync_passed (e, c, id, h, d) VALUES (?, ?, ?, ?, ?) '
          'ON CONFLICT (e, c, id) DO UPDATE SET h = excluded.h, d = excluded.d WHERE excluded.h > sync_passed.h;',
          [_prefix, op.c, op.id, op.h, jsonEncode(op.d)],
        );
      }
    });
  }

  /// What [_pass] kept and this device still does not sync.
  List<SyncOp> _passed() => [
    for (final row in SqliteDb.instance.select('SELECT c, id, h, d FROM sync_passed WHERE e = ?;', [_prefix]))
      if (!_carries(row['c'] as String))
        (c: row['c'] as String, id: row['id'] as String, h: row['h'] as String, d: jsonDecode(row['d'] as String)),
  ];

  /// What this device holds as a snapshot holds it: its records it syncs,
  /// and what it keeps for the others ([_pass]); null when a record could
  /// not be read.
  Future<List<SyncOp>?> _snapshotOps() async {
    _stamp();
    final (:ops, :complete) = await _opsOf([for (final r in SyncRecorder.all()) if (_carries(r.c)) r]);
    if (!complete) return null;
    final send = _sender();
    return [...ops, for (final op in _passed()) await send(op)];
  }

  static void _forgetPassed(String prefix) =>
      SqliteDb.instance.execute('DELETE FROM sync_passed WHERE e = ?;', [prefix]);

  /// The ops that win over what is here, written.
  Future<void> _apply(List<SyncOp>? received, Map<String, String?> state) async {
    if (received == null) return _put(state);
    final carried = [for (final op in received) if (_carries(op.c)) op];
    _pass(await _resolve(_newest([for (final op in received) if (!_carries(op.c)) op])));
    // Every await before the stamps are read: an edit made meanwhile is then
    // among them, and an older op does not overwrite it.
    final ops = await _resolve(carried);
    final current = SyncRecorder.stampsOf({for (final op in ops) (op.c, op.id)});
    final won = (jsonDecode(
      syncWinners(
        opsJson: jsonEncode([for (final op in ops) {'c': op.c, 'id': op.id, 'h': op.h, 'd': op.d}]),
        currentJson: jsonEncode({
          for (final MapEntry(:key, :value) in current.entries) '${key.$1}\u0000${key.$2}': value,
        }),
      ),
    ) as List)
        .cast<Map<String, dynamic>>();
    final winners = [
      for (final op in won) (c: op['c'] as String, id: op['id'] as String, h: op['h'] as String, d: op['d']),
    ];
    // A category turned off while this read: kept for the others, not here.
    _pass([for (final op in winners) if (!_carries(op.c)) op]);
    final write = [for (final op in winners) if (_carries(op.c)) op];
    if (write.isNotEmpty) await _write(write);
    _put(state);
  }

  /// [ops] in batches each sealed under [batchMax]. One op too large alone is
  /// left out and logged.
  Future<List<({List<SyncOp> ops, Uint8List body})>> _batches(List<SyncOp> ops) async {
    if (ops.isEmpty) return const [];
    final body = await _seal.seal(_encode(ops));
    if (body.length <= batchMax) return [(ops: ops, body: body)];
    if (ops.length == 1) {
      // A large record goes as a blob ([inlineMax]): only a key this long.
      Loggers.app.warning('Sync left out ${ops.single.c}/${ops.single.id}: ${body.length} bytes');
      return const [];
    }
    final half = ops.length ~/ 2;
    return [...await _batches(ops.sublist(0, half)), ...await _batches(ops.sublist(half))];
  }

  /// [ops] as a batch or snapshot holds them, with [extra] beside them.
  static Uint8List _encode(List<SyncOp> ops, [Map<String, Object?> extra = const {}]) => Uint8List.fromList(
    gzip.encode(
      utf8.encode(
        jsonEncode({
          'v': _version,
          'ops': [for (final op in ops) {'c': op.c, 'id': op.id, 'h': op.h, 'd': op.d}],
          ...extra,
        }),
      ),
    ),
  );

  /// Whether the key was looked for again in this read of the log: once is
  /// enough to find one that replaced it.
  var _refreshed = false;

  /// [sealed] opened; sealed to a key that replaced the one held here, that
  /// key is taken first.
  Future<Uint8List> _open(Uint8List sealed) async {
    try {
      return await _seal.open(sealed);
    } on FormatException {
      if (_refreshed) rethrow;
      _refreshed = true;
      if (!await _seal.refresh()) rethrow;
      return _seal.open(sealed);
    }
  }

  /// [sealed]'s ops; null, logged, for one nothing here can ever read (not
  /// sealed to this key, damaged), so the log is read on past it. A newer
  /// format stops the read: an update reads it.
  Future<List<SyncOp>?> _decode(Uint8List sealed, String what) async {
    final Uint8List plain;
    try {
      plain = await _open(sealed);
    } on Object catch (e) {
      Loggers.app.warning('Sync skipped unreadable $what', e);
      return null;
    }
    return _parse(plain, what)?.ops;
  }

  /// [plain]'s ops and what it holds besides; null, logged, when it is not
  /// one this build reads. A newer format throws [SyncLogTooNew].
  static ({List<SyncOp> ops, Map<String, dynamic> json})? _parse(Uint8List plain, String what) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(gzip.decode(plain))) as Map<String, dynamic>;
    } on Object catch (e) {
      Loggers.app.warning('Sync skipped unreadable $what', e);
      return null;
    }
    final version = json['v'];
    if (version is int && version > _version) throw SyncLogTooNew(version);
    try {
      if (version is! int || version < 1) throw FormatException('version $version');
      return (
        ops: [
          for (final op in json['ops'] as List)
            (c: op['c'] as String, id: op['id'] as String, h: op['h'] as String, d: op['d']),
        ],
        json: json,
      );
    } on Object catch (e) {
      Loggers.app.warning('Sync skipped unreadable $what', e);
      return null;
    }
  }

  /// A batch's `Idempotency-Key`: random, kept with its bytes until answered.
  static String _newKey() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  String? _get(String k) => _stateAt(_prefix, k);

  void _put(Map<String, String?> values) => _setStateAt(_prefix, values);

  static String? _stateAt(String prefix, String k) {
    final rows = SqliteDb.instance.select('SELECT v FROM sync_state WHERE k = ?;', ['$prefix$k']);
    return rows.isEmpty ? null : rows.first['v'] as String;
  }

  static void _setStateAt(String prefix, Map<String, String?> values) {
    SqliteStore.transact(() {
      for (final MapEntry(:key, :value) in values.entries) {
        if (value == null) {
          SqliteDb.instance.execute('DELETE FROM sync_state WHERE k = ?;', ['$prefix$key']);
        } else {
          SqliteDb.instance.execute(
            'INSERT INTO sync_state (k, v) VALUES (?, ?) ON CONFLICT (k) DO UPDATE SET v = excluded.v;',
            ['$prefix$key', value],
          );
        }
      }
    });
  }
}

/// The operation-log sync on a server-ordered log, LK Cloud's: sends this
/// device's changes as batches of ops, applies the ops other devices sent that
/// win, and writes a snapshot when the log asks for one.
final class LogSync extends SyncEngine {
  LogSync(this._transport, SyncSeal seal, {super.write, super.carries, super.stamp}) : super(_transport, seal, 'log.');

  final SyncLogTransport _transport;

  /// [SyncEngine._tooNew] for LK Cloud's log.
  static final tooNew = ValueNotifier(false);

  @override
  ValueNotifier<bool> get _tooNew => tooNew;

  static String? _state(String k) => SyncEngine._stateAt('log.', k);

  static void _setState(Map<String, String?> values) => SyncEngine._setStateAt('log.', values);

  static const _logKey = 'log';
  static const _cursorKey = 'cursor';
  static const _sentKey = 'sent';
  static const _joinedKey = 'joined';

  /// A batch sealed and not yet answered: sent again as it is, so homebase
  /// takes it once.
  ({String key, Uint8List body, String last})? _unanswered;
  DateTime? _unansweredAt;

  /// An unanswered batch older than this is built again rather than sent:
  /// a blob it names may have been swept meanwhile ([_blobGrace]).
  static const _unansweredMax = Duration(hours: 12);

  /// Reads what other devices sent, then sends what this one has: sent
  /// even when the log cannot be read on (a batch of a newer build).
  Future<void> sync() => _serial(() async {
    Object? unread;
    StackTrace? trace;
    try {
      await _pull();
    } catch (e, s) {
      unread = e;
      trace = s;
    }
    await _push();
    if (unread != null) Error.throwWithStackTrace(unread, trace!);
  });

  /// Reads what other devices sent.
  Future<void> pull() => _serial(_pull);

  /// Whether the log at [seq] has batches not read here.
  static bool behind(int seq) => seq > (int.tryParse(_state(_cursorKey) ?? '') ?? 0);

  /// [forget], after the run going on.
  Future<void> reset() => _serial(() async => forget());

  /// Replaces the key ([rekey] makes the new one current and findable), then
  /// writes a snapshot under it at once, so a device that has only the new
  /// key has the state whole. Batches before it stay readable with the old
  /// key until homebase drops them.
  Future<void> rotate(Future<void> Function() rekey) => _serial(() async {
    await _pull();
    await rekey();
    // A snapshot goes past the last one: a batch makes room for it.
    await _append((
      key: SyncEngine._newKey(),
      body: await _seal.seal(SyncEngine._encode(const [])),
      last: _state(_sentKey) ?? '',
    ));
    await _pull();
    if (!await _writeSnapshot()) throw StateError('no snapshot written');
  });

  Future<void> _pull() => _reading(_read);

  Future<void> _read() async {
    _refreshed = false;
    while (true) {
      final cursor = int.tryParse(_state(_cursorKey) ?? '') ?? 0;
      final page = await _transport.read(cursor, cursor == 0 ? null : _state(_logKey));
      if (page.compacted) {
        final snapshot = await _transport.snapshot();
        if (snapshot == null) {
          // A log made anew, with nothing covering it: read it from its start.
          _setState({_logKey: page.log, _cursorKey: '0'});
          if (cursor == 0) return;
          continue;
        }
        await _apply(
          await _decode(snapshot.body, 'snapshot ${snapshot.seq}'),
          {_logKey: snapshot.log, _cursorKey: '${snapshot.seq}'},
        );
        continue;
      }
      for (final (seq, body) in page.batches) {
        await _apply(await _decode(body, 'batch $seq'), {_logKey: page.log, _cursorKey: '$seq'});
      }
      if (!page.more) return;
    }
  }

  Future<void> _push() async {
    final log = _state(_logKey);
    // Joining a log (the first time, or one made anew): every record goes,
    // whoever stamped it, so what this device holds reaches the others.
    final joining = log == null || _state(_joinedKey) != log;
    var compact = false;
    // Before what is pending is read: it moves what was sent.
    if (_unansweredAt case final at? when DateTime.now().difference(at) > _unansweredMax) {
      // Not sent as far as this device knows: [_sentKey] did not move, so its
      // records are read and sent again below.
      _unanswered = null;
    }
    if (_unanswered case final batch?) {
      compact |= await _append(batch);
    }
    _stamp();
    final all = joining ? SyncRecorder.all() : SyncRecorder.pending(_state(_sentKey) ?? '');
    final (:ops, :complete) = await _opsOf([for (final r in all) if (_carries(r.c)) r]);
    // A record that could not be read stops the send just before it, so it
    // and what follows are read again next time.
    final stamped = complete ? all : [for (final r in all) if (r.hlc.compareTo(ops.lastOrNull?.h ?? '') <= 0) r];
    final mine = SyncRecorder.deviceHexOf(SyncRecorder.device);
    var last = _state(_sentKey) ?? '';
    for (final chunk in await _batches(ops)) {
      for (final op in chunk.ops) {
        if (op.h.substring(16) == mine && op.h.compareTo(last) > 0) last = op.h;
      }
      compact |= await _append((key: SyncEngine._newKey(), body: chunk.body, last: last));
    }
    // Past what was left out too, so it is not looked at again.
    final newest = stamped
        .map((r) => r.hlc)
        .where((h) => h.substring(16) == mine)
        .fold(last, (a, h) => h.compareTo(a) > 0 ? h : a);
    if (newest != last) _setState({_sentKey: newest});
    if (joining && complete) _setState({_joinedKey: _state(_logKey)});
    if (compact) {
      await _pull();
      await _writeSnapshot();
    }
  }

  /// Sends [batch]; whether a snapshot is due. A full log is compacted
  /// first, then sent again.
  Future<bool> _append(({String key, Uint8List body, String last}) batch) async {
    if (!identical(_unanswered, batch)) _unansweredAt = DateTime.now();
    _unanswered = batch;
    final ({String log, int seq, bool compact}) appended;
    try {
      appended = await _transport.append(batch.key, batch.body);
    } on SyncLogFull {
      await _pull();
      if (!await _writeSnapshot()) rethrow;
      return _append(batch);
    }
    _unanswered = null;
    final log = _state(_logKey);
    final cursor = int.tryParse(_state(_cursorKey) ?? '') ?? 0;
    _setState({
      _sentKey: batch.last,
      if (log == null) _logKey: appended.log,
      // Right after the cursor: nothing between to read, and this batch is
      // what is here already.
      if ((log == null || log == appended.log) && appended.seq == cursor + 1) _cursorKey: '${appended.seq}',
    });
    return appended.compact;
  }

  /// Writes a snapshot at the cursor; whether one is there now.
  Future<bool> _writeSnapshot() async {
    final cursor = int.tryParse(_state(_cursorKey) ?? '') ?? 0;
    if (cursor == 0) return false;
    final ops = await _snapshotOps();
    if (ops == null) {
      Loggers.app.info('Sync snapshot left: a record could not be read');
      return false;
    }
    final body = await _seal.seal(SyncEngine._encode(ops));
    if (!await _transport.putSnapshot(cursor, body)) {
      Loggers.app.info('Sync snapshot at $cursor: another is there already');
      return true;
    }
    await _sweepBlobs({for (final op in ops) ?SyncEngine._blobOf(op.d)});
    return true;
  }

  /// Forgets the log: the next sync reads it from its start and joins it
  /// again. For another account, or what is carried changing.
  static void forget() {
    _setState({_logKey: null, _cursorKey: null, _sentKey: null, _joinedKey: null, SyncEngine._partialKey: null});
    SyncEngine._forgetPassed('log.');
    tooNew.value = false;
  }

  /// The log of [account] from now on: another account's is forgotten.
  static void bind(String account) {
    if (_state(_accountKey) == account) return;
    forget();
    _setState({_accountKey: account});
  }

  static const _accountKey = 'account';
}

/// Writes ops that won ([SyncRecords.write], [SyncThemes.install],
/// [SyncRecords.kinds]) and tells the app what changed, as a backup's merge
/// does.
abstract final class SyncAnnounce {
  static Future<void> write(List<SyncOp> won) async {
    final keysBefore = [for (final k in Stores.key.fetch()) k.key];
    final kinds = SyncRecords.kinds;
    final collections = SyncRecords.write([
      for (final op in won)
        if (op.c != SyncThemes.c && !kinds.containsKey(op.c)) op,
    ]);
    final themes = [for (final op in won) if (op.c == SyncThemes.c) op];
    await SyncThemes.install(themes);
    for (final MapEntry(key: c, value: kind) in kinds.entries) {
      final ops = [for (final op in won) if (op.c == c) op];
      if (ops.isNotEmpty) await kind.install(ops);
    }
    // The preset may have come before or after its theme.
    if (themes.isNotEmpty || collections.contains('kv:${Stores.setting.name}')) SyncThemes.reselect();
    final servers = collections.contains(Stores.server.table);
    if (collections.contains(Stores.key.table)) {
      Stores.key.invalidate();
      KeyPassphrases.forgetGone(keysBefore, Stores.key.fetch().map((e) => e.key));
    }
    if (collections.contains(Stores.bmcCredential.table)) {
      Stores.bmcCredential.invalidate();
    }
    if (servers) {
      Stores.server.invalidate();
      // A server's delete cascades these rows.
      Stores.portForward.invalidate();
      Stores.remoteDesktop.invalidate();
      Stores.snippet.invalidate();
      Stores.pve.invalidate();
    }
    if (collections.contains(Stores.snippet.table)) {
      Stores.snippet.invalidate();
    }
    if (collections.contains(Stores.portForward.table)) Stores.portForward.invalidate();
    if (collections.contains(Stores.remoteDesktop.table)) Stores.remoteDesktop.invalidate();
    StoreReload.after({
      if (servers) ...{ReloadedStore.servers, ReloadedStore.containers},
      if (collections.contains(Stores.snippet.table)) ReloadedStore.snippets,
      if (collections.contains(Stores.key.table)) ReloadedStore.keys,
      if (collections.contains(Stores.bmcCredential.table)) ReloadedStore.bmcCredentials,
    });
  }
}
