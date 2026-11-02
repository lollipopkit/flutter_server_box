import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/ssh_key_passphrase.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/data/provider/container.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:server_box/data/store/sync_records.dart';

/// A record's change as the log carries it: `fl_sync::Op`.
typedef SyncOp = ({String c, String id, String h, Object? d});

/// Where the log is kept (LK Cloud's `/v2/sync/{app}/log`).
abstract interface class SyncLogTransport {
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

  /// [body] kept as [name] beside the log; already there is done.
  Future<void> putBlob(String name, Uint8List body);

  /// The blob [name], null when it is gone.
  Future<Uint8List?> getBlob(String name);

  /// The blobs whose name starts with [prefix], and when each was written.
  Future<List<({String name, DateTime? at})>> blobs(String prefix);

  Future<void> deleteBlob(String name);
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

/// A device that leaves records out ([LogSync.carries]) holds less than the
/// log, so it writes no snapshot, and so cannot replace the key.
final class SyncLogPartial implements Exception {
  const SyncLogPartial();
}

/// The operation-log sync (`docs/dev/sync-log.md`): sends this device's
/// changes as batches of ops, applies the ops other devices sent that win,
/// and writes a snapshot when the log asks for one. Everything it keeps is in
/// `sync_state`; one run at a time.
final class LogSync {
  LogSync(this._transport, this._seal, {void Function(List<SyncOp> won)? write, bool Function(String c)? carries})
    : _write = write ?? SyncAnnounce.write,
      _carries = carries ?? _all;

  final SyncLogTransport _transport;
  final SyncSeal _seal;

  /// Writes the ops that won and tells the app.
  final void Function(List<SyncOp> won) _write;

  /// Whether records of collection `c` are sent and taken (the settings only
  /// while the user syncs them).
  final bool Function(String c) _carries;

  static bool _all(String _) => true;

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

  static const _version = 1;
  static const _logKey = 'log';
  static const _cursorKey = 'cursor';
  static const _sentKey = 'sent';
  static const _joinedKey = 'joined';

  /// Set once an op was left out ([_carries]): what this device holds is then
  /// not the whole log, so it writes no snapshot (one would drop those ops).
  static const _partialKey = 'partial';

  Future<void> _running = Future.value();

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
    if (_state(_partialKey) != null) throw const SyncLogPartial();
    await rekey();
    // A snapshot goes past the last one: a batch makes room for it.
    await _append((key: _newKey(), body: await _seal.seal(_encode(const [])), last: _state(_sentKey) ?? ''));
    await _pull();
    if (!await _writeSnapshot()) throw StateError('no snapshot written');
  });

  Future<void> _serial(Future<void> Function() run) {
    final next = _running.then((_) => run());
    _running = next.catchError((Object _) {});
    return next;
  }

  Future<void> _pull() async {
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
        await _apply(await _decode(snapshot.body, 'snapshot ${snapshot.seq}'), {_logKey: snapshot.log, _cursorKey: '${snapshot.seq}'});
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
    final stamped = joining ? SyncRecorder.all() : SyncRecorder.pending(_state(_sentKey) ?? '');
    final ops = await _opsOf([for (final r in stamped) if (_carries(r.c)) r]);
    final mine = SyncRecorder.deviceHexOf(SyncRecorder.device);
    var last = _state(_sentKey) ?? '';
    for (final chunk in await _batches(ops)) {
      for (final op in chunk.ops) {
        if (op.h.substring(16) == mine && op.h.compareTo(last) > 0) last = op.h;
      }
      compact |= await _append((key: _newKey(), body: chunk.body, last: last));
    }
    // Past what was left out too, so it is not looked at again.
    final newest = stamped.map((r) => r.hlc).where((h) => h.substring(16) == mine).fold(last, (a, h) => h.compareTo(a) > 0 ? h : a);
    if (newest != last) _setState({_sentKey: newest});
    if (joining) _setState({_joinedKey: _state(_logKey)});
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
    if (_state(_partialKey) != null) {
      Loggers.app.info('Sync snapshot left to a device holding the whole log');
      return false;
    }
    final ops = await _opsOf([for (final r in SyncRecorder.all()) if (_carries(r.c)) r]);
    final body = await _seal.seal(_encode(ops));
    if (!await _transport.putSnapshot(cursor, body)) {
      Loggers.app.info('Sync snapshot at $cursor: another is there already');
      return true;
    }
    await _sweepBlobs({for (final op in ops) ?_blobOf(op.d)});
    return true;
  }

  /// [records] as ops, each as the store holds it now; a large one put in a
  /// blob it names.
  Future<List<SyncOp>> _opsOf(List<({String c, String id, String hlc})> records) async {
    final read = SyncRecords.reader();
    final ops = <SyncOp>[];
    Set<String>? there;
    for (final r in records) {
      final d = read(r.c, r.id);
      final json = utf8.encode(jsonEncode(d));
      if (json.length <= inlineMax) {
        ops.add((c: r.c, id: r.id, h: r.hlc, d: d));
        continue;
      }
      // Named by the op's stamp alone: a snapshot carrying the same op names
      // the batch's blob, whatever this build makes of the record now, so the
      // sweep keeps what a batch still names.
      final name = '$_blobPrefix${_seal.nameOf(utf8.encode(r.hlc))}.age';
      there ??= {for (final b in await _transport.blobs(_blobPrefix)) b.name};
      if (!there.contains(name)) {
        await _transport.putBlob(name, await _seal.seal(Uint8List.fromList(gzip.encode(json))));
        there.add(name);
      }
      ops.add((c: r.c, id: r.id, h: r.hlc, d: {_blobKey: name}));
    }
    return ops;
  }

  static String? _blobOf(Object? d) => d is Map && d.length == 1 && d[_blobKey] is String ? d[_blobKey] as String : null;

  /// Removes the blobs the snapshot just written does not name, past
  /// [_blobGrace]. A batch the snapshot covers may name one still: then its
  /// op lost to a later one of its record (the snapshot holds the op that
  /// won, and names that one's blob), which a device reading the batch
  /// reads after it, so the op is passed over (see [_resolve]). Best effort.
  Future<void> _sweepBlobs(Set<String> named) async {
    try {
      final before = DateTime.now().subtract(_blobGrace);
      for (final blob in await _transport.blobs(_blobPrefix)) {
        if (named.contains(blob.name) || (blob.at?.isAfter(before) ?? true)) continue;
        await _transport.deleteBlob(blob.name);
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
      final sealed = await _transport.getBlob(name);
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

  /// The ops that win over what is here, written.
  Future<void> _apply(List<SyncOp>? received, Map<String, String?> state) async {
    if (received == null) return _setState(state);
    final carried = [for (final op in received) if (_carries(op.c)) op];
    if (carried.length < received.length) state = {...state, _partialKey: '1'};
    // Every await before the stamps are read: an edit made meanwhile is then
    // among them, and an older op does not overwrite it.
    final ops = await _resolve(carried);
    final current = SyncRecorder.stampsOf({for (final op in ops) (op.c, op.id)});
    final won = (jsonDecode(
      syncWinners(
        opsJson: jsonEncode([for (final op in ops) {'c': op.c, 'id': op.id, 'h': op.h, 'd': op.d}]),
        currentJson: jsonEncode({for (final MapEntry(:key, :value) in current.entries) '${key.$1}\u0000${key.$2}': value}),
      ),
    ) as List)
        .cast<Map<String, dynamic>>();
    if (won.isNotEmpty) {
      _write([for (final op in won) (c: op['c'] as String, id: op['id'] as String, h: op['h'] as String, d: op['d'])]);
    }
    _setState(state);
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

  static Uint8List _encode(List<SyncOp> ops) => Uint8List.fromList(
    gzip.encode(
      utf8.encode(
        jsonEncode({
          'v': _version,
          'ops': [for (final op in ops) {'c': op.c, 'id': op.id, 'h': op.h, 'd': op.d}],
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
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(gzip.decode(await _open(sealed)))) as Map<String, dynamic>;
    } on Object catch (e) {
      Loggers.app.warning('Sync skipped unreadable $what', e);
      return null;
    }
    final version = json['v'];
    if (version is int && version > _version) throw SyncLogTooNew(version);
    try {
      if (version != _version) throw FormatException('version $version');
      return [
        for (final op in json['ops'] as List)
          (c: op['c'] as String, id: op['id'] as String, h: op['h'] as String, d: op['d']),
      ];
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

  static String? _state(String k) {
    final rows = SqliteDb.instance.select('SELECT v FROM sync_state WHERE k = ?;', ['log.$k']);
    return rows.isEmpty ? null : rows.first['v'] as String;
  }

  static void _setState(Map<String, String?> values) {
    SqliteStore.transact(() {
      for (final MapEntry(:key, :value) in values.entries) {
        if (value == null) {
          SqliteDb.instance.execute('DELETE FROM sync_state WHERE k = ?;', ['log.$key']);
        } else {
          SqliteDb.instance.execute(
            'INSERT INTO sync_state (k, v) VALUES (?, ?) ON CONFLICT (k) DO UPDATE SET v = excluded.v;',
            ['log.$key', value],
          );
        }
      }
    });
  }

  /// Forgets the log: the next sync reads it from its start and joins it
  /// again. For another account, or what is carried changing.
  static void forget() =>
      _setState({_logKey: null, _cursorKey: null, _sentKey: null, _joinedKey: null, _partialKey: null});

  /// The log of [account] from now on: another account's is forgotten.
  static void bind(String account) {
    if (_state(_accountKey) == account) return;
    forget();
    _setState({_accountKey: account});
  }

  static const _accountKey = 'account';
}

/// Writes ops that won ([SyncRecords.write]) and tells the app what changed,
/// as a backup's merge does.
abstract final class SyncAnnounce {
  static void write(List<SyncOp> won) {
    final keysBefore = [for (final k in Stores.key.fetch()) k.key];
    final collections = SyncRecords.write(won);
    final servers = collections.contains(Stores.server.table);
    if (collections.contains(Stores.key.table)) {
      Stores.key.invalidate();
      unawaited(KeyPassphrases.forgetGone(keysBefore, Stores.key.fetch().map((e) => e.key)));
      GlobalRef.gRef?.read(privateKeyProvider.notifier).reload();
    }
    if (collections.contains(Stores.bmcCredential.table)) {
      Stores.bmcCredential.invalidate();
      GlobalRef.gRef?.read(bmcCredentialProvider.notifier).reload();
    }
    if (servers) {
      Stores.server.invalidate();
      // A server's delete cascades these rows.
      Stores.portForward.invalidate();
      Stores.remoteDesktop.invalidate();
      Stores.snippet.invalidate();
      Stores.pve.invalidate();
      unawaited(GlobalRef.gRef?.read(serversProvider.notifier).reload());
      GlobalRef.gRef?.invalidate(containerProvider);
    }
    if (collections.contains(Stores.snippet.table)) {
      Stores.snippet.invalidate();
      GlobalRef.gRef?.read(snippetProvider.notifier).reload();
    }
    if (collections.contains(Stores.portForward.table)) Stores.portForward.invalidate();
    if (collections.contains(Stores.remoteDesktop.table)) Stores.remoteDesktop.invalidate();
  }
}
