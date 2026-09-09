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
  classify,
  column,
  divider,
  expanded,
  input,
  key,
  l10n,
  notice,
  onChange,
  onTap,
  padding,
  scroll,
  summary,
  tag,
  text,
  tile,
  toggle,
  tone,
  type HookEvent,
  type Plugin,
  type PluginEvent,
  type ServerHandle,
  type Surface,
  type SurfaceKind,
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

/**
 * Which surface this instance is drawing.
 *
 * One module, two views of the same reading: the page, and a card on the
 * server's detail page. Set in `open`, which the host calls before the hook —
 * and each surface is its own instance, so this is not shared with the page's.
 */
let surfaceKind: SurfaceKind = "page";

/** Whether only the ones reachable from outside are shown. */
let exposedOnly = false;

/** What the search box holds. Not persisted: it is about this visit. */
let query = "";

/**
 * How the rows are ordered.
 *
 * By port is the default: it is the one field every row has, and a list of
 * ports is read by number. By process groups a server's services together,
 * which is the other way anybody looks at this.
 */
type SortBy = "port" | "process";
let sortBy: SortBy = "port";

const SORT_KEY = "sortBy";

async function loadSort(): Promise<void> {
  try {
    const stored = (await sb.store.get({ scope: "global", key: SORT_KEY }))
      .value;
    sortBy = stored === "process" ? "process" : "port";
  } catch {
    sortBy = "port";
  }
}

/** The rows to draw, after the filter, the search and the order. */
function shownRows(all: Listener[]): Listener[] {
  const needle = query.trim().toLowerCase();
  const out = all.filter((l) => {
    if (exposedOnly && !l.exposed) return false;
    if (!needle) return true;
    // Port, process and address: the three things somebody would type. A port
    // is matched as a prefix so "80" finds 80 and 8080, which is what a person
    // typing two digits is looking for.
    return (
      `${l.port}`.startsWith(needle) ||
      (l.process ?? "").toLowerCase().includes(needle) ||
      l.addr.toLowerCase().includes(needle)
    );
  });

  out.sort((a, b) =>
    sortBy === "process"
      ? (a.process ?? "").localeCompare(b.process ?? "") || a.port - b.port
      : a.port - b.port,
  );
  return out;
}

/**
 * What went wrong, in the user's language.
 *
 * `reason` from the SDK answers in English, which is right for a plugin that
 * ships no translations and wrong for one that does — so this classifies with
 * `classify` and picks the key itself.
 */
function whyOf(e: unknown): string {
  const { kind, permission } = classify(e);
  switch (kind) {
    case "denied":
      return permission ? l10n("errDenied", permission) : l10n("errDeniedPlain");
    case "unavailable":
      return l10n("errUnavailable");
    case "timeout":
      return l10n("errTimeout");
    case "io":
      return l10n("errIo");
    case "cert":
      return l10n("errCert");
    case "decode":
      return l10n("errDecode");
    case "unknown":
      return l10n("errUnknown");
  }
}

/// The default for [exposedOnly], which is a preference and not a property of
/// any one machine — so `global`.
const EXPOSED_DEFAULT_KEY = "exposedByDefault";

async function exposedByDefault(): Promise<boolean> {
  try {
    return (await sb.store.get({ scope: "global", key: EXPOSED_DEFAULT_KEY }))
      .value === "1";
  } catch {
    return false;
  }
}

export function open(surface: Surface): UiOutput {
  surfaceKind = surface.kind;
  if (surface.kind === "settings") {
    // Drawn from the hook rather than started here. **A promise a plugin leaves
    // running when a call returns does not progress**: the runtime drives an
    // instance only while it is inside a call, so the store read this form
    // needs would sit outstanding until something else happened to call in.
    // The hook is the call that always follows `open`, so that is where the
    // waiting belongs.
    return { ui: padding(17, text(l10n("reading"))) };
  }
  // Deliberately not collecting here. `open` holds the surface until it
  // answers, and this is a command on a machine that may be slow or asleep.
  return { ui: view() };
}

/// The settings surface, which reads the store and so draws after it answers.
async function drawSettings(): Promise<void> {
  const on = await exposedByDefault();
  const node = card([
    onChange(
      toggle(on, {
        label: l10n("prefsExposed"),
        hint: l10n("prefsExposedHint"),
      }),
      { m: "setExposedDefault" },
    ),
  ]);
  try {
    await sb.ui.patch({ path: "", node });
  } catch {
    // Nobody is looking at the settings page any more.
  }
}

export async function onHook(event: HookEvent): Promise<void> {
  // A settings surface collects nothing: its form is drawn from the store by
  // `open`, and the hook is only what pumps that promise. Without this the
  // "no server" branch below draws the page's error over the form — a settings
  // surface is bound to no machine, so `event.servers` is empty by design.
  if (surfaceKind === "settings") {
    // Nothing to collect: the form is the store, and this is the call that gets
    // to wait for it.
    await drawSettings();
    return;
  }
  const first = event.servers[0];
  if (!first) {
    state = { at: "failed", why: l10n("errNoServer") };
    await sb.ui.patch({ path: "", node: view() });
    return;
  }
  server = first.server;
  // The page opens on whichever filter the user chose as the default.
  exposedOnly = await exposedByDefault();
  await loadSort();
  await collect();
}

export async function onEvent({ msg, value }: PluginEvent): Promise<UiOutput> {
  const m = msg as { m: string };
  if (m.m === "setExposedDefault") {
    await sb.store.set({
      scope: "global",
      key: EXPOSED_DEFAULT_KEY,
      value: value === true ? "1" : "0",
    });
    await drawSettings();
    return {};
  }
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
  if (m.m === "sort") {
    sortBy = sortBy === "port" ? "process" : "port";
    try {
      await sb.store.set({ scope: "global", key: SORT_KEY, value: sortBy });
    } catch {
      // The order is applied either way; only the memory of it is lost.
    }
    return { ui: view() };
  }
  if (m.m === "search") {
    query = `${value ?? ""}`;
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
        ? { at: "failed", why: l10n("errNoTool") }
        : { at: "ready", listeners, format };
  } catch (e) {
    state = { at: "failed", why: whyOf(e) };
  }
  // The whole tree, not a subtree: what changed is the body, and naming a
  // JSON Pointer into a tree this file also owns would be two descriptions of
  // one layout that have to agree.
  await sb.ui.patch({ path: "", node: view() });
}

function view() {
  if (surfaceKind === "card") return cardView();
  if (state.at === "loading") {
    return padding(17, text(l10n("reading")));
  }
  if (state.at === "failed") {
    return notice({
      kind: "failed",
      icon: "warning",
      title: l10n("errTitle"),
      detail: state.why,
      actions: [{ label: l10n("retry"), msg: { m: "reload" } }],
    });
  }

  const shown = shownRows(state.listeners);
  const exposed = state.listeners.filter((l) => l.exposed).length;

  const n = state.listeners.length;
  return column([
    summary({
      label: l10n("summaryLabel"),
      value: n === 1 ? l10n("port") : l10n("ports", `${n}`),
      detail:
        exposed === 0 ? l10n("exposedNone") : l10n("exposedCount", `${exposed}`),
      actions: [
        onTap(
          tag(l10n(sortBy === "port" ? "sortPort" : "sortProcess")),
          { m: "sort" },
        ),
        onTap(
          tag(l10n(exposedOnly ? "filterExposed" : "filterAll")),
          { m: "exposed" },
        ),
        onTap(tag(l10n("reload")), { m: "reload" }),
      ],
    }),
    // Below the summary rather than in it: it is a control for the list, and
    // a list of two does not need one — but a server with ninety open ports is
    // exactly where this page stops being readable without it.
    ...(state.listeners.length < 8 && !query
      ? []
      : [
          padding(
            13,
            onChange(input(query, { hint: l10n("searchHint") }), {
              m: "search",
            }),
          ),
        ]),
    divider(),
    expanded(
      scroll(
        shown.length === 0
          ? query.trim()
            ? [
                notice({
                  icon: "info",
                  title: l10n("emptySearchTitle", query.trim()),
                  detail: l10n("emptySearchDetail"),
                  actions: [{ label: l10n("clear"), msg: { m: "search" } }],
                }),
              ]
            : [
              exposedOnly
                ? notice({
                    icon: "lock",
                    title: l10n("emptyExposedTitle"),
                    detail: l10n("emptyExposedDetail"),
                    actions: [
                      { label: l10n("filterAll"), msg: { m: "exposed" } },
                    ],
                  })
                : notice({
                    icon: "network",
                    title: l10n("emptyTitle"),
                    detail: l10n("emptyDetail"),
                    actions: [{ label: l10n("retry"), msg: { m: "reload" } }],
                  }),
              ]
          : [card(shown.map(rowFor))],
      ),
    ),
  ]);
}

/**
 * The card on the server's detail page: the same reading, in a glance.
 *
 * **It collects once, on the way in, and never ticks.** The detail page hands
 * every card the status refresh interval, and this plugin exports no `tick`
 * on purpose — `ss` on every server every few seconds is a plugin doing work
 * nobody asked for, and what is listening does not change while you watch.
 *
 * No filter, no search, no sort: the card answers "is anything reachable from
 * outside", and the page is where the rest is. Anything it drew that the page
 * also draws would be a second place to keep in step.
 */
function cardView() {
  if (state.at === "loading") return padding(13, tone(text(l10n("reading")), "muted"));
  if (state.at === "failed") {
    // Compact on purpose: a card is one of several on that page, and a failure
    // here is not the page's subject. The full error, with its retry, is on the
    // plugin's own page.
    return padding(13, tone(text(state.why), "muted"));
  }

  const exposed = state.listeners.filter((l) => l.exposed);
  const n = state.listeners.length;
  return column([
    summary({
      label: l10n("summaryLabel"),
      value: n === 1 ? l10n("port") : l10n("ports", `${n}`),
      detail:
        exposed.length === 0
          ? l10n("exposedNone")
          : l10n("exposedCount", `${exposed.length}`),
    }),
    // Only the ones reachable from outside, and only a few: the card exists to
    // put those in front of somebody who was not looking for them. A card that
    // listed every port would be the page, in the wrong place.
    ...(exposed.length === 0
      ? []
      : [divider(), ...exposed.slice(0, CARD_ROWS).map(rowFor)]),
    ...(exposed.length > CARD_ROWS
      ? [
          padding(
            9,
            tone(text(l10n("cardMore", `${exposed.length - CARD_ROWS}`)), "muted"),
          ),
        ]
      : []),
  ]);
}

/// How many exposed listeners the card shows before it says "and N more".
const CARD_ROWS = 3;

function rowFor(l: Listener) {
  // Keyed by what makes a listener itself, so the renderer keeps a row's
  // element across a reload instead of rebuilding the list.
  return key(
    tile({
      icon: l.exposed ? "globe" : "lock",
      // The port leads: it is what the eye goes to, and a process name is
      // often missing because reading it needs root.
      title: `${l.port}`,
      // The process where there is one, and the address either way — a row
      // that said only "—" spent a whole line saying nothing.
      // The process where it could be read, and why not where it could not:
      // seeing another user's socket needs root, and a blank line does not
      // say so.
      subtitle: [l.process ?? l10n("unknownProcess"), `${l.proto} · ${l.addr}`]
        .join("  ·  "),
      // The one thing this list is opened to find out. Named rather than
      // coloured alone: a colour says "bad", and a service that is *meant*
      // to be reachable is not bad.
      trailing: l.exposed
        ? tone(tag(l10n("tagExposed")), "warning")
        : tone(tag(l10n("tagLocal")), "muted"),
    }),
    `${l.proto}:${l.addr}:${l.port}`,
  );
}

export default { open, onHook, onEvent } satisfies Plugin;
