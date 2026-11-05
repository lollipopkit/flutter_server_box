import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart'
    show ThemeBackup, ThemeBlobStore, ThemeRestoreReport;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:server_box/core/ssh/identities.dart';
import 'package:server_box/core/ssh/key_passphrase.dart';
import 'package:server_box/core/ssh/key_unlock.dart';
import 'package:server_box/core/sync/lkc.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/file/backend/local.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/store_reload.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/migrations/m008_settings_fixups.dart';
import 'package:server_box/data/store/migrations/m009_grouped_settings.dart';
import 'package:server_box/data/store/migrations/m011_virt_key_rows.dart';
import 'package:server_box/data/store/migrations/m013_virt_key_names.dart';
import 'package:server_box/data/store/migrations/m021_home_tabs_bar.dart';
import 'package:server_box/data/store/migrations/m030_pve_virt.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';

part 'backup2.freezed.dart';
part 'backup2.g.dart';
part 'backup_restore.dart';

final _loggerV2 = Logger('BackupV2');

@freezed
abstract class BackupV2 with _$BackupV2 implements Mergeable {
  const BackupV2._();

  /// Construct a backup with the latest format (v2).
  ///
  /// All `Map<String, dynamic>` are:
  /// ```json
  /// {
  ///   "key1": Model{},
  ///   "_lastModTime": {
  ///     "key1": 1234567890,
  ///   },
  /// }
  /// ```
  const factory BackupV2({
    required int version,
    required int date,
    required Map<String, Object?> spis,
    required Map<String, Object?> snippets,
    required Map<String, Object?> keys,
    required Map<String, Object?> container,
    required Map<String, Object?> history,
    required Map<String, Object?> settings,

    /// Absent from every file written before port forwards became a record of
    /// their own, so it defaults rather than being required — an older backup
    /// has to keep decoding.
    @Default(<String, Object?>{}) Map<String, Object?> portForwards,

    /// Absent from files written before built-in RDP/VNC support.
    @Default(<String, Object?>{}) Map<String, Object?> remoteDesktopProfiles,

    /// Same reason as [portForwards]: no file written before BMC support has
    /// one. A server whose `bmc.credId` names an account this map does not
    /// carry restores with the address and no account, which the editor shows.
    @Default(<String, Object?>{}) Map<String, Object?> bmcCredentials,

    /// Each server's `PveConfig`, by server id — `PveStore.getAllMap`.
    ///
    /// Absent from files written before PVE had a table of its own. Those
    /// carry it inside the server record's `custom` instead — and so does
    /// every file this build writes, for those builds to read. What [merge]
    /// makes of either is `_pveToRestore`'s rule.
    @Default(<String, Object?>{}) Map<String, Object?> pve,

    /// The installed theme packages, by installation id — see
    /// [ThemeBackup]. Only beside [settings]: they are what the theme
    /// settings point at. Absent from files written before themes were
    /// carried (#1637), whose theme settings restore onto the default.
    @Default(<String, Object?>{}) Map<String, Object?> themes,
  }) = _BackupV2;

  /// Must stay a single expression with a cascade, not a block body.
  /// `Freezed.needsJsonSerializable` only enables JSON generation when the
  /// `fromJson` factory's body `is ExpressionFunctionBody`; with a block body
  /// it silently emits no `@JsonSerializable()`, json_serializable then writes
  /// no `backup2.g.dart`, and `toJson`/`_$BackupV2FromJson` stop existing. The
  /// checked-in generated files predate that check, so the breakage only shows
  /// up the next time codegen runs from scratch.
  factory BackupV2.fromJson(Map<String, dynamic> json) =>
      _$BackupV2FromJson(json).._validateRestorableTypedStores();

  @override
  Future<void> merge({bool force = false}) async {
    await restoreStores(force: force);
  }

  /// Envelope version. Bumped to 3 with the nested `Spi.ssh` layout, so a
  /// reader can tell whether it understands the file before decoding it.
  ///
  /// Kept in step with [SchemaVersion.current]: the stores a backup carries
  /// are exactly the stores the schema describes, and two independent numbers
  /// would drift.
  static const formatVer = SchemaVersion.current;

  /// [blobs]: where theme packages are kept apart, when the backup goes
  /// where they can be (LK Cloud).
  static Future<BackupV2> loadFromStore({
    bool includeSettings = true,
    ThemeBlobStore? blobs,
  }) async {
    return BackupV2(
      version: formatVer,
      date: DateTimeX.timestamp,
      spis: _withLegacyPve(Stores.server.getAllMap(), Stores.pve.fetchAll()),
      snippets: Stores.snippet.getAllMap(),
      keys: Stores.key.getAllMap(),
      bmcCredentials: Stores.bmcCredential.getAllMap(),
      portForwards: Stores.portForward.getAllMap(),
      remoteDesktopProfiles: Stores.remoteDesktop.getAllMap(),
      container: Stores.container.getAllMap(),
      pve: Stores.pve.getAllMap(),
      history: _backupStore(Stores.history),
      settings: includeSettings
          ? _backupStore(Stores.setting)
          : const {},
      themes: includeSettings ? await _themes(blobs) : const {},
    );
  }

  /// Whether this file lacks a record this device holds, or holds one older
  /// than this device's, a delete included — see `SyncIface.lacks`. Records
  /// and their stamps only: those converge. The themes do not (they are what
  /// each device could install), so they are left out.
  bool lacksLocal({required bool includeSettings}) => [
    (Stores.server.getAllMap(), spis),
    (Stores.snippet.getAllMap(), snippets),
    (Stores.key.getAllMap(), keys),
    (Stores.bmcCredential.getAllMap(), bmcCredentials),
    (Stores.portForward.getAllMap(), portForwards),
    (Stores.remoteDesktop.getAllMap(), remoteDesktopProfiles),
    (_backupStore(Stores.history), history),
    if (includeSettings) (_backupStore(Stores.setting), settings),
  ].any((pair) => _lacks(pair.$1, pair.$2));

  static bool _lacks(Map<String, Object?> local, Map<String, Object?> remote) {
    const tsKey = StoreDefaults.defaultLastUpdateTsKey;
    Map<String, int> stamps(Map<String, Object?> rows) => _kvTimestamps(
      rows[tsKey],
      rows.keys.where((key) => key != tsKey),
    );
    final remoteStamps = stamps(remote);
    for (final MapEntry(:key, value: at) in stamps(local).entries) {
      if (at > (remoteStamps[key] ?? 0)) return true;
    }
    return local.keys.any(
      (key) => !_isInternalStoreKey(key) && !remote.containsKey(key),
    );
  }

  static Future<Map<String, Object?>> _themes(ThemeBlobStore? blobs) async {
    final export = await ThemeBackup.export(blobs: blobs);
    if (export.skipped.isNotEmpty) {
      // Listed with nothing to install them from; the restore names them.
      _loggerV2.warning('Themes without a package to carry: ${export.skipped}');
    }
    return export.entries;
  }

  static Future<String> backup([
    String? name,
    String? password,
    bool includeSettings = true,
    ThemeBlobStore? blobs,
  ]) async {
    final bak = await BackupV2.loadFromStore(
      includeSettings: includeSettings,
      blobs: blobs,
    );
    var result = bak.toJsonString();

    final encrypted = password != null && password.isNotEmpty;
    if (encrypted) {
      // Compressed *inside* the envelope, so what goes over the wire is
      // roughly an eighth of what it was: this JSON is one shape repeated a
      // few hundred times, and every key name is spelled out in every record.
      // The armor then expands it once, rather than once per layer.
      result = await AgeCryptor.encrypt(
        compressBackups
            ? gzip.encode(utf8.encode(result))
            : utf8.encode(result),
        password,
      );
    }

    final path = Paths.doc.joinPath(
      name ?? (encrypted ? Miscs.bakFileName : Miscs.plainBakFileName),
    );
    final bytes = utf8.encode(result);
    await const LocalFileBackend().write(
      path,
      () => Stream.value(bytes),
      size: bytes.length,
    );
    return path;
  }

  /// Whether a new backup is compressed before it is encrypted.
  ///
  /// It was a one-way format change for the v3 sync file: an older build
  /// decrypted the envelope, found gzip where it expected text, and stopped
  /// syncing before it uploaded. The age envelope goes further, under the v4
  /// name (`Miscs.bakFileName`): a build before it never sees the file.
  ///
  /// TODO: remove this constant once no supported build predates it, and
  /// compress unconditionally.
  static const compressBackups = true;

  /// gzip's own header.
  ///
  /// What tells the two shapes apart, with no format field to carry: JSON
  /// always begins with `{` (0x7b) and a gzip stream always with 0x1f 0x8b,
  /// so this is exact rather than a guess.
  static const _gzipMagic = [0x1f, 0x8b];

  /// The most a backup may expand to when decompressed.
  ///
  /// A restore reads a file the user chose, so this is not the front line —
  /// but gzip is the one step here where a small input can ask for an
  /// unbounded allocation, and refusing is cheaper than finding out.
  static const _maxPlainBytes = 256 * 1024 * 1024;

  /// [data] as [backup] wrote it: an encrypted backup opened with [password]
  /// (`AgeCryptor`: age, or the `LKFL_ENC` envelope of every build before),
  /// or a plain export. Decrypts in rage's isolate and parses in the
  /// caller's; the app's readers split the two ([unlock], then
  /// [BackupV2.fromPlainBytes] in a worker).
  static Future<BackupV2> open(List<int> data, [String? password]) async =>
      BackupV2.fromPlainBytes(await unlock(data, password));

  /// [data] decrypted when it is encrypted ([password] required then), and
  /// as it is otherwise: gzip or JSON, what [BackupV2.fromPlainBytes] reads.
  static Future<Uint8List> unlock(List<int> data, String? password) async {
    if (!AgeCryptor.isEncrypted(data)) {
      return data is Uint8List ? data : Uint8List.fromList(data);
    }
    if (password == null || password.isEmpty) {
      throw const RemoteBackupPasswordMissing();
    }
    return AgeCryptor.decrypt(data, password);
  }

  /// What the envelope holds, or a plain export: gzip, or the JSON itself.
  factory BackupV2.fromPlainBytes(List<int> bytes) => BackupV2.fromJsonString(
    utf8.decode(_looksGzipped(bytes) ? gunzipCapped(bytes) : bytes),
  );

  factory BackupV2.fromJsonString(String jsonString) {
    final map = json.decode(jsonString) as Map<String, dynamic>;

    // Checked before decoding. `version` was written from the beginning but
    // never read, so a newer file was decoded by whatever reader happened to
    // accept its shape — silently dropping the fields it didn't know.
    // `is num`, not `is int`: JSON has one number type, so a writer emitting
    // `13.0` reaches here as a `double` and skipped the check entirely, while
    // the generated decoder below reads it with `toInt()` and carries on as
    // though it were this format.
    final ver = map['version'];
    if (ver is num && ver > formatVer) {
      throw SchemaTooNewException(stored: ver.ceil(), supported: formatVer);
    }

    return BackupV2.fromJson(map);
  }

  String toJsonString() => json.encode(_toJsonValue(toJson()));

  static bool _looksGzipped(List<int> bytes) =>
      bytes.length >= 2 &&
      bytes[0] == _gzipMagic[0] &&
      bytes[1] == _gzipMagic[1];

  /// gunzip that stops rather than allocating whatever the stream asks for.
  ///
  /// Chunked, because the size is only knowable as the output arrives: gzip's
  /// trailer carries a length, it is at the *end*, and it is not authenticated
  /// by anything. Counting as we go is the only bound that holds.
  @visibleForTesting
  static Uint8List gunzipCapped(List<int> bytes) {
    final out = BytesBuilder(copy: false);
    final decoder = gzip.decoder.startChunkedConversion(
      _CountingSink(out, _maxPlainBytes),
    );
    try {
      decoder.add(bytes);
      decoder.close();
    } catch (_) {
      // The cap throws from inside `add`, which skips the `close` above and
      // leaves the native inflate stream for the finalizer — on exactly the
      // path this exists for, a hostile input, and once per attempt. Closing
      // an incomplete stream throws in turn, which is nothing to report: the
      // reason this failed is already on its way out.
      try {
        decoder.close();
      } catch (_) {}
      rethrow;
    }
    return out.takeBytes();
  }

  void _validateRestorableTypedStores() {
    _validateRestorableStore('spis', spis);
    _validateRestorableStore('snippets', snippets);
    _validateRestorableStore('keys', keys);
    _validateRestorableStore('portForwards', portForwards);
    _validateRestorableStore('remoteDesktopProfiles', remoteDesktopProfiles);
    _validateRestorableStore('bmcCredentials', bmcCredentials);
  }

  /// Whether this file was written by a build with `server_pve`, and so has
  /// a [pve] section that is the complete state: every server with PVE has an
  /// entry, and one without an entry has none.
  bool get carriesPveSection => version > PveVirtMigration.appliedAt;

  /// [spis] with each server's PVE configuration also written into its
  /// record's `custom`, where a build from before `server_pve` reads it —
  /// see `PveConfig.toLegacyCustom`. Such a build ignores the [pve] section
  /// and writes back only what it read.
  // TODO(migration): remove after 5 releases from v1.0.1715.
  static Map<String, Object?> _withLegacyPve(
    Map<String, Object?> spis,
    Map<String, PveConfig> pve,
  ) => {
    for (final MapEntry(:key, :value) in spis.entries)
      key: switch ((value, pve[key])) {
        (final Map record, final PveConfig cfg) =>
          PveConfig.withLegacyCustom(record, cfg),
        _ => value,
      },
  };

}

/// Keeps the per-record modification map needed by sync, but not device-local
/// layout and migration markers. Restoring those markers from another device
/// can make this device skip a migration or claim a schema it does not have.
///
/// Device-local keys ([SqliteStore.isDeviceLocalKey]) are the same idea for
/// keys with ordinary names — see [SettingStore.deviceLocalKeys], where a
/// permission granted on one machine must not be granted on another by
/// restoring a file.
Map<String, Object?> _backupStore(SqliteStore store) {
  final rows = store.getAllMap(includeInternalKeys: true);
  rows.removeWhere((key, _) => _isLocalOnly(store, key));
  // The stamps as read, without device-local ones (a build that does not
  // hold a key device-local reads one with no row as deleted there, and
  // deletes its own), and as the map: a string holding it made two devices'
  // backups differ in shape.
  if (store.lastUpdateTs case final stamps?) rows[store.lastUpdateTsKey] = stamps;
  return rows;
}

Map<String, int> _kvTimestamps(Object? raw, Iterable<String> recordKeys) {
  Object? decoded = raw;
  if (raw is String) {
    try {
      decoded = json.decode(raw);
    } catch (_) {
      decoded = int.tryParse(raw);
    }
  }
  if (decoded is num) {
    final timestamp = decoded.toInt();
    return {for (final key in recordKeys) key: timestamp};
  }
  if (decoded is! Map) return const {};
  return {
    for (final entry in decoded.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}

/// Whether [key] belongs to this device rather than to the backup.
///
/// `lastUpdateTs` is internal and still travels: it is what sync compares.
bool _isLocalOnly(SqliteStore store, String key) =>
    (store.isInternalKey(key) && key != store.lastUpdateTsKey) ||
    store.isDeviceLocalKey(key);

Object? _toEncodable(Object? value) {
  if (value is Enum) return value.name;

  return switch (value) {
    final Spi spi => spi.toJson(),
    final Snippet snippet => snippet.toJson(),
    final PrivateKeyInfo key => key.toJson(),
    final PortForwardConfig forward => forward.toJson(),
    final ServerCustom custom => custom.toJson(),
    final WakeOnLanCfg wolCfg => wolCfg.toJson(),
    // Nested on Spi. All three were missing, so backing up a server that used
    // any of them threw instead of producing a file. `_$SpiToJson` emits the
    // object itself for each, so every one of them has to be named here.
    final SshCredential ssh => ssh.toJson(),
    final MonitorHttpCredential monitor => monitor.toJson(),
    final BmcCfg bmc => bmc.toJson(),
    final PveConfig pve => pve.toJson(),
    _ => throw UnsupportedError(
      'Cannot JSON-encode ${value.runtimeType}: missing supported toJson()',
    ),
  };
}

Object? _toJsonValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entryValue) {
      if (key is! String) {
        throw UnsupportedError(
          'Cannot JSON-encode map key ${key.runtimeType}: keys must be String',
        );
      }
      return MapEntry(key, _toJsonValue(entryValue));
    });
  }
  if (value is Iterable) {
    return value.map(_toJsonValue).toList(growable: false);
  }
  return _toJsonValue(_toEncodable(value));
}

void _validateRestorableStore(String storeName, Map<String, Object?> data) {
  for (final entry in data.entries) {
    if (_isInternalStoreKey(entry.key) || entry.value == null) continue;
    if (entry.value is Map) continue;

    throw FormatException(
      'Backup contains corrupted $storeName entry "${entry.key}": '
      'expected JSON object, got ${entry.value.runtimeType}. '
      'Backups created by app versions 1.0.1448-1.0.1450 may be affected '
      'and cannot be fully restored.',
    );
  }
}

bool _isInternalStoreKey(String key) =>
    key.startsWith(StoreDefaults.prefixKey) ||
    key.startsWith(StoreDefaults.prefixKeyOld);

/// Counts what a decompressor produces and refuses past a limit.
///
/// The limit has to be enforced here rather than on the result: gzip's own
/// trailer carries the decompressed length, it sits at the *end* of the
/// stream, and nothing authenticates it — so the only bound that holds is the
/// one applied as the bytes arrive.
final class _CountingSink implements Sink<List<int>> {
  _CountingSink(this._out, this._max);

  final BytesBuilder _out;
  final int _max;
  var _seen = 0;

  @override
  void add(List<int> chunk) {
    _seen += chunk.length;
    if (_seen > _max) {
      throw FormatException(
        'Backup expands past the $_max bytes this will decompress',
      );
    }
    _out.add(chunk);
  }

  @override
  void close() {}
}
