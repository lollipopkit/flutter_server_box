# lkui

The client an installed desk app uses, from inside its sandboxed frame, to
reach the ServerBox monitor's desk. The design, the permissions and the
message protocol: `docs/dev/desk-sys.md`. A starting point: `../template`.

```sh
npm install lkui
```

```ts
import { connect } from 'lkui'

const desk = await connect()
await desk.toolbar({ actions: [{ id: 'refresh', label: 'Refresh', icon: 'refresh' }] })
desk.on('action', ({ id }) => { /* … */ })
const count = (await desk.storage.get<number>('count')) ?? 0
await desk.storage.set('count', count + 1)
```

Once `connect()` resolves, the page is in the desk's design system: the desk
serves its stylesheet (`/desk-app/desk.css`) and keeps the page in its mode
and theme, so the app writes markup with its classes and tokens and carries
none of it (`docs/dev/desk-sys.md`, "UI"):

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
