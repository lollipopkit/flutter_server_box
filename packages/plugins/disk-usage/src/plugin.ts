/**
 * Where the space went, one directory at a time.
 *
 * The question this answers is the one asked right after `df` says 95%, and it
 * is answered by descending rather than by scanning: `du -x -d 1` on the
 * directory you are looking at, and again on whichever child turns out to be
 * the large one. A whole-tree scan would answer the same question and take
 * minutes to do it.
 *
 * Collected from the hook like every page here — see PLUGINS.md 4.4 — and the
 * path is remembered per server, so coming back lands where you left rather
 * than at `/` again.
 *
 * Written against the SDK's tracked state: the reading is a `resource` that
 * reads the path, so *descending is setting a value* and everything else
 * follows. What
 * that removes is every `await draw()` this file used to carry, and with them
 * the question of which of them was forgotten.
 */

import {
  banner,
  btn,
  card,
  classify,
  column,
  commandReason,
  divider,
  expanded,
  resource,
  input,
  isUsablePath,
  key,
  l10n,
  notice,
  onChange,
  onTap,
  padding,
  percent,
  scroll,
  shellQuote,
  sized,
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
import {
  command,
  humanBytes,
  parentOf,
  parse,
  type Entry,
  type Scan,
} from "./scan.ts";

/**
 * How long one level may take.
 *
 * `du` walks everything under what it reports on, so a big directory is slow
 * by construction. Two minutes is long enough for a full `/var` on a spinning
 * disk and short enough that a mount which is not answering gives up rather
 * than holding the page for ever.
 */
const TIMEOUT_MS = 120_000;

/**
 * The label the scan runs under, so a button can stop one.
 *
 * A guess at four minutes is not a decision anybody can make before the scan
 * starts, which is why the timeout above is not enough on its own: what a
 * person actually does is watch it for a while and then decide. One label for
 * the whole plugin, because one surface measures one directory at a time —
 * descending replaces the reading rather than adding to it.
 */
const SCAN = "scan";

const ROOT = "/";
const LAST_PATH_KEY = "lastPath";

/// Settings. Global rather than per server: how the measurement is taken is
/// the user's preference, not a property of any one machine — unlike
/// [LAST_PATH_KEY], which is where *that* machine was left.
const CROSS_FS_KEY = "crossFilesystems";
const START_AT_KEY = "startAt";
const SORT_KEY = "sortBy";

/** Names left out of a listing, and the size a row has to reach to be in one. */
const SKIP_KEY = "skipNames";
const HIDE_BELOW_KEY = "hideBelowMib";

/**
 * How the rows are ordered. Largest first is the default because the question
 * is where the space went; by name is for finding one you already know of.
 */
type SortBy = "size" | "name";
const sortBy = state<SortBy>("size");

/** The server this instance is about. `undefined` is *not asked yet*. */
const server = state<ServerHandle | null | undefined>(undefined);

/** The directory on screen. Setting it *is* descending. */
const path = state<string | null>(null);

/** What a delete is doing, or null. Drawn over the reading while it runs. */
const removing = state<number | null>(null);

/**
 * Which children are picked, by absolute path, and whether picking is on.
 *
 * Cleared whenever the level changes: a selection is about what is in front of
 * you, and carrying one into another directory would mean a delete that
 * removes something off screen.
 */
const selecting = state(false);
const selected = state<ReadonlySet<string>>(new Set());

interface Settings {
  crossFilesystems: boolean;
  startAt: string;
  /** Directory names to leave out of a listing. */
  skip: string[];
  /** Rows under this are left out. Zero shows everything. */
  hideBelowBytes: number;
}

const DEFAULTS: Settings = {
  crossFilesystems: false,
  startAt: ROOT,
  skip: [],
  hideBelowBytes: 0,
};

/**
 * What the settings page holds.
 *
 * A resource rather than a value, because it is four store reads — and the form
 * has all three of its states for free: the page says "reading" while they are
 * outstanding instead of drawing an empty form that fills in under the user.
 */
const prefs = resource(async () => settings());

/**
 * What the settings form holds that the store does not.
 *
 * A field the user is halfway through typing is not a setting yet, and a
 * rejected one must not jump back to the stored value while they are looking at
 * why it was rejected. Both live here, and only until the surface goes.
 */
const draft = state<ReadonlyMap<string, string>>(new Map());

/// The switch's own, for the same reason: what it shows is what was just
/// tapped, and re-reading four keys to learn that would put the form back into
/// its loading state for a moment.
const crossDraft = state<boolean | null>(null);
const rejected = state<ReadonlyMap<string, string>>(new Map());

/**
 * The reading: one level, and the filters as they were when it was taken.
 *
 * Reading [path] is what makes descending work — a row sets it and this runs.
 * The filters are carried with the answer rather than read by the view: they
 * come from the store, the view is a pure function, and applying a setting to
 * a measurement taken before it was changed is how a list disagrees with the
 * page that produced it.
 */
const level = resource(async () => {
  const handle = server.value;
  const at = path.value;
  if (!handle) throw new NoServer();
  if (at === null) throw new NoServer();

  const s = await settings();
  const r = await sb.server.exec({
    server: handle,
    script: command(at, { crossFilesystems: s.crossFilesystems }),
    timeoutMs: TIMEOUT_MS,
    cancelKey: SCAN,
  });
  const scan = parse(at, r.stdout);

  // After the answer, and in its own `try`. Remembering where you were is a
  // convenience; a store that would not write must not take the measurement
  // down with it — which is what happened while the two were together.
  try {
    await sb.store.set({ scope: "server", key: LAST_PATH_KEY, value: at });
  } catch {
    // Nothing to tell the user: the level they asked for is on screen.
  }
  return { scan, filters: { skip: s.skip, hideBelowBytes: s.hideBelowBytes } };
}, {
  // A `du` over a full disk is minutes, and the host runs one call at a time
  // per instance — so a call that waited for this is a call in which the Stop
  // button above cannot be pressed. The page draws `Measuring…`, the call
  // answers with it, and the reading arrives on the next tick.
  background: true,
});

/// A surface bound to no machine, or one with no directory yet.
class NoServer extends Error {}

/**
 * What went wrong, in the user's language.
 *
 * `reason` and `commandReason` from the SDK answer in English, which is right
 * for a plugin that ships no translations and wrong for one that does.
 */
function whyOf(e: unknown): string {
  if (e instanceof NoServer) return l10n("errNoServer");
  const { kind, permission, remote } = classify(e);
  switch (kind) {
    case "denied":
      return permission ? l10n("errDenied", permission) : l10n("errDeniedPlain");
    case "unavailable":
      return l10n("errUnavailable");
    // Both of these carry what the app could not decide for itself: whether
    // `du` is still walking that filesystem. Over SSH it is not; over a
    // monitor agent it is, and somebody watching their server's load needs to
    // be told rather than left to work it out.
    case "timeout":
      return remote === "running" ? l10n("errTimeoutRunning") : l10n("errTimeout");
    case "cancelled":
      return remote === "running"
        ? l10n("errCancelledRunning")
        : l10n("errCancelled");
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

/**
 * What `rm` itself said, as a sentence.
 *
 * The recognised cases are translated. Anything else is the command's own
 * first line, untranslated — it is the machine talking, and inventing a
 * sentence for it would be worse than quoting it.
 */
function commandWhy(r: { code: number; stderr: string }): string {
  const lower = r.stderr.toLowerCase();
  if (lower.includes("permission denied") || lower.includes("operation not permitted")) {
    return l10n("errNoPermission");
  }
  if (lower.includes("no such file") || lower.includes("no such directory")) {
    return l10n("errGone");
  }
  if (lower.includes("read-only file system")) return l10n("errReadOnly");
  return commandReason(r, l10n("errDeleteFailed"));
}

/** Read per scan rather than kept, so an edit applies to the next one. */
async function settings(): Promise<Settings> {
  try {
    const [cross, start, skip, hide] = await Promise.all([
      sb.store.get({ scope: "global", key: CROSS_FS_KEY }),
      sb.store.get({ scope: "global", key: START_AT_KEY }),
      sb.store.get({ scope: "global", key: SKIP_KEY }),
      sb.store.get({ scope: "global", key: HIDE_BELOW_KEY }),
    ]);
    return {
      crossFilesystems: cross.value === "1",
      // An unusable value is ignored rather than sent: the field is free text
      // and `/` is always a directory.
      startAt: start.value && isUsablePath(start.value) ? start.value : ROOT,
      skip: splitNames(skip.value),
      hideBelowBytes: mibOf(hide.value) * 1024 * 1024,
    };
  } catch {
    return DEFAULTS;
  }
}

/**
 * The names in a skip list, however they were separated.
 *
 * Whitespace or commas, because both are what people type and neither is legal
 * in the middle of a directory name they would want to skip.
 */
export function splitNames(raw: string | null | undefined): string[] {
  return `${raw ?? ""}`
    .split(/[\s,]+/)
    .map((n) => n.trim())
    .filter((n) => n.length > 0);
}

/** A whole number of MiB, or 0 for anything this is not. */
function mibOf(raw: string | null | undefined): number {
  const n = Number.parseInt(`${raw ?? ""}`.trim(), 10);
  return Number.isFinite(n) && n > 0 ? n : 0;
}

/**
 * What the two filters leave, and what they took.
 *
 * The count is drawn: a list shortened without saying so is how somebody
 * concludes a directory is empty when what happened is that they set a
 * threshold weeks ago.
 */
export function filtered(
  children: { name: string; path: string; bytes: number }[],
  where: { skip: string[]; hideBelowBytes: number },
): { shown: typeof children; hidden: number } {
  const skip = new Set(where.skip.map((n) => n.toLowerCase()));
  const shown = children.filter(
    (c) => !skip.has(c.name.toLowerCase()) && c.bytes >= where.hideBelowBytes,
  );
  return { shown, hidden: children.length - shown.length };
}

const app = surface((ctx) =>
  ctx.kind === "settings" ? settingsView() : pageView(),
);

/**
 * `tick` is exported although this plugin polls nothing.
 *
 * It is what a `background` resource needs to arrive at all: the host delivers
 * an outstanding host call's answer only while it is inside a call, and a scan
 * no call waits for has no other way in. The app calls this as soon as the
 * answer is there, so the reading is not actually deferred by an interval —
 * but without the export there is nothing to call.
 */
export const { open, onEvent, tick, dispose } = app;

export async function onHook(event: HookEvent): Promise<void> {
  const first = event.servers[0];
  if (!first) {
    // A settings surface is bound to no machine by design; so is a page opened
    // on a server that has gone. The page says which.
    server.value = null;
    await app.settle();
    return;
  }

  server.value = first.server;
  sortBy.value = (await storedSort()) === "name" ? "name" : "size";
  // Where this server was left. Per server, because "the big directory" is a
  // property of the machine and not of the person looking at it.
  let remembered: string | null = null;
  try {
    remembered = (await sb.store.get({ scope: "server", key: LAST_PATH_KEY }))
      .value;
  } catch {
    remembered = null;
  }
  path.value = remembered ?? (await settings()).startAt;
  await app.settle();
}

async function storedSort(): Promise<string | null> {
  try {
    return (await sb.store.get({ scope: "global", key: SORT_KEY })).value;
  } catch {
    return null;
  }
}

// ------------------------------------------------------------------ the page

function pageView() {
  // Nothing is measured until the hook names a server and a directory: a
  // resource runs the first time something reads it, so not reading `level`
  // here is what keeps `open` from running a command.
  if (server.value === undefined || path.value === null) {
    return skeleton(5);
  }

  const count = removing.value;
  if (count !== null) {
    // Drawn over the reading while it runs. Removing a large tree takes as
    // long as measuring one did, and a page that did not change reads as a
    // button that did nothing.
    return column([
      bar(),
      divider(),
      padding(
        17,
        text(count === 1 ? l10n("removingOne") : l10n("removing", `${count}`)),
      ),
    ]);
  }

  const body = level.when({
    loading: () =>
      column([bar({ measuring: true }), divider(), padding(17, text(l10n("measuring")))]),
    error: (e) => failedView(e),
    data: ({ scan, filters }) => levelView(scan, filters),
  });

  // **Above the reading, not instead of it.** What `rm` refused is about the
  // delete, and the measurement on screen is still good — replacing it with a
  // failure would take away the list the user is deciding from.
  const failed = failure.value;
  if (!failed) return body;
  return column([
    padding(13, banner(failed, { icon: "warning" })),
    expanded(body),
  ]);
}

function failedView(e: unknown) {
  const at = path.value ?? ROOT;
  const up = parentOf(at);
  return column([
    bar(),
    divider(),
    notice({
      kind: "failed",
      icon: "warning",
      title: l10n("errTitle", at),
      detail: whyOf(e),
      actions: [
        { label: l10n("retry"), msg: () => reload() },
        // Somewhere to go. Without this a directory that cannot be read is a
        // page with no way off it.
        ...(up === null ? [] : [{ label: l10n("up"), msg: () => descend(up) }]),
      ],
    }),
  ]);
}

/**
 * The path and the way out, for the states that have no reading yet.
 *
 * While a scan is running the reload turns into a Stop. Reloading during one
 * would start a second scan of a directory the first is still walking, and
 * `du -x /` on a full disk is minutes of a machine's IO — so the control that
 * is there is the one somebody actually wants after the first minute.
 */
function bar(state: { measuring?: boolean } = {}) {
  const at = path.value ?? ROOT;
  const up = parentOf(at);
  return summary({
    label: at,
    value: "…",
    actions: [
      ...(up === null ? [] : [onTap(tag("↑"), () => descend(up))]),
      state.measuring
        ? onTap(tone(tag(l10n("stop")), "danger"), () => stopScan())
        : onTap(tag(l10n("reload")), () => reload()),
    ],
  });
}

/**
 * Gives up on the scan that is running.
 *
 * Nothing is drawn here: the reading rejects, and the error view says what
 * happened — including whether the command is still running on the server,
 * which is the host's answer and not this plugin's to guess.
 */
async function stopScan(): Promise<void> {
  try {
    await sb.server.cancel({ key: SCAN });
  } catch {
    // Refused, or nothing was running. Either way the page is about to draw
    // whatever the reading became.
  }
}

/** Measures this level again. A new answer replaces whatever went wrong. */
function reload(): void {
  failure.value = null;
  level.reload();
}

/** Goes to [to], which is what setting the path means. */
function descend(to: string): void {
  clearSelection();
  failure.value = null;
  path.value = to;
}

function clearSelection(): void {
  selecting.value = false;
  selected.value = new Set();
}

function levelView(
  s: Scan,
  filters: { skip: string[]; hideBelowBytes: number },
) {
  const fs = s.filesystem;
  const up = parentOf(s.path);
  const picking = selecting.value;
  const picked = selected.value;
  const by = sortBy.value;

  return column([
    summary({
      // The path is the eyebrow rather than the figure: it says where you
      // are, and what the page answers is how much is here.
      label: s.path,
      value: humanBytes(s.totalBytes),
      // The filesystem behind it, because "31G in /var" only means something
      // beside the size of the disk it is on.
      detail: fs
        ? l10n("filesystem", humanBytes(fs.usedBytes), humanBytes(fs.sizeBytes))
        : undefined,
      actions: picking
        ? [
            onTap(tone(tag(l10n("cancel")), "muted"), () => clearSelection()),
            // The count is in the label because it is the whole question a
            // person asks before pressing it.
            onTap(tone(tag(l10n("delete", `${picked.size}`)), "danger"), () =>
              remove(s),
            ),
          ]
        : [
            ...(up === null ? [] : [onTap(tag("↑"), () => descend(up))]),
            ...(s.children.length === 0
              ? []
              : [
                  onTap(tag(l10n(by === "size" ? "sortSize" : "sortName")), () =>
                    flipSort(by),
                  ),
                  onTap(tag(l10n("select")), () => (selecting.value = true)),
                ]),
            onTap(tag(l10n("reload")), () => reload()),
          ],
    }),
    ...(fs ? [padding(13, percent(fs.usedBytes / fs.sizeBytes, ""))] : []),
    // The total is short by whatever is in them, so it is said next to the
    // total rather than tucked away.
    ...(s.unreadable > 0
      ? [
          padding(
            13,
            tone(
              text(
                s.unreadable === 1
                  ? l10n("unreadableOne")
                  : l10n("unreadable", `${s.unreadable}`),
              ),
              "warning",
            ),
          ),
        ]
      : []),
    divider(),
    expanded(
      scroll(
        s.children.length === 0
          ? [
              notice({
                icon: "folder",
                title: l10n("emptyTitle"),
                detail: l10n("emptyDetail"),
                actions: [{ label: l10n("retry"), msg: () => reload() }],
              }),
            ]
          : rowsFor(s, filters, by, picking, picked),
      ),
    ),
  ]);
}

async function flipSort(by: SortBy): Promise<void> {
  const next: SortBy = by === "size" ? "name" : "size";
  sortBy.value = next;
  // Remembered, because the order somebody chose is a preference and not a
  // property of the directory they happened to be in.
  try {
    await sb.store.set({ scope: "global", key: SORT_KEY, value: next });
  } catch {
    // The order is applied either way; only the memory of it is lost.
  }
}

/**
 * The rows, after the two filters the settings page owns.
 *
 * The count of what they took is drawn under them. A list shortened without
 * saying so is how somebody concludes a directory is nearly empty, when what
 * happened is a threshold they set weeks ago.
 */
function rowsFor(
  s: { children: Entry[]; totalBytes: number },
  filters: { skip: string[]; hideBelowBytes: number },
  by: SortBy,
  picking: boolean,
  picked: ReadonlySet<string>,
) {
  const { shown, hidden } = filtered(s.children, filters);
  return [
    card(
      ordered(shown, by).map((c) =>
        rowFor(c, s.totalBytes, picking, picked),
      ),
    ),
    ...(hidden === 0
      ? []
      : [padding(11, tone(text(l10n("hiddenByFilter", `${hidden}`)), "muted"))]),
  ];
}

/**
 * The rows in the order the user asked for.
 *
 * A copy, because `Scan.children` is what the parser produced and sorting it in
 * place would make the order depend on how many times it had been drawn.
 */
function ordered(
  children: { name: string; path: string; bytes: number }[],
  by: SortBy,
) {
  const out = [...children];
  if (by === "name") {
    // `localeCompare` so `Étage` sorts where a person expects, and numeric so
    // `log.10` follows `log.9` rather than `log.1`.
    out.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }));
  } else {
    out.sort((a, b) => b.bytes - a.bytes);
  }
  return out;
}

function rowFor(
  child: { path: string; name: string; bytes: number },
  total: number,
  picking: boolean,
  picked: ReadonlySet<string>,
) {
  // A share of the parent rather than of the disk: the question at this level
  // is which of *these* took the space.
  const share = total > 0 ? child.bytes / total : 0;
  const chosen = picked.has(child.path);
  return key(
    onTap(
      tile({
        // The tint is what a selection reads as — the app's own selected row —
        // and the icon is the affordance beside it. The icon alone was one
        // grey glyph turning into another.
        selected: chosen,
        icon: picking ? (chosen ? "check" : "folder") : "folder",
        title: child.name,
        // The size and the share of the parent, right-aligned at a fixed width
        // so every bar starts and ends in the same place. A column of bars that
        // share an edge is a chart; one bar per card is not.
        trailing: sized(
          column([text(humanBytes(child.bytes)), percent(share, "")], {
            spacing: 5,
          }),
          { width: 96 },
        ),
      }),
      picking ? () => pick(child.path) : () => descend(child.path),
    ),
    // The state is part of the identity, or a row would keep the widget it had
    // before it was picked.
    `${child.path}|${chosen}|${picking}`,
  );
}

function pick(at: string): void {
  const next = new Set(selected.peek());
  if (!next.delete(at)) next.add(at);
  selected.value = next;
}

// ---------------------------------------------------------------- the delete

/**
 * Deletes what is picked, after asking.
 *
 * The one thing here that changes a machine, so:
 *
 * - The user is asked, with the paths and the total listed. `sb.ui.prompt`
 *   with no body is a confirmation, and the manifest asks for `ui.dialog`
 *   because of this and nothing else.
 * - Every path is quoted, and `--` ends the options — a directory called `-rf`
 *   is a legal directory name and it arrives here out of a listing this plugin
 *   asked the server for.
 * - The current directory is never among the candidates (it is not one of its
 *   own children) and `/` is refused outright, so there is no arrangement of
 *   taps that removes the level being looked at.
 *
 * What `rm` could not remove is reported rather than swallowed: a delete that
 * silently did nothing is worse than one that says it failed.
 */
async function remove(s: Scan): Promise<void> {
  const handle = server.peek();
  const picked = selected.peek();
  if (!handle) return;
  const paths = s.children
    .filter((c) => picked.has(c.path))
    .filter((c) => c.path !== "/" && isUsablePath(c.path));
  if (paths.length === 0) {
    clearSelection();
    return;
  }

  const bytes = paths.reduce((n, c) => n + c.bytes, 0);
  const answer = await sb.ui.prompt({
    title:
      paths.length === 1
        ? l10n("confirmOne")
        : l10n("confirmMany", `${paths.length}`),
    // The paths are the user's own and are not translated; the sentence around
    // them is.
    message: [
      l10n("confirmBody", humanBytes(bytes), s.path),
      "",
      ...paths.map((c) => c.path),
    ].join("\n"),
    confirm: l10n("confirmAction"),
  });
  if (answer.cancelled) return;

  const script = `rm -rf -- ${paths.map((c) => shellQuote(c.path)).join(" ")}`;
  removing.value = paths.length;
  try {
    const r = await sb.server.exec({
      server: handle,
      script,
      timeoutMs: TIMEOUT_MS,
    });
    if (r.code !== 0) {
      removing.value = null;
      clearSelection();
      failure.value = commandWhy(r);
      return;
    }
  } catch (e) {
    removing.value = null;
    clearSelection();
    failure.value = whyOf(e);
    return;
  }

  removing.value = null;
  clearSelection();
  // Measured again rather than subtracted: what `rm` actually removed is a
  // question for the machine, and the sizes beside every other row moved too.
  reload();
}

/**
 * What a delete said when it could not.
 *
 * Its own value rather than the reading's error: the measurement on screen is
 * still good, and replacing it with a failure would take away the list the
 * user is deciding from.
 */
const failure = state<string | null>(null);

// -------------------------------------------------------------- the settings

function settingsView() {
  return prefs.when({
    loading: () => padding(17, text(l10n("reading"))),
    error: () => padding(17, text(l10n("errUnknown"))),
    data: (s) =>
      column([
        card([
          onChange(
            toggle(crossDraft.value ?? s.crossFilesystems, {
              label: l10n("prefsCrossFs"),
              hint: l10n("prefsCrossFsHint"),
            }),
            async (value) => {
              crossDraft.value = value === true;
              await sb.store.set({
                scope: "global",
                key: CROSS_FS_KEY,
                value: value === true ? "1" : "0",
              });
            },
          ),
        ]),
        field({
          key: START_AT_KEY,
          label: l10n("prefsStartAt"),
          hint: l10n("prefsStartAtHint"),
          placeholder: ROOT,
          stored: s.startAt,
          save: (typed) => saveStartAt(typed),
        }),
        field({
          key: SKIP_KEY,
          label: l10n("prefsSkip"),
          hint: l10n("prefsSkipHint"),
          placeholder: "node_modules .cache",
          stored: s.skip.join(" "),
          save: (typed) => saveSkip(typed),
        }),
        field({
          key: HIDE_BELOW_KEY,
          label: l10n("prefsHideBelow"),
          hint: l10n("prefsHideBelowHint"),
          placeholder: "0",
          stored: s.hideBelowBytes === 0 ? "" : `${s.hideBelowBytes / 1024 / 1024}`,
          save: (typed) => saveHideBelow(typed),
        }),
        padding(13, onTap(btn(l10n("prefsReset")), () => resetPrefs())),
      ]),
  });
}

/**
 * One row of the form: a label, what it is for, the field, and why the last
 * thing typed into it was not kept.
 *
 * The value comes from the draft when there is one, so a rejected edit stays on
 * screen next to its reason — redrawing the stored value under somebody who is
 * being told their input is wrong takes away the thing they need to fix.
 */
function field(
  f: {
    key: string;
    label: string;
    hint: string;
    placeholder: string;
    stored: string;
    save: (typed: string) => Promise<void>;
  },
) {
  const why = rejected.value.get(f.key);
  const typed = draft.value.get(f.key);
  return padding(
    13,
    column(
      [
        text(f.label),
        tone(text(f.hint), "muted"),
        onChange(
          input(typed ?? f.stored, { hint: f.placeholder }),
          (value) => f.save(`${value ?? ""}`),
        ),
        ...(why ? [tone(text(why), "danger")] : []),
      ],
      { spacing: 5 },
    ),
  );
}

function setIn(
  which: typeof draft | typeof rejected,
  key: string,
  value: string | null,
): void {
  const next = new Map(which.peek());
  if (value === null) next.delete(key);
  else next.set(key, value);
  which.value = next;
}

async function saveStartAt(raw: string): Promise<void> {
  const typed = raw.trim();
  setIn(draft, START_AT_KEY, typed);
  // Rejected here rather than ignored at read time, which is what it used to
  // be: a value that is silently not used is one the user believes is in
  // effect. Empty clears it, which is how a text field says "back to the
  // default".
  //
  // Absolute, because that is what "start at" means: a relative path resolves
  // against whatever directory the command happens to run in, which is the
  // user's home and not what anybody typing `var` meant.
  if (typed !== "" && !(typed.startsWith("/") && isUsablePath(typed))) {
    setIn(rejected, START_AT_KEY, l10n("prefsErrPath"));
    return;
  }
  setIn(rejected, START_AT_KEY, null);
  await sb.store.set({
    scope: "global",
    key: START_AT_KEY,
    value: typed === "" ? null : typed,
  });
}

async function saveSkip(typed: string): Promise<void> {
  setIn(draft, SKIP_KEY, typed);
  // Free text with nothing to get wrong: anything that is not a name simply
  // matches no directory. Stored as typed so the field reads back the way it
  // was written.
  await sb.store.set({
    scope: "global",
    key: SKIP_KEY,
    value: splitNames(typed).length === 0 ? null : typed.trim(),
  });
}

async function saveHideBelow(raw: string): Promise<void> {
  const typed = raw.trim();
  setIn(draft, HIDE_BELOW_KEY, typed);
  const n = Number.parseInt(typed, 10);
  if (typed !== "" && (!Number.isFinite(n) || n < 0 || `${n}` !== typed)) {
    setIn(rejected, HIDE_BELOW_KEY, l10n("prefsErrNumber"));
    return;
  }
  setIn(rejected, HIDE_BELOW_KEY, null);
  await sb.store.set({
    scope: "global",
    key: HIDE_BELOW_KEY,
    value: typed === "" || n === 0 ? null : `${n}`,
  });
}

async function resetPrefs(): Promise<void> {
  // Every key this form owns, back to absent. Absent rather than written
  // defaults: what a default is belongs to the build, and a stored copy of one
  // is a value that stops following it.
  for (const key of [CROSS_FS_KEY, START_AT_KEY, SKIP_KEY, HIDE_BELOW_KEY]) {
    await sb.store.set({ scope: "global", key, value: null });
  }
  draft.value = new Map();
  rejected.value = new Map();
  crossDraft.value = null;
  prefs.reload();
}
