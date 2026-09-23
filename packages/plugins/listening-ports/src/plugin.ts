/**
 * What a server is listening on.
 *
 * Written against the SDK's tracked state: the reading is a `resource`, the
 * filters are `state`s, and **reading one is subscribing to it**. What that
 * removes is every line this file used to spend on *when to redraw* — a handler
 * here changes a value and stops, and the page follows.
 *
 * It is a `page` (a button in the server's function bar), a `card` on the
 * server's detail page, and a `settings` section. One module, three views of
 * the same reading: `ctx.kind` decides which.
 *
 * The reading is collected from the hook rather than from `open` — see
 * PLUGINS.md 4.4 — because it is a question with an answer, not a value that
 * changes while you watch it. `open` draws the loading state at once and the
 * rows arrive when the command comes back.
 */

import {
  card,
  classify,
  column,
  divider,
  expanded,
  resource,
  input,
  key,
  l10n,
  notice,
  onChange,
  onTap,
  padding,
  scroll,
  skeleton,
  state,
  summary,
  surface,
  tag,
  text,
  tile,
  toggle,
  tone,
  type HookEvent,
  type ServerHandle,
} from "@serverbox/plugin-api";
import { COMMAND, parse, type Format, type Listener } from "./parse.ts";

/**
 * The server this instance is about, in three states.
 *
 * `undefined` is *not asked yet* — `open` has drawn and the hook has not
 * arrived — and `null` is *asked, and there is none*. Two different screens: a
 * page that is about to read something, and a page that cannot. Collapsing
 * them made a surface flash "no server" for one frame every time it opened.
 */
const server = state<ServerHandle | null | undefined>(undefined);

/** Whether only the ones reachable from outside are shown. */
const exposedOnly = state(false);

/** What the search box holds. Not persisted: it is about this visit. */
const query = state("");

/**
 * How the rows are ordered.
 *
 * By port is the default: it is the one field every row has, and a list of
 * ports is read by number. By process groups a server's services together,
 * which is the other way anybody looks at this.
 */
type SortBy = "port" | "process";
const sortBy = state<SortBy>("port");

const SORT_KEY = "sortBy";

/// The default for [exposedOnly], which is a preference rather than a property
/// of any one machine — so `global`.
const EXPOSED_DEFAULT_KEY = "exposedByDefault";

/** What is stored under [EXPOSED_DEFAULT_KEY], as the settings form reads it. */
const exposedDefault = resource(async () => {
  const stored = await sb.store.get({ scope: "global", key: EXPOSED_DEFAULT_KEY });
  return stored.value === "1";
});

/**
 * The reading itself.
 *
 * Reading [server] at the top is what makes this re-run: the hook sets it, this
 * fetches again, the page redraws. Nothing here calls for a redraw and nothing
 * patches.
 */
const listeners = resource(async () => {
  const handle = server.value;
  if (!handle) throw new NoServer();
  const r = await sb.server.exec({ server: handle, script: COMMAND });
  const { format, listeners } = parse(r.stdout);
  if (format === "none") throw new NoTool();
  return { listeners, format } as { listeners: Listener[]; format: Format };
});

/// The two failures that are not exceptions from the host: a surface with no
/// machine behind it, and a machine with neither `ss` nor `netstat`. Classes
/// rather than strings, so `whyOf` can tell them from an exec that threw.
class NoServer extends Error {}
class NoTool extends Error {}

/** The rows to draw, after the filter, the search and the order. */
function shownRows(all: Listener[]): Listener[] {
  const needle = query.value.trim().toLowerCase();
  const only = exposedOnly.value;
  const by = sortBy.value;
  const out = all.filter((l) => {
    if (only && !l.exposed) return false;
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
    by === "process"
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
  if (e instanceof NoServer) return l10n("errNoServer");
  if (e instanceof NoTool) return l10n("errNoTool");
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

const app = surface((ctx) => {
  if (ctx.kind === "settings") return settingsView();
  if (ctx.kind === "card") return cardView();
  return pageView();
});

export const { open, onEvent, dispose } = app;

/**
 * The hook is where the reading happens, and where it is waited for.
 *
 * `settle` is not optional: the host drives an instance only while it is
 * inside a call, so the fetch this starts would not progress until something
 * else called in — a page that opens loading and stays there.
 */
export async function onHook(event: HookEvent): Promise<void> {
  const first = event.servers[0];
  if (first) {
    exposedOnly.value = await stored(EXPOSED_DEFAULT_KEY, "1");
    sortBy.value = (await storedValue(SORT_KEY)) === "process" ? "process" : "port";
    server.value = first.server;
  } else {
    // A settings surface is bound to no machine by design, and so is a page
    // opened on a server that has gone. `listeners` says which.
    server.value = null;
  }
  await app.settle();
}

async function storedValue(key: string): Promise<string | null> {
  try {
    return (await sb.store.get({ scope: "global", key })).value;
  } catch {
    return null;
  }
}

async function stored(key: string, truthy: string): Promise<boolean> {
  return (await storedValue(key)) === truthy;
}

/// The settings surface: one preference, read from the store.
function settingsView() {
  return exposedDefault.when({
    loading: () => padding(17, text(l10n("reading"))),
    error: () => padding(17, text(l10n("errUnknown"))),
    data: (on) =>
      card([
        onChange(
          toggle(on, {
            label: l10n("prefsExposed"),
            hint: l10n("prefsExposedHint"),
          }),
          async (value) => {
            await sb.store.set({
              scope: "global",
              key: EXPOSED_DEFAULT_KEY,
              value: value === true ? "1" : "0",
            });
            exposedDefault.reload();
          },
        ),
      ]),
  });
}

function pageView() {
  // **Nothing is read until the hook names a server.** A resource runs the
  // first time something reads it, so not reading `listeners` here is what
  // keeps `open` from running a command — the same rule PLUGINS.md 4.4 states,
  // falling out of laziness rather than out of a flag.
  if (server.value === undefined) return skeleton(5);
  return listeners.when({
    loading: () => skeleton(5),
    error: (e) =>
      notice({
        kind: "failed",
        icon: "warning",
        title: l10n("errTitle"),
        detail: whyOf(e),
        actions: [{ label: l10n("retry"), msg: () => listeners.reload() }],
      }),
    data: ({ listeners: all }) => rows(all),
  });
}

function rows(all: Listener[]) {
  const shown = shownRows(all);
  const exposed = all.filter((l) => l.exposed).length;
  const searching = query.value;
  const only = exposedOnly.value;
  const by = sortBy.value;

  const n = all.length;
  return column([
    summary({
      label: l10n("summaryLabel"),
      value: n === 1 ? l10n("port") : l10n("ports", `${n}`),
      detail:
        exposed === 0 ? l10n("exposedNone") : l10n("exposedCount", `${exposed}`),
      actions: [
        onTap(tag(l10n(by === "port" ? "sortPort" : "sortProcess")), async () => {
          const next = by === "port" ? "process" : "port";
          sortBy.value = next;
          try {
            await sb.store.set({ scope: "global", key: SORT_KEY, value: next });
          } catch {
            // The order is applied either way; only the memory of it is lost.
          }
        }),
        onTap(
          tag(l10n(only ? "filterExposed" : "filterAll")),
          () => (exposedOnly.value = !only),
        ),
        onTap(tag(l10n("reload")), () => listeners.reload()),
      ],
    }),
    // Below the summary rather than in it: it is a control for the list, and
    // a list of two does not need one — but a server with ninety open ports is
    // exactly where this page stops being readable without it.
    ...(n < 8 && !searching
      ? []
      : [
          padding(
            13,
            onChange(
              input(searching, { hint: l10n("searchHint"), icon: "search" }),
              (value) => (query.value = `${value ?? ""}`),
            ),
          ),
        ]),
    divider(),
    expanded(
      scroll(
        shown.length > 0
          ? [card(shown.map(rowFor))]
          : [emptyFor(searching, only)],
      ),
    ),
  ]);
}

/** Which of the three empty states this is, and the way out of each. */
function emptyFor(searching: string, only: boolean) {
  if (searching.trim()) {
    return notice({
      icon: "info",
      title: l10n("emptySearchTitle", searching.trim()),
      detail: l10n("emptySearchDetail"),
      actions: [{ label: l10n("clear"), msg: () => (query.value = "") }],
    });
  }
  if (only) {
    return notice({
      icon: "lock",
      title: l10n("emptyExposedTitle"),
      detail: l10n("emptyExposedDetail"),
      actions: [
        { label: l10n("filterAll"), msg: () => (exposedOnly.value = false) },
      ],
    });
  }
  return notice({
    icon: "network",
    title: l10n("emptyTitle"),
    detail: l10n("emptyDetail"),
    actions: [{ label: l10n("retry"), msg: () => listeners.reload() }],
  });
}

/**
 * The card on the server's detail page: the same reading, in a glance.
 *
 * **It collects once, on the way in, and never ticks.** The detail page hands
 * every card the status refresh interval, and this plugin exports no `tick` on
 * purpose — `ss` on every server every few seconds is a plugin doing work
 * nobody asked for, and what is listening does not change while you watch.
 *
 * No filter, no search, no sort: the card answers "is anything reachable from
 * outside", and the page is where the rest is. Anything it drew that the page
 * also draws would be a second place to keep in step.
 */
function cardView() {
  if (server.value === undefined) {
    return padding(13, tone(text(l10n("reading")), "muted"));
  }
  return listeners.when({
    loading: () => padding(13, tone(text(l10n("reading")), "muted")),
    // Compact on purpose: a card is one of several on that page, and a failure
    // here is not the page's subject. The full error, with its retry, is on the
    // plugin's own page.
    error: (e) => padding(13, tone(text(whyOf(e)), "muted")),
    data: ({ listeners: all }) => {
      const exposed = all.filter((l) => l.exposed);
      const n = all.length;
      return column([
        summary({
          label: l10n("summaryLabel"),
          value: n === 1 ? l10n("port") : l10n("ports", `${n}`),
          detail:
            exposed.length === 0
              ? l10n("exposedNone")
              : l10n("exposedCount", `${exposed.length}`),
        }),
        // Only the ones reachable from outside, and only a few: the card exists
        // to put those in front of somebody who was not looking for them. A
        // card that listed every port would be the page, in the wrong place.
        ...(exposed.length === 0
          ? []
          : [divider(), ...exposed.slice(0, CARD_ROWS).map(rowFor)]),
        ...(exposed.length > CARD_ROWS
          ? [
              padding(
                9,
                tone(
                  text(l10n("cardMore", `${exposed.length - CARD_ROWS}`)),
                  "muted",
                ),
              ),
            ]
          : []),
      ]);
    },
  });
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
      // The process where it could be read, and why not where it could not:
      // seeing another user's socket needs root, and a blank line does not
      // say so.
      subtitle: [l.process ?? l10n("unknownProcess"), `${l.proto} · ${l.addr}`]
        .join("  ·  "),
      // The one thing this list is opened to find out. Named rather than
      // coloured alone: a colour says "bad", and a service that is *meant* to
      // be reachable is not bad.
      trailing: l.exposed
        ? tone(tag(l10n("tagExposed")), "warning")
        : tone(tag(l10n("tagLocal")), "muted"),
    }),
    `${l.proto}:${l.addr}:${l.port}`,
  );
}
