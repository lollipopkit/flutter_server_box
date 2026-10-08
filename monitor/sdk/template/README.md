# Desk app template

A `web` desk app built with `@lollipopkit/desk-sys` (`../desk-sys`), the
design system's `@lollipopkit/desk-ui` (`../desk-ui`); both are Apache-2.0 and vite.
Read `docs/dev/desk-sys.md` first.

```sh
npm install
npm run pack        # dist/ + manifest.json -> <id>.fsba
```

Install the package as an admin in Settings → Apps, then approve it.

- Change `id` in `manifest.json`: a publisher prefix, `_`, a name (`acme_notes`).
- The UI runs in a sandboxed frame with no network: everything it needs is
  in the bundle, and it reaches the desk only through `connect()`.
- URLs in the bundle must be relative (`base: './'`).
- `applyTheme(desk.info.theme)` and again on `theme`: the app follows the
  desk's mode and the theme the account installed. Build from the `lk-*`
  classes and tokens (or the Svelte components) rather than your own colours.
- For a backend, set `"kind": "wasm"`, add `backend.wasm` next to
  `manifest.json` in the package, and call it with `desk.backend(method, params)`
  (see `monitor/examples/desk-app-uptime`).
