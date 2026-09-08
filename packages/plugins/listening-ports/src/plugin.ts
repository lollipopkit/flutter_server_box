/**
 * What a server is listening on. The first plugin written against the host
 * interface rather than alongside it.
 *
 * It is a `page`: a button in the server's function bar, opening a list. The
 * reading is collected in `onHook` rather than in `open` or `tick` — see
 * PLUGINS.md 4.4 — because it is a question with an answer, not a value that
 * changes while you watch it. `open` draws the empty page immediately and the
 * rows are patched in when the command comes back, so a slow machine costs a
 * spinner rather than a blank window.
 */

import {
  card,
  column,
  divider,
  expanded,
  key,
  onTap,
  padding,
  row,
  scroll,
  tag,
  text,
  tone,
  type HookEvent,
  type Plugin,
  type ServerHandle,
  type Surface,
  type UiOutput,
} from "@serverbox/plugin-api";
import { COMMAND, parse, type Format, type Listener } from "./parse.ts";

type State =
  | { at: "loading" }
  | { at: "ready"; listeners: Listener[]; format: Format }
  | { at: "failed"; why: string };

let state: State = { at: "loading" };

/** The server this page is about, from the hook. */
let server: ServerHandle | null = null;

/** Whether only the ones reachable from outside are shown. */
let exposedOnly = false;

export function open(_surface: Surface): UiOutput {
  // Deliberately not collecting here. `open` holds the surface until it
  // answers, and this is a command on a machine that may be slow or asleep.
  return { ui: view() };
}

export async function onHook(event: HookEvent): Promise<void> {
  const first = event.servers[0];
  if (!first) {
    state = { at: "failed", why: "no server" };
    await sb.ui.patch({ path: "", node: view() });
    return;
  }
  server = first.server;
  await collect();
}

export async function onEvent(msg: unknown): Promise<UiOutput> {
  const m = msg as { m: string };
  if (m.m === "reload") {
    state = { at: "loading" };
    // Drawn before the command runs, so the button visibly did something on a
    // machine that takes seconds to answer.
    await sb.ui.patch({ path: "", node: view() });
    await collect();
    return {};
  }
  if (m.m === "exposed") {
    exposedOnly = !exposedOnly;
    return { ui: view() };
  }
  return {};
}

async function collect(): Promise<void> {
  const handle = server;
  if (!handle) return;
  try {
    const r = await sb.server.exec({ server: handle, script: COMMAND });
    const { format, listeners } = parse(r.stdout);
    state =
      format === "none"
        ? { at: "failed", why: "neither ss nor netstat is installed" }
        : { at: "ready", listeners, format };
  } catch (e) {
    state = { at: "failed", why: String(e) };
  }
  // The whole tree, not a subtree: what changed is the body, and naming a
  // JSON Pointer into a tree this file also owns would be two descriptions of
  // one layout that have to agree.
  await sb.ui.patch({ path: "", node: view() });
}

function view() {
  if (state.at === "loading") {
    return padding(17, text("Reading…"));
  }
  if (state.at === "failed") {
    return padding(17, tone(text(state.why), "danger"));
  }

  const shown = exposedOnly
    ? state.listeners.filter((l) => l.exposed)
    : state.listeners;
  const exposed = state.listeners.filter((l) => l.exposed).length;

  return column([
    padding(
      13,
      row(
        [
          expanded(
            text(
              `${state.listeners.length} listening · ${exposed} reachable from outside`,
            ),
          ),
          onTap(tag(exposedOnly ? "Exposed only" : "All"), { m: "exposed" }),
          onTap(tag("Reload"), { m: "reload" }),
        ],
        { spacing: 7 },
      ),
    ),
    divider(),
    expanded(
      scroll(
        shown.length === 0
          ? [padding(17, text("Nothing is listening."))]
          : shown.map(rowFor),
      ),
    ),
  ]);
}

function rowFor(l: Listener) {
  // Keyed by what makes a listener itself, so the renderer keeps a row's
  // element across a reload instead of rebuilding the list.
  return key(
    card([
      padding(
        11,
        row(
          [
            // The port is what the eye goes to, so it leads and nothing is put
            // before it.
            text(`${l.port}`),
            expanded(text(l.process ?? "—")),
            tag(l.proto),
            // The one thing this list is opened to find out. Named rather than
            // coloured alone: a colour says "bad", and a service that is
            // *meant* to be reachable is not bad.
            l.exposed
              ? tone(tag(l.addr), "warning")
              : tone(tag(l.addr), "muted"),
          ],
          { spacing: 9 },
        ),
      ),
    ]),
    `${l.proto}:${l.addr}:${l.port}`,
  );
}

export default { open, onHook, onEvent } satisfies Plugin;
