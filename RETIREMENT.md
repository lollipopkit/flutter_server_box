# Retirement & Migration Residue Tracker

This document tracks every `TODO` that exists as intentional migration residue. It is the single source of truth for when each shim can be deleted. No shim is removed without updating this file and bumping `SchemaVersion` where applicable.

> **Rule:** See `lib/data/store/schema.dart` and `lib/data/store/migrations/all.dart`. A schema step is three edits: model, `SchemaVersion.current`, and `kSchemaMigrations`. Testing `apply()` directly never proves the other two. See `CLAUDE.md` for details.

Locations name the file and the symbol a retirement touches. Line numbers are deliberately absent: they drift with every unrelated edit and a stale pointer is worse than none.

## Hive (keep per Q1)

Data has been on SQLite since before `1.0.1538`. However upgrades from `1466`/`1480`/`1491` and earlier still rely on `HiveImport`. Fixtures under `test/fixtures/hive_v{1466,1480,1491}/` and `test/migration/hive_release_migration_test.dart` guard this path. **Do not delete `lib/hive/` or `hive_ce` dependencies until `SchemaVersion.oldestSupported` is advanced past the Hive era and fixtures confirm no install can still carry a Hive box.**

| Area | Location | Since | Retire when | Notes |
|---|---|---|---|---|
| Hive bootstrap | `lib/main.dart` (`Hive.initFlutter`, `registerHiveLegacyAdapters`, `Hive.close`) | m003 | no install predates HiveImport | `lib/hive/*` + `hive_ce*` deps |
| Hive adapters | `lib/hive/legacy_adapters.dart` (`registerHiveLegacyAdapters`, frozen `Legacy*V1` types) | m003 | with Hive bootstrap | frozen adapters; never regenerate |
| Hive SPI legacy | `lib/hive/spi_legacy_adapter.dart` (`SpiLegacyAdapter`, `SpiNestedLegacyAdapter`) | m004 | with `SpiNestSshMigration` | `Spi` nesting |
| Hive → SQLite migration | `lib/data/store/migrations/m003_hive_to_sqlite.dart` (`HiveImport`) | m003 | with Hive bootstrap | |
| Schema bump guard | `lib/data/store/schema.dart` (`SchemaVersion`) | m003 | with HiveImport | `TODO` there |

## v2 compatibility shims

| Location | Since | Retire when | Notes |
|---|---|---|---|
| `lib/core/sync.dart` (`BakSyncer`, `inheritLegacyRemote`) | v2 | no v2 backup can still be imported | `lib/data/res/misc.dart`, `lib/data/model/app/bak/*` |
| `lib/data/res/misc.dart` (`TODO`) | v2 | with sync.dart | |
| `lib/main.dart` (`BakSyncer.inheritLegacyRemote` call) | v2 | no backup holds legacy name | |

## ServerCustom `cmds` / `withoutCmds`

`custom.dart` keeps `cmds` (CSV) alongside the normalized child table. One full release after the table is the only store of truth can it go.

| Location | Since | Retire when | Notes |
|---|---|---|---|
| `lib/data/model/server/custom.dart` (`cmds`, `withoutCmds`) | m004 ext | next major after 1.0.1538 | |
| `lib/data/provider/server/single.dart` (`IndividualServerNotifier._migrateCustomCmds`) | m004 ext | with custom.dart | fallback read |
| `lib/view/page/server/edit/edit.dart` (`ServerEditPage`) | m004 ext | with custom.dart | editor write path |

## Settings — retired keys swept by `removeRetiredKeys`

`SettingStore.removeRetiredKeys` (`lib/data/store/setting.dart`) is the sweeper. Each entry has a paired migration.

| Key / Location | Migration | Retire when |
|---|---|---|
| `watchServerIds` `lib/data/store/setting.dart` (`SettingStore.watchServerIds`) | `m015_watch_selection_to_exclusion.dart` | one release after exclusion shipped |
| `legacyStatusUrls` `lib/data/store/setting.dart` | `m016_legacy_status_urls.dart` | one release after 410 dialog shipped |
| `schemaVersion` kv `lib/data/store/setting.dart` | — | when no install can hold stale `fgService` row |
| `fgService` stale row `lib/data/store/setting.dart` | — | swept, harmless |
| string branch `sshVirtKeys` `lib/data/store/setting.dart` | `m011_virt_key_rows.dart` + `m013_virt_key_names.dart` | after rows migration |
| flag reads `lib/data/store/setting.dart` | `m008_settings_fixups.dart` | with SettingsFixups |
| virtKeyRows read `lib/data/store/setting.dart` | `m011_virt_key_rows.dart` | with VirtKeyRows |

## known_host table

| Location | Migration | Retire when |
|---|---|---|
| `lib/data/store/server.dart` (legacy `known_host` table) + `lib/data/store/migrations/m004_kv_to_tables.dart` + `lib/data/store/migrations/m012_known_hosts_to_settings.dart` | m012 | no install can carry `known_host` table |

## Home / history / tabs

| Location | Since | Retire when |
|---|---|---|
| `lib/data/store/history.dart` (`homeTabIndex`) | m010 | `lib/view/page/home.dart` |
| `lib/data/ssh/terminal_source.dart` / `lib/view/page/ssh/tab.dart` / `lib/view/page/storage/tab.dart` (tab profiles) | profile migration | no saved tab set predates profiles |

## Scripts / platform

| Location | Since | Retire when |
|---|---|---|
| `lib/data/model/app/scripts/cmd_types.dart` enum sync | sbm_parser share | when Dart enum generated from `sbm_parser` |
| `lib/data/model/app/scripts/script_consts.dart` (`ScriptConstants`) | script share | when `ScriptConstants` derived from `crates/sbm_parser` |
| `lib/data/model/app/linux_distro.dart` | — | after three-line `/etc/os-release` trim |
| `lib/data/model/app/server_detail_card.dart` | — | after card `ks` names stabilized |
| `lib/core/utils/ios_rootfs.dart` | container | no install predates container |
| `lib/core/utils/local_files.dart` | — | no install still writes old paths |
| `lib/main.dart` (`extended_image_library` folder) | upstream | when library creates folder recursively |
| `lib/view/page/storage/file_browser.dart` sudo rescue | SFTP sudo | when escalatePath decided |
| `lib/view/page/setting/entries/app.dart` raw settings edit | — | decide intentionality |

## How to retire

1. **Hive retirements only:** Confirm `test/migration/hive_release_migration_test.dart` + `test/fixtures/*` expectation. Other retirements skip this.
2. **Persisted-schema changes only:** Bump `SchemaVersion.current` in `lib/data/store/schema.dart` and add entry in `lib/data/store/migrations/all.dart`. ARB, platform, and code-only retirements skip this — no schema step needed.
3. Remove code + update this file (move row to `Retired` below).
4. Run the checks that match the change: `dart run build_runner build` if models changed, `flutter gen-l10n` if ARB touched, `flutter analyze`, `cargo test --workspace` if Rust changed, `flutter test --timeout 30s` (always).
5. One PR per retirement.

## Retired (append here)

| Date | Item | PR |
|---|---|---|
| 2026-09-02 | 6 unused ARB keys (`distIconConsent` etc.) | opt/codebase-cleanup-1553 batch 0 |
