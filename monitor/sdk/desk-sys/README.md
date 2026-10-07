# @lollipopkit/desk-sys

The client an installed desk app uses, from inside its sandboxed frame, to
reach the ServerBox monitor's desk. The design, the permissions and the
message protocol: `docs/dev/desk-sys.md`. A starting point: `../template`.

```ts
import { connect } from '@lollipopkit/desk-sys'

const desk = await connect()
await desk.toolbar({ actions: [{ id: 'refresh', label: 'Refresh', icon: 'refresh' }] })
desk.on('action', ({ id }) => { /* … */ })
const count = (await desk.storage.get<number>('count')) ?? 0
await desk.storage.set('count', count + 1)
```

`src/protocol.ts` is the protocol itself; the desk's side
(`monitor/frontend/src/desk/webapps/bridge.svelte.ts`) imports it from here,
and `monitor/frontend/src/tests/deskSdk.test.ts` runs this client against it.

Not published yet (`private`): the license an app built on it takes is still
to be decided.
