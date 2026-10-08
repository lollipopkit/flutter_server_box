# Example desk app with a backend

A `wasm` desk app (`docs/dev/desk-sys.md`): the UI asks its backend
(`src/lib.rs`, run by the agent) for the machine's uptime, and for `who`
(the `exec` permission, and the calling account's shell grant).

```sh
cargo build --release --target wasm32-unknown-unknown
cp target/wasm32-unknown-unknown/release/desk_app_uptime.wasm backend.wasm
COPYFILE_DISABLE=1 tar -czf example_uptime.fsba manifest.json backend.wasm ui
```
