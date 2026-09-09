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
  btn,
  card,
  classify,
  column,
  commandReason,
  divider,
  expanded,
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
 *
 * Not cancellable: `sb.server.exec` takes a timeout and nothing else. Recorded
 * in the README as the thing writing this plugin found missing.
 */
const TIMEOUT_MS = 120_000;

const ROOT = "/";
const LAST_PATH_KEY = "lastPath";

/**
 * What went wrong, in the user's language.
 *
 * `reason` and `commandReason` from the SDK answer in English, which is right
 * for a plugin that ships no translations and wrong for one that does.
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

/// Settings. Global rather than per server: how the measurement is taken is
/// the user's preference, not a property of any one machine — unlike
/// [LAST_PATH_KEY], which is where *that* machine was left.
const CROSS_FS_KEY = "crossFilesystems";
const START_AT_KEY = "startAt";
const SORT_KEY = "sortBy";

/**
 * How the rows are ordered. Largest first is the default because the question
 * is where the space went; by name is for finding one you already know of.
 */
type SortBy = "size" | "name";
let sortBy: SortBy = "size";

async function loadSort(): Promise<void> {
  try {
    const stored = (await sb.store.get({ scope: "global", key: SORT_KEY }))
      .value;
    sortBy = stored === "name" ? "name" : "size";
  } catch {
    sortBy = "size";
  }
}

/** Names left out of a listing, and the size a row has to reach to be in one. */
const SKIP_KEY = "skipNames";
const HIDE_BELOW_KEY = "hideBelowMib";

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

/** Read once per collection rather than kept, so an edit applies next scan. */
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

/**
 * The filters as the last scan read them.
 *
 * Kept here because the view is synchronous and the store is not, and refreshed
 * where the scan reads everything else — so an edit applies to the next scan
 * rather than half-applying to the one on screen.
 */
let filters = { skip: [] as string[], hideBelowBytes: 0 };

/**
 * What the settings form holds that the store does not.
 *
 * A field the user is halfway through typing is not a setting yet, and a
 * rejected one must not jump back to the stored value while they are looking at
 * why it was rejected. Both live here, and only until the surface goes.
 */
const draft = new Map<string, string>();
const rejected = new Map<string, string>();

type State =
  | { at: "idle" }
  | { at: "scanning"; path: string }
  | { at: "deleting"; path: string; count: number }
  | { at: "ready"; scan: Scan }
  | { at: "failed"; path: string; why: string };

let state: State = { at: "idle" };
let server: ServerHandle | null = null;

/**
 * Which children are picked, by absolute path, and whether picking is on.
 *
 * Cleared whenever the level changes: a selection is about what is in front of
 * you, and carrying one into another directory would mean a delete that
 * removes something off screen.
 */
let selecting = false;
let selected = new Set<string>();

function clearSelection(): void {
  selecting = false;
  selected = new Set();
}

/**
 * Which surface this instance is drawing.
 *
 * Set in `open`, which the host calls before the hook. Each surface is its own
 * instance, so the settings page's copy of this module is not the page's.
 */
let surfaceKind: SurfaceKind = "page";

export function open(surface: Surface): UiOutput {
  surfaceKind = surface.kind;
  // The settings page is not bound to a server and does not measure anything,
  // so it answers from the store rather than from `state`.
  if (surface.kind === "settings") {
    // Drawn from the hook rather than started here. **A promise a plugin leaves
    // running when a call returns does not progress**: the runtime drives an
    // instance only while it is inside a call, so the store read this form
    // needs would sit outstanding until something else happened to call in.
    // The hook is the call that always follows `open`, so that is where the
    // waiting belongs.
    return { ui: padding(17, text(l10n("reading"))) };
  }
  return { ui: view() };
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
    state = { at: "failed", path: ROOT, why: l10n("errNoServer") };
    await draw();
    return;
  }
  server = first.server;
  await loadSort();
  // Where this server was left. Per server, because "the big directory" is a
  // property of the machine and not of the person looking at it.
  const remembered = (await sb.store.get({ scope: "server", key: LAST_PATH_KEY }))
    .value;
  // Where this machine was left, or where the user said to start.
  await scan(remembered ?? (await settings()).startAt);
}

export async function onEvent({ msg, value }: PluginEvent): Promise<UiOutput> {
  const m = msg as { m: string; path?: string };
  if (m.m === "setCrossFs") {
    await sb.store.set({
      scope: "global",
      key: CROSS_FS_KEY,
      value: value === true ? "1" : "0",
    });
    await drawSettings();
    return {};
  }
  if (m.m === "setStartAt") {
    const typed = `${value ?? ""}`.trim();
    draft.set(START_AT_KEY, typed);
    // Rejected here rather than ignored at read time, which is what it used to
    // be: a value that is silently not used is one the user believes is in
    // effect. Empty clears it, which is how a text field says "back to the
    // default".
    // Absolute, because that is what "start at" means: a relative path
    // resolves against whatever directory the command happens to run in, which
    // is the user's home and not what anybody typing `var` meant.
    if (typed !== "" && !(typed.startsWith("/") && isUsablePath(typed))) {
      rejected.set(START_AT_KEY, l10n("prefsErrPath"));
      await drawSettings();
      return {};
    }
    rejected.delete(START_AT_KEY);
    await sb.store.set({
      scope: "global",
      key: START_AT_KEY,
      value: typed === "" ? null : typed,
    });
    await drawSettings();
    return {};
  }
  if (m.m === "setSkip") {
    const typed = `${value ?? ""}`;
    draft.set(SKIP_KEY, typed);
    // Free text with nothing to get wrong: anything that is not a name simply
    // matches no directory. Stored as typed so the field reads back the way it
    // was written.
    await sb.store.set({
      scope: "global",
      key: SKIP_KEY,
      value: splitNames(typed).length === 0 ? null : typed.trim(),
    });
    return {};
  }
  if (m.m === "setHideBelow") {
    const typed = `${value ?? ""}`.trim();
    draft.set(HIDE_BELOW_KEY, typed);
    const n = Number.parseInt(typed, 10);
    if (typed !== "" && (!Number.isFinite(n) || n < 0 || `${n}` !== typed)) {
      rejected.set(HIDE_BELOW_KEY, l10n("prefsErrNumber"));
      await drawSettings();
      return {};
    }
    rejected.delete(HIDE_BELOW_KEY);
    await sb.store.set({
      scope: "global",
      key: HIDE_BELOW_KEY,
      value: typed === "" || n === 0 ? null : `${n}`,
    });
    await drawSettings();
    return {};
  }
  if (m.m === "resetPrefs") {
    // Every key this form owns, back to absent. Absent rather than written
    // defaults: what a default is belongs to the build, and a stored copy of
    // one is a value that stops following it.
    for (const key of [CROSS_FS_KEY, START_AT_KEY, SKIP_KEY, HIDE_BELOW_KEY]) {
      await sb.store.set({ scope: "global", key, value: null });
    }
    draft.clear();
    rejected.clear();
    await drawSettings();
    return {};
  }
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
  if (m.m === "sort") {
    sortBy = sortBy === "size" ? "name" : "size";
    // Remembered, because the order somebody chose is a preference and not a
    // property of the directory they happened to be in.
    try {
      await sb.store.set({ scope: "global", key: SORT_KEY, value: sortBy });
    } catch {
      // The order is applied either way; only the memory of it is lost.
    }
    return { ui: view() };
  }
  if (m.m === "select") {
    selecting = true;
    return { ui: view() };
  }
  if (m.m === "cancelSelect") {
    clearSelection();
    return { ui: view() };
  }
  if (m.m === "pick" && m.path) {
    if (selected.has(m.path)) {
      selected.delete(m.path);
    } else {
      selected.add(m.path);
    }
    return { ui: view() };
  }
  if (m.m === "delete") {
    await remove();
    return {};
  }
  return {};
}

/**
 * Deletes what is picked, after asking.
 *
 * The one thing here that changes a machine, so:
 *
 * - The user is asked, with the paths and the total listed. `sb.ui.prompt`
 *   with no fields is a confirmation, and the manifest asks for `ui.dialog`
 *   because of this and nothing else.
 * - Every path is quoted, and `--` ends the options — a directory called
 *   `-rf` is a legal directory name and it arrives here out of a listing this
 *   plugin asked the server for.
 * - The current directory is never among the candidates (it is not one of its
 *   own children) and `/` is refused outright, so there is no arrangement of
 *   taps that removes the level being looked at.
 *
 * What `rm` could not remove is reported rather than swallowed: a delete that
 * silently did nothing is worse than one that says it failed.
 */
async function remove(): Promise<void> {
  const handle = server;
  if (!handle || state.at !== "ready") return;
  const paths = state.scan.children
    .filter((c) => selected.has(c.path))
    .filter((c) => c.path !== "/" && isUsablePath(c.path));
  if (paths.length === 0) {
    clearSelection();
    await draw();
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
      l10n("confirmBody", humanBytes(bytes), state.scan.path),
      "",
      ...paths.map((c) => c.path),
    ].join("\n"),
    confirm: l10n("confirmAction"),
  });
  if (answer.cancelled) return;

  const script = `rm -rf -- ${paths.map((c) => shellQuote(c.path)).join(" ")}`;
  const at = state.scan.path;
  // Drawn before it runs. Removing a large tree takes as long as measuring one
  // did, and a page that did not change reads as a button that did nothing.
  state = { at: "deleting", path: at, count: paths.length };
  await draw();
  try {
    const r = await sb.server.exec({
      server: handle,
      script,
      timeoutMs: TIMEOUT_MS,
    });
    if (r.code !== 0) {
      state = {
        at: "failed",
        path: at,
        why: commandWhy(r),
      };
      clearSelection();
      await draw();
      return;
    }
  } catch (e) {
    state = { at: "failed", path: at, why: whyOf(e) };
    clearSelection();
    await draw();
    return;
  }

  clearSelection();
  // Measured again rather than subtracted: what `rm` actually removed is a
  // question for the machine, and the sizes beside every other row moved too.
  await scan(at);
}

function current(): string | null {
  switch (state.at) {
    case "ready":
      return state.scan.path;
    case "scanning":
    case "deleting":
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

/**
 * The settings surface.
 *
 * What it shows lives in the store, so it draws once the store has answered
 * rather than synchronously out of `open` — which is why `open` returns a
 * placeholder for this surface and this patches over it.
 */
async function drawSettings(): Promise<void> {
  const s = await settings();
  const node = column([
    card([
      onChange(
        toggle(s.crossFilesystems, {
          label: l10n("prefsCrossFs"),
          hint: l10n("prefsCrossFsHint"),
        }),
        { m: "setCrossFs" },
      ),
    ]),
    field({
      key: START_AT_KEY,
      label: l10n("prefsStartAt"),
      hint: l10n("prefsStartAtHint"),
      placeholder: ROOT,
      stored: s.startAt,
      msg: "setStartAt",
    }),
    field({
      key: SKIP_KEY,
      label: l10n("prefsSkip"),
      hint: l10n("prefsSkipHint"),
      placeholder: "node_modules .cache",
      stored: s.skip.join(" "),
      msg: "setSkip",
    }),
    field({
      key: HIDE_BELOW_KEY,
      label: l10n("prefsHideBelow"),
      hint: l10n("prefsHideBelowHint"),
      placeholder: "0",
      stored: s.hideBelowBytes === 0 ? "" : `${s.hideBelowBytes / 1024 / 1024}`,
      msg: "setHideBelow",
    }),
    padding(13, onTap(btn(l10n("prefsReset")), { m: "resetPrefs" })),
  ]);
  try {
    await sb.ui.patch({ path: "", node });
  } catch {
    // Nobody is looking at the settings page any more.
  }
}

/**
 * One row of the form: a label, what it is for, the field, and why the last
 * thing typed into it was not kept.
 *
 * The value comes from the draft when there is one, so a rejected edit stays on
 * screen next to its reason — redrawing the stored value under somebody who is
 * being told their input is wrong takes away the thing they need to fix.
 */
function field(f: {
  key: string;
  label: string;
  hint: string;
  placeholder: string;
  stored: string;
  msg: string;
}) {
  const why = rejected.get(f.key);
  return padding(
    13,
    column(
      [
        text(f.label),
        tone(text(f.hint), "muted"),
        onChange(input(draft.get(f.key) ?? f.stored, { hint: f.placeholder }), {
          m: f.msg,
        }),
        ...(why ? [tone(text(why), "danger")] : []),
      ],
      { spacing: 5 },
    ),
  );
}

async function scan(path: string): Promise<void> {
  const handle = server;
  if (!handle) return;

  // A selection is about what is in front of you. Carried into another
  // directory it would mean a delete that removes something off screen.
  clearSelection();

  // Drawn before the command runs. A level can take a minute, and a tap that
  // shows nothing for a minute reads as a tap that did nothing.
  state = { at: "scanning", path };
  await draw();

  try {
    // One read for everything the scan needs, including the two filters the
    // view applies — the view is synchronous and the store is not, so they are
    // taken here and applied to what this scan produces.
    const s = await settings();
    filters = { skip: s.skip, hideBelowBytes: s.hideBelowBytes };
    const r = await sb.server.exec({
      server: handle,
      script: command(path, { crossFilesystems: s.crossFilesystems }),
      timeoutMs: TIMEOUT_MS,
    });
    state = { at: "ready", scan: parse(path, r.stdout) };
  } catch (e) {
    state = { at: "failed", path, why: whyOf(e) };
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
    return column([
      bar(state.path),
      divider(),
      padding(17, text(l10n("measuring"))),
    ]);
  }
  if (state.at === "deleting") {
    return column([
      bar(state.path),
      divider(),
      padding(
        17,
        text(
          state.count === 1
            ? l10n("removingOne")
            : l10n("removing", `${state.count}`),
        ),
      ),
    ]);
  }
  if (state.at === "failed") {
    const up = parentOf(state.path);
    return column([
      bar(state.path),
      divider(),
      notice({
        kind: "failed",
        icon: "warning",
        title: l10n("errTitle", state.path),
        detail: state.why,
        actions: [
          { label: l10n("retry"), msg: { m: "reload" } },
          // Somewhere to go. Without this a directory that cannot be read is a
          // page with no way off it.
          ...(up === null ? [] : [{ label: l10n("up"), msg: { m: "up" } }]),
        ],
      }),
    ]);
  }

  const { scan: s } = state;
  const fs = s.filesystem;
  const up = parentOf(s.path);

  return column([
    summary({
      // The path is the eyebrow rather than the figure: it says where you
      // are, and what the page answers is how much is here.
      label: s.path,
      value: humanBytes(s.totalBytes),
      // The filesystem behind it, because "31G in /var" only means something
      // beside the size of the disk it is on.
      detail: fs
        ? l10n(
            "filesystem",
            humanBytes(fs.usedBytes),
            humanBytes(fs.sizeBytes),
          )
        : undefined,
      actions: selecting
        ? [
            onTap(tone(tag(l10n("cancel")), "muted"), { m: "cancelSelect" }),
            // The count is in the label because it is the whole question a
            // person asks before pressing it.
            onTap(
              tone(tag(l10n("delete", `${selected.size}`)), "danger"),
              { m: "delete" },
            ),
          ]
        : [
            ...(up === null ? [] : [onTap(tag("↑"), { m: "up" })]),
            ...(s.children.length === 0
              ? []
              : [
                  onTap(
                    tag(l10n(sortBy === "size" ? "sortSize" : "sortName")),
                    { m: "sort" },
                  ),
                  onTap(tag(l10n("select")), { m: "select" }),
                ]),
            onTap(tag(l10n("reload")), { m: "reload" }),
          ],
    }),
    ...(fs
      ? [padding(13, percent(fs.usedBytes / fs.sizeBytes, ""))]
      : []),
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
                actions: [{ label: l10n("retry"), msg: { m: "reload" } }],
              }),
            ]
          : rowsFor(s),
      ),
    ),
  ]);
}

/**
 * The rows, after the two filters the settings page owns.
 *
 * The count of what they took is drawn under them. A list shortened without
 * saying so is how somebody concludes a directory is nearly empty, when what
 * happened is a threshold they set weeks ago.
 */
function rowsFor(s: { children: Entry[]; totalBytes: number }) {
  const { shown, hidden } = filtered(s.children, filters);
  return [
    card(ordered(shown).map((c) => rowFor(c, s.totalBytes))),
    ...(hidden === 0
      ? []
      : [padding(11, tone(text(l10n("hiddenByFilter", `${hidden}`)), "muted"))]),
  ];
}

/** The path, the way back up, and a way to ask again. */
/** The path and the way out, for the states that have no reading yet. */
function bar(path: string) {
  const up = parentOf(path);
  return summary({
    label: path,
    value: "…",
    actions: [
      ...(up === null ? [] : [onTap(tag("↑"), { m: "up" })]),
      onTap(tag("Reload"), { m: "reload" }),
    ],
  });
}

/**
 * The rows in the order the user asked for.
 *
 * A copy, because `Scan.children` is what the parser produced and sorting it
 * in place would make the order depend on how many times it had been drawn.
 */
function ordered(children: { name: string; path: string; bytes: number }[]) {
  const out = [...children];
  if (sortBy === "name") {
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
) {
  // A share of the parent rather than of the disk: the question at this level
  // is which of *these* took the space.
  const share = total > 0 ? child.bytes / total : 0;
  const picked = selected.has(child.path);
  return key(
    onTap(
      tile({
        // The icon carries the state while picking, so a row says which it is
        // without a second control taking the width the size needs.
        icon: selecting ? (picked ? "check" : "folder") : "folder",
        title: child.name,
        // The size and the share of the parent, right-aligned at a fixed
        // width so every bar starts and ends in the same place. A column of
        // bars that share an edge is a chart; one bar per card is not.
        trailing: sized(
          column(
            [text(humanBytes(child.bytes)), percent(share, "")],
            { spacing: 5 },
          ),
          { width: 96 },
        ),
      }),
      selecting
        ? { m: "pick", path: child.path }
        : { m: "open", path: child.path },
    ),
    // The state is part of the identity, or a row would keep the widget it had
    // before it was picked.
    `${child.path}|${picked}|${selecting}`,
  );
}

export default { open, onHook, onEvent } satisfies Plugin;
