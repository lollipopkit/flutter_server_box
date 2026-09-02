# Retirement & Migration Residue Tracker

This document tracks every `TODO` that exists as intentional migration residue. It is the single source of truth for when each shim can be deleted. No shim is removed without updating this file and bumping `SchemaVersion` where applicable.

> **Rule:** See `lib/data/store/schema.dart` and `lib/data/store/migrations/all.dart`. A schema step is three edits: model, `SchemaVersion.current`, and `kSchemaMigrations`. Testing `apply()` directly never proves the other two. See `CLAUDE.md` for details.

## Hive (keep per Q1)

Data has been on SQLite since before `1.0.1538`. However upgrades from `1466`/`1480`/`1491` and earlier still rely on `HiveImport`. Fixtures under `test/fixtures/hive_v{1466,1480,1491}/` and `test/hive_release_migration_test.dart` guard this path. **Do not delete `lib/hive/` or `hive_ce` dependencies until `SchemaVersion.oldestSupported` is advanced past the Hive era and fixtures confirm no install can still carry a Hive box.**

| Area | File:Line | Since | Retire when | Notes |
|---|---|---|---|---|
| Hive bootstrap | `lib/main.dart:109` | m003 | no install predates HiveImport | `Hive.initFlutter`, `registerHiveLegacyAdapters`, `Hive.close`, `lib/hive/*` + `hive_ce*` deps |
| Hive adapters | `lib/hive/legacy_adapters.dart:27` | m003 | with Hive bootstrap | frozen adapters; never regenerate |
| Hive SPI legacy | `lib/hive/spi_legacy_adapter.dart:70` | m004 | with `SpiNestSshMigration` | `Spi` nesting |
| Hive → SQLite migration | `lib/data/store/migrations/m003_hive_to_sqlite.dart:18` | m003 | with Hive bootstrap | |
| Schema bump guard | `lib/data/store/schema.dart:156` | m003 | with HiveImport | `TODO` there |

## v2 compatibility shims

| File:Line | Since | Retire when | Notes |
|---|---|---|---|
| `lib/core/sync.dart:143` | v2 | no v2 backup can still be imported | `BakSyncer` + `lib/data/res/misc.dart:24`, `lib/data/model/app/bak/*` |
| `lib/data/res/misc.dart:24` | v2 | with sync.dart | |
| `lib/main.dart:85` | v2 | no backup holds legacy name | `BakSyncer.inheritLegacyRemote` |

## ServerCustom `cmds` / `withoutCmds`

`custom.dart` keeps `cmds` (CSV) alongside the normalized child table. One full release after the table is the only store of truth can it go.

| File:Line | Since | Retire when | Notes |
|---|---|---|---|
| `lib/data/model/server/custom.dart:19,50` | m004 ext | next major after 1.0.1538 | `withoutCmds`/`cmds` fields |
| `lib/data/provider/server/single.dart:640` | m004 ext | with custom.dart | fallback read |
| `lib/view/page/server/edit/edit.dart:152` | m004 ext | with custom.dart | editor write path |

## Settings — retired keys swept by `removeRetiredKeys`

`SettingStore.removeRetiredKeys` (`lib/data/store/setting.dart:516,775`) is the sweeper. Each entry has a paired migration.

| Key / File:Line | Migration | Retire when |
|---|---|---|
| `watchServerIds` `lib/data/store/setting.dart:230` | `m015_watch_selection_to_exclusion.dart:25` | one release after exclusion shipped |
| `legacyStatusUrls` `lib/data/store/setting.dart:256` | `m016_legacy_status_urls.dart` | one release after 410 dialog shipped |
| `schemaVersion` kv `lib/data/store/setting.dart:516` | — | when no install can hold stale `fgService` row |
| `fgService` stale row `lib/data/store/setting.dart:628` | — | swept, harmless |
| string branch `sshVirtKeys` `lib/data/store/setting.dart:587` | `m011_virt_key_rows.dart:11` + `m013_virt_key_names` | after rows migration |
| flag reads `lib/data/store/setting.dart:802` | `m008_settings_fixups.dart:38,69,72` | with SettingsFixups |
| virtKeyRows read `lib/data/store/setting.dart:818` | `m011_virt_key_rows.dart:11` | with VirtKeyRows |

## known_host table

| File:Line | Migration | Retire when |
|---|---|---|
| `lib/data/store/server.dart:435` + `lib/data/store/migrations/m004_kv_to_tables.dart:437` + `m012_known_hosts_to_settings.dart:25` | m012 | no install can carry `known_host` table |

## Home / history / tabs

| File:Line | Since | Retire when |
|---|---|---|
| `lib/data/store/history.dart:152` `homeTabIndex` | m010 | `lib/view/page/home.dart:161` |
| `lib/data/ssh/terminal_source.dart:104` / `lib/view/page/ssh/tab.dart:467` / `lib/view/page/storage/tab.dart:433` tab profiles | profile migration | no saved tab set predates profiles |

## Scripts / platform

| File:Line | Since | Retire when |
|---|---|---|
| `lib/data/model/app/scripts/cmd_types.dart:28` enum sync | sbm_parser share | when Dart enum generated from `sbm_parser` |
| `lib/data/model/app/scripts/script_consts.dart:7` | script share | when `ScriptConstants` derived from `crates/sbm_parser` |
| `lib/data/model/app/linux_distro.dart:284` | — | after three-line `/etc/os-release` trim |
| `lib/data/model/app/server_detail_card.dart:83` | — | after card `ks` names stabilized |
| `lib/core/utils/ios_rootfs.dart:818` | container | no install predates container |
| `lib/core/utils/local_files.dart:23` | — | no install still writes old paths |
| `lib/main.dart:103` `extended_image_library` folder | upstream | when library creates folder recursively |
| `lib/view/page/storage/file_browser.dart:724` sudo rescue | SFTP sudo | when escalatePath decided |
| `lib/view/page/setting/entries/app.dart:470` raw settings edit | — | decide intentionality |

## How to retire

1. Confirm `test/hive_release_migration_test.dart` + `test/fixtures/*` expectation.
2. Bump `SchemaVersion.current` in `lib/data/store/schema.dart` and add entry in `lib/data/store/migrations/all.dart`.
3. Remove code + update this file (move row to `Retired` below).
4. `dart run build_runner build --delete-conflicting-outputs` if models changed, `flutter gen-l10n` if ARB touched, `flutter analyze`, `cargo test --workspace`, `flutter test --timeout 30s`.
5. One PR per retirement.

## Retired (append here)

| Date | Item | PR |
|---|---|---|
| 2026-09-02 | 6 unused ARB keys (`distIconConsent` etc.) | opt/codebase-cleanup-1553 batch 0 |
