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
import 'package:server_box/data/store/migrations/m018_server_geo.dart';
import 'package:server_box/data/store/migrations/m019_drop_geo_cache.dart';
import 'package:server_box/data/store/migrations/m020_benchmark_runs.dart';
import 'package:server_box/data/store/migrations/m021_home_tabs_bar.dart';
import 'package:server_box/data/store/migrations/m022_ai_endpoint_version.dart';
import 'package:server_box/data/store/migrations/m023_enum_names.dart';
import 'package:server_box/data/store/migrations/m024_remote_desktop_profiles.dart';
import 'package:server_box/data/store/migrations/m025_transport_switches.dart';
import 'package:server_box/data/store/migrations/m026_ssh_legacy_algorithms.dart';
import 'package:server_box/data/store/migrations/m027_drop_ssh_server_history.dart';
import 'package:server_box/data/store/migrations/m028_local_server.dart';
import 'package:server_box/data/store/migrations/m029_drop_theme_store_url.dart';
import 'package:server_box/data/store/migrations/m030_pve_virt.dart';
import 'package:server_box/data/store/migrations/m031_drop_agent_conversations.dart';
import 'package:server_box/data/store/migrations/m032_disk_counts_network.dart';
import 'package:server_box/data/store/migrations/m033_sync_record.dart';
import 'package:server_box/data/store/migrations/m034_identity_files.dart';
import 'package:server_box/data/store/migrations/m035_monitor_cert_sha256.dart';
import 'package:server_box/data/store/migrations/m036_drop_server_custom_cmd.dart';
import 'package:server_box/data/store/migrations/m037_drop_tab_sessions.dart';
import 'package:server_box/data/store/migrations/m038_sync_all.dart';
import 'package:server_box/data/store/migrations/m039_ssh_identity_agent.dart';
import 'package:server_box/data/store/migrations/m040_ssh_forward_agent.dart';
import 'package:server_box/data/store/migrations/m041_ssh_control_path.dart';
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
  ServerGeoMigration(),
  DropGeoCacheMigration(),
  BenchmarkRunsMigration(),
  HomeTabsBarMigration(),
  AiEndpointVersionMigration(),
  EnumNamesMigration(),
  RemoteDesktopProfilesMigration(),
  TransportSwitchesMigration(),
  SshLegacyAlgorithmsMigration(),
  DropSshServerHistoryMigration(),
  LocalServerMigration(),
  DropThemeStoreUrlMigration(),
  PveVirtMigration(),
  DropAgentConversationsMigration(),
  DiskCountsNetworkMigration(),
  SyncRecordMigration(),
  IdentityFilesMigration(),
  MonitorCertSha256Migration(),
  DropServerCustomCmdMigration(),
  DropTabSessionsMigration(),
  SyncAllMigration(),
  SshIdentityAgentMigration(),
  SshForwardAgentMigration(),
  SshControlPathMigration(),
];

/// The steps a restore runs on the settings it brought back, in schema order.
///
/// A restore is neither a launch nor a version bump, so the migrator never
/// looks at a file older than this install: each listed step converts a shape
/// such a file can still carry.
///
/// Not listed:
/// - `EnumNamesMigration` (m023): every read of those rows takes either shape.
/// - m012, m016, m030: their input is a table or this device's preferences,
///   which no backup carries.
/// - m015: a newer file still carries the selection it converted, so running
///   it there would overwrite the exclusions that file restored.
const kRestoreSettingsMigrations = <SettingsMigration>[
  // An `int` `sshConnectionMode` and the flag-gated Agent home tab.
  SettingsFixupsMigration(),
  // The per-field keys from before the grouped settings.
  GroupedSettingsMigration(),
  // The switch from before `virtualKeyRows`.
  VirtKeyRowsMigration(),
  // Virtual keys stored by index.
  VirtKeyNamesMigration(),
  // The five-tab home bar of older builds.
  HomeTabsBarMigration(),
  // An `askAi.baseUrl` without its API version, which `LegacyAskAiMigration`
  // turns into a provider at the next launch that then answers 404.
  AiEndpointVersionMigration(),
];

/// The [kRestoreSettingsMigrations] a file written at schema [fileVersion]
/// still needs. A file written after a step already has its shape, and the
/// step's match would misread a current value: m021 takes any bar of exactly
/// the old five tabs for the old default.
Iterable<SettingsMigration> restoreSettingsMigrationsFor(int fileVersion) =>
    kRestoreSettingsMigrations.where((step) => fileVersion <= step.from);
