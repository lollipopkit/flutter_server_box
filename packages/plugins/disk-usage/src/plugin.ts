/**
 * Where the space went, one directory at a time.
 *
 * The question this answers is the one asked right after `df` says 95%, and it
 * is answered by descending rather than by scanning: `du -x -d 1` on the
 * directory you are looking at, and again on whichever child turns out to be
 * the large one. A whole-tree scan would answer the same question and take
 * minutes to do it.
 *
 * Collected in `onHook` like every page here — see PLUGINS.md 4.4 — and the
 * path is remembered per server, so coming back lands where you left rather
 * than at `/` again.
 */

import {
  card,
  column,
  divider,
  expanded,
  key,
  onTap,
  padding,
  percent,
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
import {
  command,
  humanBytes,
  parentOf,
  parse,
  type Scan,
} from "./scan.ts";

/**
 * How long one level may take.
 *
 * `du` walks everything under what it reports on, so a big directory is slow
 * by construction. Two minutes is long enough for a full `/var` on a spinning
 * disk and short enough that a mount which is not answering gives up rather
 * than holding the page for ever.
 *
 * Not cancellable: `sb.server.exec` takes a timeout and nothing else. Recorded
 * in the README as the thing writing this plugin found missing.
 */
const TIMEOUT_MS = 120_000;

const ROOT = "/";
const LAST_PATH_KEY = "lastPath";

type State =
  | { at: "idle" }
  | { at: "scanning"; path: string }
  | { at: "ready"; scan: Scan }
  | { at: "failed"; path: string; why: string };

let state: State = { at: "idle" };
let server: ServerHandle | null = null;

export function open(_surface: Surface): UiOutput {
  return { ui: view() };
}

export async function onHook(event: HookEvent): Promise<void> {
  const first = event.servers[0];
  if (!first) {
    state = { at: "failed", path: ROOT, why: "no server" };
    await draw();
    return;
  }
  server = first.server;
  // Where this server was left. Per server, because "the big directory" is a
  // property of the machine and not of the person looking at it.
  const remembered = (await sb.store.get({ scope: "server", key: LAST_PATH_KEY }))
    .value;
  await scan(remembered ?? ROOT);
}

export async function onEvent(msg: unknown): Promise<UiOutput> {
  const m = msg as { m: string; path?: string };
  if (m.m === "open" && m.path) {
    await scan(m.path);
    return {};
  }
  if (m.m === "up") {
    const from = current();
    const parent = from === null ? null : parentOf(from);
    if (parent !== null) await scan(parent);
    return {};
  }
  if (m.m === "reload") {
    const from = current();
    if (from !== null) await scan(from);
    return {};
  }
  return {};
}

function current(): string | null {
  switch (state.at) {
    case "ready":
      return state.scan.path;
    case "scanning":
    case "failed":
      return state.path;
    case "idle":
      return null;
  }
}

/**
 * Draws, and does not mind if nobody is looking.
 *
 * `sb.ui.patch` rejects when the surface is not on screen — the app is right
 * to say so, since a plugin streaming a log should be able to tell — but a
 * plugin that awaits it unguarded turns "nobody is watching" into "the work
 * stops". The first version of this did exactly that: the `Measuring…` patch
 * threw and the measurement never ran.
 */
async function draw(): Promise<void> {
  try {
    await sb.ui.patch({ path: "", node: view() });
  } catch {
    // Nothing to do about it, and nothing to report to a surface that is gone.
  }
}

async function scan(path: string): Promise<void> {
  const handle = server;
  if (!handle) return;

  // Drawn before the command runs. A level can take a minute, and a tap that
  // shows nothing for a minute reads as a tap that did nothing.
  state = { at: "scanning", path };
  await draw();

  try {
    const r = await sb.server.exec({
      server: handle,
      script: command(path),
      timeoutMs: TIMEOUT_MS,
    });
    state = { at: "ready", scan: parse(path, r.stdout) };
  } catch (e) {
    state = { at: "failed", path, why: String(e) };
  }
  await draw();

  // After the answer is drawn, and in its own `try`. Remembering where you
  // were is a convenience; a store that would not write must not take the
  // measurement down with it — which is what happened while this was inside
  // the block above, and is why the two are separated here.
  if (state.at === "ready") {
    try {
      await sb.store.set({ scope: "server", key: LAST_PATH_KEY, value: path });
    } catch {
      // Nothing to tell the user: the level they asked for is on screen.
    }
  }
}

function view() {
  if (state.at === "idle") return padding(17, text("…"));
  if (state.at === "scanning") {
    return column([bar(state.path), divider(), padding(17, text("Measuring…"))]);
  }
  if (state.at === "failed") {
    return column([
      bar(state.path),
      divider(),
      padding(17, tone(text(state.why), "danger")),
    ]);
  }

  const { scan: s } = state;
  const fs = s.filesystem;
  return column([
    bar(s.path),
    padding(
      13,
      column(
        [
          row(
            [
              expanded(text(`${humanBytes(s.totalBytes)} in ${s.path}`)),
              // The filesystem behind it, because "31G in /var" only means
              // something beside the size of the disk it is on.
              ...(fs
                ? [
                    text(
                      `${humanBytes(fs.usedBytes)} / ${humanBytes(fs.sizeBytes)}`,
                    ),
                  ]
                : []),
            ],
            { spacing: 9 },
          ),
          ...(fs ? [percent(fs.usedBytes / fs.sizeBytes, "")] : []),
        ],
        { spacing: 7 },
      ),
    ),
    divider(),
    expanded(
      scroll(
        s.children.length === 0
          ? [padding(17, text("Nothing under here takes any space."))]
          : s.children.map((c) => rowFor(c, s.totalBytes)),
      ),
    ),
  ]);
}

/** The path, the way back up, and a way to ask again. */
function bar(path: string) {
  const up = parentOf(path);
  return padding(
    11,
    row(
      [
        ...(up === null ? [] : [onTap(tag("↑"), { m: "up" })]),
        expanded(text(path)),
        onTap(tag("Reload"), { m: "reload" }),
      ],
      { spacing: 7 },
    ),
  );
}

function rowFor(
  child: { path: string; name: string; bytes: number },
  total: number,
) {
  // A share of the parent rather than of the disk: the question at this level
  // is which of *these* took the space.
  const share = total > 0 ? child.bytes / total : 0;
  return key(
    onTap(
      card([
        padding(
          11,
          column(
            [
              row(
                [
                  expanded(text(child.name)),
                  text(humanBytes(child.bytes)),
                ],
                { spacing: 9 },
              ),
              percent(share, ""),
            ],
            { spacing: 5 },
          ),
        ),
      ]),
      { m: "open", path: child.path },
    ),
    child.path,
  );
}

export default { open, onHook, onEvent } satisfies Plugin;
