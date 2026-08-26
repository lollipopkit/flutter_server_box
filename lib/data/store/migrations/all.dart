import 'package:server_box/data/store/migrations/m004_kv_to_tables.dart';
import 'package:server_box/data/store/migrations/m005_monitor_insecure_http.dart';
import 'package:server_box/data/store/migrations/m006_bmc_columns.dart';
import 'package:server_box/data/store/migrations/m007_private_key_comment.dart';
import 'package:server_box/data/store/migrations/m008_settings_fixups.dart';
import 'package:server_box/data/store/migrations/m009_grouped_settings.dart';
import 'package:server_box/data/store/migrations/m010_server_dist.dart';
import 'package:server_box/data/store/migrations/m011_virt_key_rows.dart';
import 'package:server_box/data/store/migrations/m012_known_hosts_to_settings.dart';
import 'package:server_box/data/store/migrations/m013_virt_key_names.dart';
import 'package:server_box/data/store/migrations/m014_ssh_file_transport.dart';
import 'package:server_box/data/store/migrations/m015_watch_selection_to_exclusion.dart';
import 'package:server_box/data/store/migrations/m016_legacy_status_urls.dart';
import 'package:server_box/data/store/migrations/m017_both_transports.dart';
import 'package:server_box/data/store/schema.dart';

/// Every migration, ordered, in the one place that names them.
///
/// `main.dart` and the migration tests both drive the chain, and each used to
/// carry its own copy of the list. A step added to only one of them is a
/// launch that throws `Missing schema migration from vN`, or a test asserting
/// a shape no install is ever in — and which of the two you get depends on
/// which copy was forgotten. There is nothing to forget with one list.
class _NoopMigration implements SchemaMigration {
  const _NoopMigration(this.from);
  @override
  final int from;
  @override
  Future<void> apply() async {}
}

const kSchemaMigrations = <SchemaMigration>[
  _NoopMigration(2),
  _NoopMigration(3),
  KvToTablesMigration(),
  MonitorInsecureHttpMigration(),
  BmcColumnsMigration(),
  PrivateKeyCommentMigration(),
  SettingsFixupsMigration(),
  GroupedSettingsMigration(),
  ServerDistMigration(),
  VirtKeyRowsMigration(),
  KnownHostsToSettingsMigration(),
  VirtKeyNamesMigration(),
  SshFileTransportMigration(),
  WatchSelectionToExclusionMigration(),
  LegacyStatusUrlsMigration(),
  BothTransportsMigration(),
];
