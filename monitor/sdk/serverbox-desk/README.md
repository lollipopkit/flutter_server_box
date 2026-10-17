# serverbox-desk

The client an installed desk app uses, from inside its sandboxed frame, to
reach the ServerBox monitor's desk. The design, the permissions and the
message protocol: [Developing Desk Apps](https://serverbox.lollipopkit.com/docs/development/desk-apps/)
and [`docs/dev/desk-sys.md`](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/desk-sys.md).
A starting point: [`monitor/sdk/template`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/sdk/template).

```sh
npm install serverbox-desk
```

```ts
import { connect } from 'serverbox-desk'

const desk = await connect()
await desk.toolbar({ actions: [{ id: 'refresh', label: 'Refresh', icon: 'refresh' }] })
desk.on('action', ({ id }) => { /* … */ })
const count = (await desk.storage.get<number>('count')) ?? 0
await desk.storage.set('count', count + 1)

// A `wasm` app's backend: a function of its WIT `api`, and one of its `jobs`
// run as root after the desk's own sudo dialog.
const notes = await desk.call('list', { folder: 'work' })
await desk.job('reindex', {}, { sudo: { title: 'Reindex', body: 'Reads every folder as root.' }, onLine: console.log })
```

Once `connect()` resolves, the page is in the desk's design system: the desk
serves its stylesheet (`/desk-app/desk.css`) and keeps the page in its mode
and theme, so the app writes markup with its classes and tokens and carries
none of it ([`docs/dev/desk-sys.md`, "UI"](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/desk-sys.md#ui-third-party-apps)):

```html
<body>
  <div class="lk-card">
    <button class="lk-btn lk-btn--primary"><span class="lk-icon" data-icon="play_arrow"></span>Run</button>
  </div>
</body>
```

`connect({ style: false })` leaves the page alone.

`src/protocol.ts` is the protocol itself; the desk's side
(`monitor/frontend/src/desk/webapps/bridge.svelte.ts`) imports it from here,
and `monitor/frontend/src/tests/deskSdk.test.ts` runs this client against it.

`npm run build` writes `dist/`, what the package exports (`npm publish` runs
it first); the panel and its tests use `src/` directly.

Apache-2.0 (`LICENSE`, `NOTICE`): an app built on it, closed-source included,
keeps its own license.
