# Code health audit — September 2026

Scope: first-party code in the main repository, based on `origin/main` at `ccf716cd`. Submodules and gitlinks are unchanged. Database schema versions, historical data readers, signed release fixtures, HTTP response fields, FFI contracts, SSH authentication and supported platforms are preserved.

## Batches delivered

| Batch | Changes and evidence |
| --- | --- |
| Test baseline | Preserve signed JSON as LF and signature bytes as binary; replace permission-dependent `chmod` with a test filesystem override; drain asynchronous database writes before teardown. No signatures were regenerated and verification was not relaxed. |
| Logic and resource limits | Drain exec stdin/stdout/stderr concurrently while retaining at most cap + one lookahead byte per output; bind frontend 401 handling to server ID, URL and token snapshots; quote SQLite identifiers during rescue exports. Regression tests exercise large stdin plus both output streams, stale sessions and quoted names. |
| Dead code | Remove unused terminal, container and server operations, connection-history wrapper, singular key parsers, output-buffer drain wrapper, obsolete known-host APIs, ID alias cache, staging-name predicate and ticket consume wrappers. Preserve persisted history updates, tab renames, migration tables and reserve/commit/rollback behavior. |
| Production test hooks | Remove model-table load/adopt/reset methods, AI tool parser wrapper, geography network factory/DNS mutation/reset, globe cache reset, native pending-crash forgetting, rescue-share substitution, migration store overrides, preference write override and decompression cap override. Tests use normal service instances, real storage paths, platform boundaries and local HTTP servers. |
| Performance | Sweep large login throttle maps at most once per minute; close model/manifest HTTP clients; bound manifest connections to 20 seconds; share the 60-second transfer timeout floor; remove duplicate logout persistence; run pure frontend suites in Node. |
| Coverage and tests | Cover model cache/asset loading, invalid cache metadata, refresh coalescing/failure/persistence/disposal, SFTP read failure/cancellation/late-open cleanup, Monitor roots retry/shared disposal/truncated download, and SSH shutdown during channel opening or stream failure. Replace Android source-string assertions with executable policy/channel tests. |

## Deletion checks

Before removing APIs, check main-repository call sites, generated references, overrides, platform entry points, FFI and build references. The remaining `visibleForTesting` annotations do not imply a test-only API: parsers, command builders, payload builders and dependency interfaces that production actually calls remain.

- Old `known_hosts` rows are prepared directly in migration tests. The legacy schema and migrations remain; current host trust still uses settings.
- Connection statistics tests read the production summary; the retention bound is checked against persisted rows.
- Test table-name constants moved to `test/helpers/table_names.dart`; production table creation remains.
- Stateful services use the same constructors and operations in production and tests. HTTP/IO fakes live in `test/helpers/`; no replacement `ForTest` branch was added.
- The transfer worker now receives its real worker from its production owner, with the same dependency interface used by tests.
- Rust-only private test helpers stay behind `#[cfg(test)]` and do not ship in release builds.
- Historical Hive and rootfs fixtures, cryptographic differential tests and manifest/entitlement contract tests remain.

## Measured performance and resource bounds

Measurements below are local Windows debug/test runs, not release performance guarantees.

| Workload | Before | After |
| --- | --- | --- |
| 10,000 rotating login usernames, same Rust regression workload | 1.647 s | 30.1 ms |
| Same 81 frontend tests | 39.29 s | 33.56 s |
| Exec retained output per stream | Entire output before truncation | Configured cap + 1 byte, plus an 8 KiB read buffer |
| Model/manifest refresh clients | Not explicitly closed | Closed on success and failure; tests count created/closed clients |

The frontend timings are single comparable runs and remain sensitive to CPU contention and transform caches. Browser suites retain isolation. Login sweeps preserve live reservations, per-key TTL reset and existing exponential backoff.

## Validation

The starting Flutter baseline had 2,740 passes, 30 skips and eight failures: one platform-dependent permission test and seven signature failures caused by CRLF checkout. Baseline non-generated application line coverage was approximately 45.8%, from an incomplete run.

| Check | Result |
| --- | --- |
| `dart analyze lib test integration_test` | No issues |
| `flutter test --no-pub --coverage --timeout 30s` | 2,746 passed, 32 skipped |
| Frontend `npx vitest run` | 81 passed, 11 files |
| Frontend `npm run check` | Zero errors and warnings |
| `cargo test --workspace --locked --offline -j 1` | 524 passed, 7 ignored; exit 0 |

The final LCOV records 19,195 / 42,211 lines (45.47%) across 431 non-generated `lib` files. The calculation excludes `/generated/`, `lib/src/rust/`, `*.g.dart` and `*.freezed.dart`; files absent from LCOV are not counted. Model context loading/refresh is 86/86 lines, the SFTP backend 22/149, Monitor file backend 25/57 and local SSH tunnels 72/97. The incomplete baseline and changed set of loaded files make the overall percentage unsuitable as a like-for-like performance or quality claim.

The first Rust build exhausted the Windows pagefile under default compilation parallelism; the final command uses `-j 1`. The existing velocity stress test also confused an aggregate 30-second throughput deadline with a deadlock. It now consumes each response, yields the synthetic writer, retains 200 requests, and applies a five-second deadline to each request/body and writer shutdown. Its isolated run passed in 18.7 seconds; real deadlocks still fail within a bounded wait.

A focused Flutter run passed all 60 tests but its optional coverage merge failed because `lcov.base.info` did not exist. The complete suite and coverage were regenerated successfully afterwards. No failed/partial coverage output is used for the final figures.

## Platform limits and remaining coverage

- No Android or Apple device was attached. Android service channel cases explicitly skip on Windows; notification-permission persistence and native service scheduling still require an Android integration run. Existing manifest/entitlement checks were retained.
- No real SSH host credentials were configured. SSH discovery and end-to-end transport/authentication cases remain environment-dependent; local channel/backend substitutes verify failure and disposal behavior without changing the SSH submodule.
- Local Monitor tests verify transport failures and resource release. HTTP disconnect timing and descendant-process cleanup across operating systems are not established by a pipe-unit test; `kill_on_drop` and existing timeout response semantics are retained.
- No running Dart Tooling Daemon or Flutter debug app was found, so hot reload/restart could not run.
- Existing PR CI covers Linux Flutter analysis/tests, frontend tests/type checks and Rust on Linux/Windows; native build jobs remain selected by the existing workflow filters. Those jobs are triggered by the PR, but their eventual results are not claimed here.
- Coverage is a diagnostic. SSH discovery, OS integrations and portions of transfer orchestration still lack full branch coverage; the added tests prioritize failure behavior rather than a target percentage.

## Deferred submodule audit items

No files or gitlinks under submodules were edited.

| Submodule | Follow-up |
| --- | --- |
| `packages/fl_lib` | Audit `LocalAuth.isAvailForTest` / `goWithResultForTest`, SQLite in-memory/reset helpers and other production test seams. Preserve current authentication and historical-storage behavior in a separate change. |
| `packages/dartssh2` | Audit packet/channel testing entry points such as `handlePacket` / `acceptChannelForTesting`, and redundant catch/rethrow paths. Keep protocol compatibility and upstream tests. |
| Other platform/vendor submodules | Keep their lifecycle and platform-specific checks separate from this main-repository PR. |

## Reviewer checklist

- Confirm no schema/protocol/generated-code/submodule diff.
- Review session invalidation against switched, reauthenticated, removed and reconfigured servers.
- Review pipe draining, UTF-8 truncation, timeout behavior and owned-client disposal.
- Review test-hook removal against production call sites and retained historical migrations.
- Check platform skips and deferred submodule findings before treating this as an end-to-end device certification.
