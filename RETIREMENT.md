# Migration residue

Every retirement that has to wait for installs to age out, in one place, so a
shim is not deleted while a supported install still needs it.

**This file is an index, not the record.** Each entry's reasoning and its exact
condition live in the `TODO` beside the code, and that is where to read before
retiring anything. What this adds is the one thing no single file can: the
whole set, so a release that advances `SchemaVersion.oldestSupported` or the
oldest supported Hive release can find everything that changes with it.

Entries name a file and a symbol. No line numbers: they drift with every
unrelated edit, and a stale pointer is worse than none.

## The rules

- **A schema step is three edits**: the migration class, `SchemaVersion.current`,
  and `kSchemaMigrations` (`lib/data/store/migrations/all.dart`). Missing the
  second leaves every install on the old version with a green suite; missing the
  third throws `Missing schema migration from vN` at launch. Neither shows up in
  the step's own test, which calls `apply()` directly. See `CLAUDE.md`.
- **Never regenerate a fixture.** `test/fixtures/hive_v{1466,1480,1491}/` and
  `test/fixtures/rootfs_manifest/` are bytes a release actually wrote. Rewriting
  one to make a test pass proves only that today's code agrees with itself.
- **Hive retirements additionally** need `test/migration/hive_release_migration_test.dart`
  to pass against those fixtures. Code-only retirements do not.

## Hive

Data has been on SQLite since before `1.0.1538`, but upgrades from `1466`,
`1480`, `1491` and earlier still run `HiveImport`. Nothing here goes until
`SchemaVersion.oldestSupported` is past the Hive era *and* the fixtures confirm
no install can still carry a box.

| Location | Since | Retire with |
|---|---|---|
| `lib/main.dart` — `Hive.initFlutter`, `registerHiveLegacyAdapters`, `Hive.close` | m003 | `HiveImport` |
| `lib/hive/legacy_adapters.dart` — `registerHiveLegacyAdapters`, frozen `Legacy*V1` | m003 | the Hive bootstrap. Never regenerate these |
| `lib/hive/spi_legacy_adapter.dart` — `SpiLegacyAdapter`, `SpiNestedLegacyAdapter`, `LegacySpiV2` | m004 | the Hive bootstrap |
| `lib/data/store/migrations/m003_hive_to_sqlite.dart` — `HiveImport` | m003 | the Hive bootstrap |
| `lib/data/store/schema.dart` — `hiveImportProduces` | m003 | `HiveImport`; bump it in step until then |
| `lib/core/utils/db_rescue.dart` — the box sweep | m003 | `HiveImport` |
| `hive_ce*` dependencies in `pubspec.yaml` | m003 | the Hive bootstrap |

## v2 backups

| Location | Retire when |
|---|---|
| `lib/core/sync.dart` — `BakSyncer.saveToFile`, `BakSyncer.fromFile` | no v2 backup can still be imported |
| `lib/core/sync.dart` — `inheritLegacyRemote` | no v2 backup can still be imported |
| `lib/data/res/misc.dart` — `legacyBakFileName` | with `inheritLegacyRemote` |
| `lib/main.dart` — the legacy backup-file name passed to `Paths.init` | with `inheritLegacyRemote` |

## `ServerCustom.cmds`

`custom.dart` carries `cmds` (CSV) alongside the normalized child table, and the
table becomes the only store of truth one full release after it ships.

| Location | Retire with |
|---|---|
| `lib/data/model/server/custom.dart` — `cmds`, `withoutCmds` | the table alone |
| `lib/data/provider/server/single.dart` — `_migrateCustomCmds` | `custom.dart` |
| `lib/view/page/server/edit/edit.dart` — `_unmigratedCmds` | `custom.dart` |

## Retired setting keys

`SettingStore.removeRetiredKeys` (`lib/data/store/setting.dart`) is the sweeper;
each entry has a paired migration that stopped writing the key. The sweep is
gated on the stored schema version, so a key can only be dropped once no install
below that version remains.

| Key | Migration | Retire with |
|---|---|---|
| `watchServerIds` | m015 | `WatchSelectionToExclusionMigration` |
| `watchLegacyUrls` | m016 | `LegacyStatusUrlsMigration` |
| `sshConnectionModeMigrated`, `homeTabsAgentMigrated` | m008 | the flag reads in `SettingsFixupsMigration` |
| `virtKeyRows` (string branch) | m011, m013 | the read in `VirtKeyRowsMigration` |
| `schemaVersion` (plain key) | — | when no install can hold the pre-prefix copy |
| `fgService` | — | swept, harmless; no reader |
| `showDistMark` (old key) | — | unread; nothing looks at it |

## Entity tables that no longer have a writer

| Location | Retire when |
|---|---|
| `lib/data/store/db.dart` — `known_host` table | no install can still carry rows; `m004_kv_to_tables.dart` and `m012_known_hosts_to_settings.dart` are the only readers |

## Tabs and history

| Location | Retire when |
|---|---|
| `lib/data/store/history.dart` — `homeTabIndex` | no install can carry one; `lib/view/page/home.dart` reads it once on upgrade |
| `lib/data/model/app/tab.dart` — `_retiredIndices` | no stored tab order can hold index 7 |
| `lib/view/page/storage/tab.dart` — the `serverId == null` fallback | no saved tab set predates the `kind` field |
| `lib/data/ssh/terminal_source.dart` — `rootfsId`'s `alpine` spelling | no saved tab set predates profiles |
| `lib/view/page/ssh/tab.dart` — the `serverId` fallback | no saved tab set predates `sourceId` |

## Deferred for other reasons

These are not waiting on installs. Each has its own condition in the code.

| Location | Condition |
|---|---|
| `lib/data/model/app/scripts/cmd_types.dart` — enum/`sbm_parser` sync | Dart enum generated from `sbm_parser` |
| `lib/data/model/app/scripts/script_consts.dart` — `ScriptConstants` | derived from `crates/sbm_parser` |
| `lib/data/model/app/linux_distro.dart` — short marker forms | three-line `/etc/os-release` trim crosses every supported install |
| `lib/data/model/app/bak/backup2.dart` — `compressBackups` | no supported build predates compression |
| `lib/core/utils/ios_rootfs.dart` — the old `alpine/` tree | no install predates the container |
| `lib/core/utils/local_files.dart` — legacy `Paths` locations | no install still writes them |
| `lib/core/utils/server_share.dart` — `findExisting` | `Spi.isSameAs` grows an identity covering both transports |
| `lib/main.dart` — the `extended_image_library` temp folder | the library creates it recursively |
| `lib/view/page/storage/file_browser.dart` — escalating an empty-file create | a way to escalate a write is worked out |
| `lib/view/page/setting/entries/app.dart` — raw settings edit | whether the timestamp behaviour was intentional |
| `lib/view/page/user_detail.dart` — `authorized_keys` | the file editor is reachable outside the browser |

## How to retire

1. Read the `TODO` beside the code for what actually gates it.
2. If a persisted shape changes, do the three edits above and bump
   `SchemaVersion.current`.
3. Remove the code and its row here.
4. Run what the change touched: `dart run build_runner build` for models,
   `flutter gen-l10n` for ARB, `flutter analyze`, `flutter test --timeout 30s`,
   and `cargo test --workspace` for Rust.
5. One retirement per PR.
