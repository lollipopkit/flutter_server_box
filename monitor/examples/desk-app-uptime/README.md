# Example desk app with a backend

A `wasm` desk app (`docs/dev/desk-sys.md`): the UI asks its backend
(`src/lib.rs`, a component the agent runs; its service is
`wit/uptime.wit`) for the machine's uptime (the `status` permission), and
for `who` (`process`).

```sh
cargo build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/desk_app_uptime.wasm backend.wasm
COPYFILE_DISABLE=1 tar -czf example.uptime.fsba manifest.json backend.wasm ui
```
