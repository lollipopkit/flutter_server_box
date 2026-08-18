import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';

part 'backup.g.dart';

const backupFormatVersion = 1;

final _logger = Logger('Backup');

@JsonSerializable()
class Backup implements Mergeable {
  // backup format version
  final int version;
  final String date;
  final List<Spi> spis;
  final List<Snippet> snippets;
  final List<PrivateKeyInfo> keys;
  final Map<String, dynamic> container;
  final Map<String, dynamic> history;
  final int? lastModTime;
  final Map<String, dynamic>? settings;

  const Backup({
    required this.version,
    required this.date,
    required this.spis,
    required this.snippets,
    required this.keys,
    required this.container,
    required this.history,
    required this.settings,
    this.lastModTime,
  });

  factory Backup.fromJson(Map<String, dynamic> json) => _$BackupFromJson(json);

  Map<String, dynamic> toJson() => _$BackupToJson(this);

  static Future<Backup> loadFromStore() async {
    final lastModTime = Stores.lastModTime;
    return Backup(
      version: backupFormatVersion,
      date: DateTime.now().toString().split('.').firstOrNull ?? '',
      spis: Stores.server.fetch(),
      snippets: Stores.snippet.fetch(),
      keys: Stores.key.fetch(),
      container: Stores.container.getAllMap(),
      lastModTime: lastModTime,
      history: Stores.history.getAllMap(),
      settings: Stores.setting.getAllMap(),
    );
  }

  static Future<String> backup([String? name]) async {
    final bak = await Backup.loadFromStore();
    final result = _diyEncrypt(json.encode(bak.toJson()));
    final path = Paths.doc.joinPath(name ?? Miscs.bakFileName);
    await File(path).writeAsString(result);
    return path;
  }

  @override
  Future<void> merge({bool force = false}) async {
    final curTime = Stores.lastModTime;
    final bakTime = lastModTime ?? 0;
    final shouldRestore = force || curTime < bakTime;
    if (!shouldRestore) {
      _logger.info('No need to restore, local is newer');
      return;
    }

    _restoreInto(
      Stores.snippet,
      {for (final s in snippets) s.name: s},
      force: force,
    );
    _restoreInto(Stores.server, {for (final s in spis) s.id: s}, force: force);
    _restoreInto(Stores.key, {for (final s in keys) s.id: s}, force: force);
    _restoreInto(Stores.history, history, force: force);
    _restoreInto(Stores.container, container, force: force);

    final settings_ = settings;
    if (settings_ != null) {
      _restoreInto(Stores.setting, settings_, force: force);
    }

    Provider.reload();
    RNodes.app.notify();

    _logger.info('Restore success');
  }

  factory Backup.fromJsonString(String raw) =>
      Backup.fromJson(json.decode(_diyDecrypt(raw)));
}

/// Writes one section of a backup into the store it came from.
///
/// [force] replaces what is there; otherwise the store is also made to *stop*
/// holding whatever the backup does not, which is what makes a delete on one
/// device reach another.
///
/// Nothing here stamps `lastUpdateTs`, which is what writing straight to the
/// Hive box used to achieve. A restore is not an edit: marking every restored
/// key as changed now would leave the merged copy looking newer than the backup
/// it came from, and the next sync would push it straight back out.
///
/// Uses `keys()` rather than every key in the store, so the internal
/// `lastUpdateTs` entry is not one of the ones deleted for being absent from
/// the backup — `getAllMap` leaves it out of the backup by the same rule, so
/// the box-level version deleted it on every non-forced merge.
void _restoreInto(
  SqliteStore store,
  Map<String, Object?> incoming, {
  required bool force,
}) {
  if (!force) {
    for (final key in store.keys().difference(incoming.keys.toSet())) {
      store.remove(key, updateLastUpdateTsOnRemove: false);
    }
  }
  for (final entry in incoming.entries) {
    final value = entry.value;
    if (value == null) {
      store.remove(entry.key, updateLastUpdateTsOnRemove: false);
      continue;
    }
    store.set(entry.key, value, updateLastUpdateTsOnSet: false);
  }
}

String _diyEncrypt(String raw) =>
    json.encode(raw.codeUnits.map((e) => e * 2 + 1).toList(growable: false));

String _diyDecrypt(String raw) {
  try {
    final list = json.decode(raw);
    final sb = StringBuffer();
    for (final e in list) {
      sb.writeCharCode((e - 1) ~/ 2);
    }
    return sb.toString();
  } catch (e, trace) {
    Loggers.app.warning('Backup decrypt failed', e, trace);
    rethrow;
  }
}
