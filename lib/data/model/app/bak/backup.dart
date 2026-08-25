import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:server_box/core/utils/ssh_key_unlock.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/migrations/m008_settings_fixups.dart';
import 'package:server_box/data/store/migrations/m009_grouped_settings.dart';
import 'package:server_box/data/store/migrations/m011_virt_key_rows.dart';
import 'package:server_box/data/store/migrations/m013_virt_key_names.dart';
import 'package:server_box/data/store/setting.dart';

part 'backup.g.dart';

final _logger = Logger('Backup');

/// The first backup format, kept for reading only.
///
/// The app writes [BackupV2]; this exists so a file from a build old enough to
/// have written it can still be restored. It carries one timestamp for the
/// whole file rather than one per record, which is why a merge here can only
/// take or leave each store whole.
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

  @override
  Future<void> merge({bool force = false}) async {
    final curTime = Stores.lastModTime;
    final bakTime = lastModTime ?? 0;
    final shouldRestore = force || curTime < bakTime;
    if (!shouldRestore) {
      _logger.info('No need to restore, local is newer');
      return;
    }

    // One transaction for the whole merge. Per-key commits would leave a
    // restore that was interrupted — process killed, device out of battery —
    // with servers deleted whose replacements were never written, and no way to
    // tell that had happened.
    //
    // Whole stores rather than per record: this format carries one timestamp
    // for the entire file, so there is nothing to compare a single record
    // against. Ordered by what references what — a server names a private key,
    // and a snippet names a server.
    // Every stored key is about to be replaced by whatever the file holds, so
    // nothing opened this run describes what is in the database any more. A
    // stale entry here is not a stale display — it is a connection that goes on
    // authenticating with the key the restore just removed.
    PrivateKeyUnlock.forgetAll();

    final settings_ = settings;

    SqliteStore.transact(() {
      Stores.key.replaceAll(keys);
      Stores.server.replaceAll(spis);
      Stores.snippet.replaceAll(snippets);
      Stores.container.restoreLegacyMap(container);
      _restoreInto(Stores.history, history);

      if (settings_ != null) {
        _restoreInto(
          Stores.setting,
          settings_,
          deviceLocal: SettingStore.deviceLocalKeys,
        );
      }
    });

    // Outside the transaction, and for the reason the v2 path does it too: a
    // restore is neither a launch nor a version bump, so nothing else will
    // look at what just landed. This format predates the grouped settings
    // entirely, so its settings map is always the old per-field keys — and,
    // being older still, the pre-`virtKeyRows` switch and the `int`
    // `sshConnectionMode` as well.
    //
    // Only when the file brought settings, for the reason [BackupV2.merge]
    // records: these convert what arrived, and a file carrying none leaves the
    // local settings alone.
    //
    // In version order, which is the order the migrator would have run them in.
    if (settings_ != null && settings_.isNotEmpty) {
      await const SettingsFixupsMigration().apply();
      await const GroupedSettingsMigration().apply();
      await const VirtKeyRowsMigration().apply();
      await const VirtKeyNamesMigration().apply();
    }

    Provider.reload();
    RNodes.app.notify();

    _logger.info('Restore success');
  }

  factory Backup.fromJsonString(String raw) =>
      Backup.fromJson(json.decode(_diyDecrypt(raw)));
}

/// Writes one section of a backup into the key-value store it came from.
///
/// The store is also made to *stop* holding whatever the backup does not,
/// which is what makes a delete on one device reach another. Unconditionally,
/// including on a forced restore: `Mergeable.mergeStore` — the v2 path — takes
/// a local-only key out when `force` is set, and skipping it here left a
/// forced restore of an older file holding preferences that file does not
/// have, which is not the state the user asked to go back to.
///
/// [deviceLocal] names keys this device answers for itself; they are neither
/// written from the backup nor deleted for being absent from one. See
/// [SettingStore.deviceLocalKeys].
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
  Set<String> deviceLocal = const {},
}) {
  for (final key in store.keys().difference(incoming.keys.toSet())) {
    if (deviceLocal.contains(key)) continue;
    store.remove(key, updateLastUpdateTsOnRemove: false);
  }
  for (final entry in incoming.entries) {
    if (deviceLocal.contains(entry.key)) continue;
    final value = entry.value;
    if (value == null) {
      store.remove(entry.key, updateLastUpdateTsOnRemove: false);
      continue;
    }
    store.set(entry.key, value, updateLastUpdateTsOnSet: false);
  }
}

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
