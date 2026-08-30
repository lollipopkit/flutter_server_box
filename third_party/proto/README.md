# Vendored protobuf schemas

## `tombstone.proto`

Android's schema for the crash record `ApplicationExitInfo.getTraceInputStream()`
returns for `REASON_CRASH_NATIVE` on API 31 and later. It is the only way this
app can see where a native crash happened — in the Rust FFI, the Linux engine,
proot or sqlite — since a crash there takes the process with it and no Dart code
runs afterwards.

- Upstream: `system/core/debuggerd/proto/tombstone.proto`
- Source: <https://android.googlesource.com/platform/system/core/+/refs/heads/main/debuggerd/proto/tombstone.proto>
- Licence: Apache-2.0, as part of AOSP `system/core`
- Vendored verbatim. Do not edit it: a local change would be lost the next time
  it is refreshed, and it would no longer describe what a device writes.

### Why it is here rather than in `android/`

Decoding happens in Dart. Doing it on the Kotlin side would put
`protobuf-javalite` and the protobuf Gradle plugin into the module F-Droid
rebuilds from source and `androidReproducible` compares byte for byte, and it
would be reachable only from a device that has already crashed. In Dart it is
one pure-Dart package and the decoder is covered by `flutter test`.

### Regenerating

```sh
make gen-proto
```

Which needs `protoc` (`brew install protobuf`) and installs `protoc_plugin` from
pub. Output goes to `lib/src/proto/` and is committed, so an ordinary build and
CI need neither tool. That directory is generated: do not edit it, and it is
excluded from the analyzer in `analysis_options.yaml` because protoc emits
relative imports between its own files.

### Refreshing the schema

Fetch the upstream file again and regenerate:

```sh
curl -sSL -o third_party/proto/tombstone.proto \
  https://raw.githubusercontent.com/aosp-mirror/platform_system_core/main/debuggerd/proto/tombstone.proto
make gen-proto
```

Only worth doing when a new Android release adds a field this app would read.
Fields it does not know about are skipped by the protobuf runtime, so a stale
copy loses information rather than breaking — which is also why the tests here
cannot detect one. `lib/core/service/tombstone.dart` reads `signal_info`,
`abort_message`, `causes`, `pid`, `tid` and each thread's `current_backtrace`.
