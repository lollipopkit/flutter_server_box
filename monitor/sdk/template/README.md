# Desk app template

A `web` desk app built with `lkui` (`../lkui`,
Apache-2.0) and vite.
Read `docs/dev/desk-sys.md` first.

```sh
npm install
npm run pack        # dist/ + manifest.json -> <id>.fsba
```

Here `lkui` is the copy beside it (`file:../lkui`), which needs
`npm run build --prefix ../lkui` once; a copy of this template elsewhere
depends on the published `lkui` instead.

Install the package as an admin in Settings → Apps, then approve it.

- Change `id` in `manifest.json`: a publisher prefix, `_`, a name (`acme_notes`).
- The UI runs in a sandboxed frame with no network: everything it needs is
  in the bundle, and it reaches the desk only through `connect()`.
- URLs in the bundle must be relative (`base: './'`).
- `connect()` puts the desk's design system on the page and keeps it in the
  desk's mode and theme: write markup with its `lk-*` classes and tokens
  (`docs/dev/desk-sys.md`, "UI") rather than your own colours. Its
  implementation is the desk's and is never in the package, so the app looks
  right only inside ServerBox. `connect({ style: false })` opts out.
- For a backend, set `"kind": "wasm"`, add `backend.wasm` next to
  `manifest.json` in the package, and call it with `desk.backend(method, params)`
  (see `monitor/examples/desk-app-uptime`).
