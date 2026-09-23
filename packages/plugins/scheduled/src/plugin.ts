/**
 * What runs on a timer, and the one thing worth changing from a phone.
 *
 * The first plugin here with a write path, which is most of what it is for.
 * Turning a cron job off is small, reversible and the thing somebody actually
 * wants at 2am; editing the whole file is not, and is left to the app's own
 * editor over SFTP.
 *
 * **The write is compare-and-swap.** A crontab is the only copy and anything
 * on the machine may edit it — another client, a person over ssh, a
 * config-management run — so a read-modify-write that does not say what it
 * believed it was replacing discards whatever landed in between. Same
 * reasoning as the app's own custom-command directory.
 *
 * Written against the SDK's tracked state: the reading is a `resource`, the
 * selection and the warning line are `state`s, and every handler is a closure. What that removes is every line this file used to spend on *when to
 * redraw* — and the bug that came with them, where entering selection mode
 * changed the toolbar and left every row doing what it did before.
 */

import {
  banner,
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
  onLongPress,
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
import {
  added,
  edited,
  isSchedule,
  parse,
  parseWrite,
  readCommand,
  removed,
  toggled,
  writeCommand,
  type CronJob,
  type Schedule,
} from "./schedule.ts";

/**
 * The server this instance is about, in three states.
 *
 * `undefined` is *not asked yet* and `null` is *asked, and there is none* — a
 * page about to read something, and a page that cannot. Nothing is read until
 * the hook has answered, which is what keeps `open` from running a command
 * (PLUGINS.md 4.4).
 */
const server = state<ServerHandle | null | undefined>(undefined);

/// Whether the systemd half is read. A preference, so `global`.
const TIMERS_KEY = "includeTimers";

/**
 * Whether timers are included, as the read and the settings form both see it.
 *
 * Absent means on: a machine with systemd has timers and they belong in a list
 * of what is scheduled. The setting is for turning them off.
 */
const timersOn = state(true);

/** The reading. It reads [server] and [timersOn], so either one re-runs it. */
const schedule = resource(async () => {
  const handle = server.value;
  if (!handle) throw new NoServer();
  const r = await sb.server.exec({
    server: handle,
    script: readCommand({ timers: timersOn.value }),
  });
  return parse(r.stdout);
});

/**
 * The crontab as this plugin has just written it.
 *
 * **An answer, not a second copy.** A write hands back the new fingerprint, so
 * re-reading the machine after every edit would be one more command on a
 * machine somebody is actively editing. Cleared whenever the read runs again,
 * which is what keeps the read the source and this the shortcut.
 */
const written = state<Schedule | null>(null);

/** The line under the summary: a conflict, a refused schedule, a failure. */
const note = state<string | null>(null);

/**
 * Which jobs are picked, by line, and whether picking is on.
 *
 * The same shape the disk-usage plugin uses, deliberately: two plugins in one
 * app that both let you pick a set and remove it should not have two ways of
 * doing it.
 *
 * Cleared on every read, because a line number is an index into a file that
 * has just been replaced.
 */
const selecting = state(false);
const selected = state<ReadonlySet<number>>(new Set());

/** One machine's answer, as the tab has it so far. */
type FleetRow = {
  name: string;
  server: ServerHandle;
} & (
  | { at: "reading" }
  | { at: "ready"; jobs: number; timers: number; next: string | null }
  | { at: "failed"; why: string }
);

const fleet = state<readonly FleetRow[]>([]);

/// A surface bound to no machine, which is what a settings page and a page
/// opened on a server that has gone both are.
class NoServer extends Error {}

/**
 * What went wrong, in the user's language.
 *
 * `reason` from the SDK answers in English, which is right for a plugin that
 * ships no translations and wrong for one that does.
 */
function whyOf(e: unknown): string {
  if (e instanceof NoServer) return l10n("errNoServer");
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
  if (ctx.kind === "tab") return fleetView();
  return pageView();
});

export const { open, onEvent, dispose } = app;

/**
 * The hook: which machines, and the reading that follows.
 *
 * `settle` is not optional — the host drives an instance only while it is
 * inside a call, so a fetch a build started would not progress until something
 * else called in.
 */
export async function onHook(event: HookEvent): Promise<void> {
  timersOn.value = await storedTimers();

  if (event.contribution === "fleet") {
    await readFleet(event.servers);
    return;
  }
  server.value = event.servers[0]?.server ?? null;
  await app.settle();
}

async function storedTimers(): Promise<boolean> {
  try {
    const stored = await sb.store.get({ scope: "global", key: TIMERS_KEY });
    return stored.value !== "0";
  } catch {
    return true;
  }
}

// ------------------------------------------------------------------- the tab

/**
 * Every machine, one after another.
 *
 * **Serial, and drawn after each answer.** The alternative is a command on
 * every server at once, which on a fleet of twenty is twenty connections
 * opening because somebody looked at a tab. Each answer sets the state and the
 * page follows — a slow machine at the end costs a row that says so rather
 * than an empty page.
 */
async function readFleet(
  servers: { server: ServerHandle; name: string }[],
): Promise<void> {
  const rows: FleetRow[] = servers.map((s) => ({
    at: "reading",
    name: s.name,
    server: s.server,
  }));
  fleet.value = [...rows];
  if (rows.length === 0) return;

  const script = readCommand({ timers: timersOn.peek() });
  for (let i = 0; i < rows.length; i++) {
    const at = rows[i]!;
    try {
      const r = await sb.server.exec({ server: at.server, script });
      const parsed = parse(r.stdout);
      const next = parsed.timers
        .map((t) => t.next)
        .filter((n) => n && n !== "-")
        .sort()[0];
      rows[i] = {
        at: "ready",
        name: at.name,
        server: at.server,
        jobs: parsed.jobs.filter((j) => !j.disabled).length,
        timers: parsed.timers.length,
        next: next ?? null,
      };
    } catch (e) {
      rows[i] = { at: "failed", name: at.name, server: at.server, why: whyOf(e) };
    }
    // A new array each time, because that is what says it changed.
    fleet.value = [...rows];
  }
}

/**
 * The tab: one row per machine, and what it is running on a timer.
 *
 * A tab is not bound to a server, which is why this one asks for `server.list`
 * — the fleet is the whole subject. Tapping a row opens that server, which is
 * the question a row raises.
 */
function fleetView() {
  const rows = fleet.value;
  if (rows.length === 0) {
    return notice({
      icon: "info",
      title: l10n("fleetEmptyTitle"),
      detail: l10n("fleetEmptyDetail"),
    });
  }

  const ready = rows.filter((r) => r.at === "ready");
  const jobs = ready.reduce((n, r) => n + (r.at === "ready" ? r.jobs : 0), 0);
  const timers = ready.reduce((n, r) => n + (r.at === "ready" ? r.timers : 0), 0);

  return column([
    summary({
      label: l10n("fleetLabel"),
      value: l10n("fleetCount", `${jobs}`, `${timers}`),
      // Said while it is still going, because a total that grows without
      // explanation reads as a number that cannot be trusted.
      detail:
        ready.length === rows.length
          ? l10n("fleetOn", `${rows.length}`)
          : l10n("fleetReading", `${ready.length}`, `${rows.length}`),
      actions: [
        onTap(tag(l10n("reload")), () =>
          readFleet(rows.map((r) => ({ server: r.server, name: r.name }))),
        ),
      ],
    }),
    divider(),
    expanded(scroll([card(rows.map((row) => fleetRow(row)))])),
  ]);
}

function fleetRow(row: FleetRow) {
  const subtitle =
    row.at === "reading"
      ? l10n("reading")
      : row.at === "failed"
        ? row.why
        : row.jobs + row.timers === 0
          ? l10n("fleetNothing")
          : l10n("fleetRowCount", `${row.jobs}`, `${row.timers}`);
  return key(
    onTap(
      tile({
        icon: row.at === "failed" ? "warning" : "clock",
        title: row.name,
        subtitle,
        // The next thing that will happen on that machine, which is the one
        // field worth carrying up from the page.
        trailing:
          row.at === "ready" && row.next
            ? tone(tag(row.next), "muted")
            : undefined,
      }),
      async () => {
        try {
          // No permission of its own: opening a server the user can already
          // see is navigation, not disclosure.
          await sb.nav.openServer({ server: row.server });
        } catch {
          // A handle the host will not resolve any more — the server was
          // deleted while the tab was open. Nothing to navigate to, and taking
          // the surface down over a tap that went nowhere is worse.
        }
      },
    ),
    `${row.server}`,
  );
}

// -------------------------------------------------------------- the settings

function settingsView() {
  return card([
    onChange(
      toggle(timersOn.value, {
        label: l10n("prefsTimers"),
        hint: l10n("prefsTimersHint"),
      }),
      async (value) => {
        const on = value === true;
        timersOn.value = on;
        await sb.store.set({
          scope: "global",
          key: TIMERS_KEY,
          value: on ? "1" : "0",
        });
      },
    ),
  ]);
}

// ------------------------------------------------------------------ the page

function pageView() {
  // Nothing is read until the hook names a server: a provider is built the
  // first time something watches it, so not watching `schedule` here is what
  // keeps `open` from running a command.
  if (server.value === undefined) return skeleton(4);

  const body = schedule.when({
    loading: () => skeleton(4),
    error: (e) =>
      notice({
        kind: "failed",
        icon: "warning",
        title: l10n("errTitle"),
        detail: whyOf(e),
        actions: [{ label: l10n("retry"), msg: () => reload() }],
      }),
    data: (read) => jobsView(written.value ?? read),
  });

  // **Above the reading, not inside it.** A conflict is answered by reloading,
  // so the message about it would be drawn by the state the reload replaces —
  // it disappeared for as long as the re-read took, which is exactly when
  // somebody is looking for the reason the list changed.
  const warning = note.value;
  if (!warning) return body;
  return column([
    padding(13, banner(warning, { icon: "warning" })),
    expanded(body),
  ]);
}

/** Reads the machine again, dropping whatever this plugin last wrote. */
function reload(): void {
  written.value = null;
  note.value = null;
  clearSelection();
  schedule.reload();
}

function clearSelection(): void {
  selecting.value = false;
  selected.value = new Set();
}

function jobsView(s: Schedule) {
  const picking = selecting.value;
  const picked = selected.value;
  const total = s.jobs.length + s.timers.length;
  const off = s.jobs.filter((j) => j.disabled).length;

  return column([
    summary({
      label: l10n("summaryLabel"),
      value: total === 1 ? l10n("job") : l10n("jobs", `${total}`),
      // What the total is made of, since cron and systemd timers are two
      // different things a person may be looking for.
      detail:
        off > 0
          ? l10n("breakdownOff", `${s.jobs.length}`, `${s.timers.length}`, `${off}`)
          : l10n("breakdown", `${s.jobs.length}`, `${s.timers.length}`),
      actions: picking
        ? [
            onTap(tone(tag(l10n("cancel")), "muted"), () => clearSelection()),
            onTap(tone(tag(l10n("remove", `${picked.size}`)), "danger"), () =>
              removeJobs(s),
            ),
          ]
        : [
            ...(s.hasCron
              ? [
                  onTap(tag(l10n("add")), () => editJob(s, null)),
                  ...(s.jobs.length === 0
                    ? []
                    : [
                        onTap(
                          tag(l10n("select")),
                          () => (selecting.value = true),
                        ),
                      ]),
                ]
              : []),
            onTap(tag(l10n("reload")), () => reload()),
          ],
    }),
    divider(),
    expanded(
      scroll([
        ...(s.hasCron && s.jobs.length > 0
          ? [card(s.jobs.map((job) => cronRow(s, job, picking, picked)))]
          : []),
        ...(s.timers.length > 0 ? [card(s.timers.map(timerRow))] : []),
        ...(total > 0 ? [] : [emptyFor(s)]),
      ]),
    ),
  ]);
}

function emptyFor(s: Schedule) {
  if (!s.hasCron) {
    return notice({
      icon: "clock",
      title: l10n("emptyNoCronTitle"),
      detail: l10n("emptyNoCronDetail"),
      actions: [{ label: l10n("retry"), msg: () => reload() }],
    });
  }
  // Hoisted, because the key has to be visible to a reader — and to the test
  // that checks every key a plugin names is translated, which cannot see one
  // inside a call with its own parentheses.
  const askedForTimers = s.timers.length === 0 && timersOn.value;
  return notice({
    icon: "clock",
    title: l10n("emptyTitle"),
    detail: l10n(askedForTimers ? "emptyDetailNoTimers" : "emptyDetail"),
    actions: [{ label: l10n("retry"), msg: () => reload() }],
  });
}

function cronRow(
  s: Schedule,
  job: CronJob,
  picking: boolean,
  picked: ReadonlySet<number>,
) {
  // **In selection mode a tap picks the row.** The bar changed and the rows did
  // not, so entering it left every tap doing what it did before — asking to
  // disable the job — while `Remove 0` could never count past zero.
  const chosen = picked.has(job.line);
  // **Editing was implemented and unreachable.** `editJob` handled a line and
  // nothing on screen ever asked for one — the same class of gap as the
  // selection mode that changed the toolbar and left the rows alone. A long
  // press is where a list row keeps its second action, and it is the app's own
  // gesture for "what else can I do with this".
  const row = onLongPress(
    onTap(
      tile({
        // The row itself says it is chosen — the app tints a selected
        // `ListTile` the way it tints its own. The icon alone was one grey
        // glyph turning into another, which is a selection nobody sees.
        selected: chosen,
        icon: picking ? (chosen ? "check" : "clock") : "clock",
        // The schedule leads. A list of cron lines is read for *when*, and the
        // command is what you check once you have found the one you meant.
        title: job.when,
        subtitle: job.command,
        // The state is a word, not only a colour: "off" is a fact about the
        // machine and a person scanning this list is looking for it.
        trailing: job.disabled
          ? tone(tag(l10n("tagOff")), "muted")
          : tag(l10n("tagOn")),
      }),
      picking ? () => pick(job.line) : () => toggleJob(s, job.line),
    ),
    // Nothing while picking: the gesture belongs to the selection then, and an
    // editor opening from a list you are choosing in is a dialog nobody asked
    // for.
    picking ? () => pick(job.line) : () => editJob(s, job.line),
  );
  return key(
    row,
    // The mode and the choice are part of the row's identity, so a row that
    // changed only in what a tap means is still a different row.
    `cron:${job.line}|${chosen}|${picking}`,
  );
}

function pick(line: number): void {
  const next = new Set(selected.peek());
  if (!next.delete(line)) next.add(line);
  selected.value = next;
}

/**
 * A timer, which is read-only here.
 *
 * Enabling and disabling a unit is `systemctl`, which needs root on most
 * machines — and a plugin that asked for that would be asking for a great deal
 * more than turning a line of the user's own crontab on and off.
 */
function timerRow(t: {
  unit: string;
  activates: string;
  next: string;
  last: string;
}) {
  return key(
    tile({
      icon: "calendar",
      title: t.unit,
      subtitle: l10n("timerWhen", t.next, t.last),
      trailing: tone(tag(l10n("tagTimer")), "muted"),
    }),
    `timer:${t.unit}`,
  );
}

// ----------------------------------------------------------------- the write

/**
 * Writes `next` as the whole crontab, and folds the answer back into state.
 *
 * One place, because every edit is the same act: there is no way to change one
 * line of a crontab, so add, edit, delete and toggle all replace the file —
 * and all of them have to handle the same three answers.
 *
 * **Compare-and-swap.** The fingerprint is what was read; a machine whose
 * crontab moved since answers `conflict`, and the reply to that is to reload
 * rather than to write again. Writing anyway is what loses somebody's change.
 */
async function write(s: Schedule, next: string[]): Promise<void> {
  const handle = server.peek();
  if (!handle) return;

  try {
    const r = await sb.server.exec({
      server: handle,
      script: writeCommand(next, s.fingerprint),
    });
    const result = parseWrite(r.stdout);
    if (result.at === "conflict") {
      reload();
      note.value = l10n("conflict");
      return;
    }
    if (result.at === "failed") {
      note.value = result.why;
      return;
    }
    note.value = null;
    written.value = {
      ...s,
      cronLines: next,
      jobs: parse(sectioned(next)).jobs,
      fingerprint: result.fingerprint,
    };
  } catch (e) {
    note.value = whyOf(e);
  }
}

async function toggleJob(s: Schedule, line: number): Promise<void> {
  const job = s.jobs.find((j) => j.line === line);
  if (!job) return;

  const answer = await sb.ui.prompt({
    title: l10n(job.disabled ? "confirmEnable" : "confirmDisable"),
    // The command rather than the line number: a person confirming this needs
    // to see what stops running. Not translated — it is the user's own text.
    message: `${job.when}\n${job.command}`,
    confirm: l10n(job.disabled ? "enable" : "disable"),
  });
  if (answer.cancelled) return;

  await write(s, toggled(s.cronLines, line));
}

/**
 * Adds a job, or edits one.
 *
 * The same form either way, because it is the same two values — and a person
 * who has just written a schedule in one dialog should not meet a different
 * one when they correct it.
 *
 * **The body is a tree**, so the two fields are the app's own inputs rather
 * than bare boxes: the command grows with what is typed. Their `onChange`
 * messages are the field names — the host holds what the controls say while
 * the plugin waits for the answer, keyed by exactly those.
 *
 * The schedule is checked before anything is written. `crontab` accepts a line
 * it cannot parse and simply never runs it, so refusing here is the only
 * moment anybody finds out.
 */
async function editJob(
  s: Schedule,
  line: number | null,
): Promise<void> {
  const job = line === null ? null : s.jobs.find((j) => j.line === line);
  if (line !== null && !job) return;

  const answer = await sb.ui.prompt({
    title: l10n(job ? "editTitle" : "addTitle"),
    node: column(
      [
        onChange(
          input(job?.when ?? "0 3 * * *", { hint: l10n("fieldWhen") }),
          "when",
        ),
        onChange(
          input(job?.command ?? "", { hint: l10n("fieldCommand"), lines: 3 }),
          "command",
        ),
      ],
      { spacing: 9 },
    ),
    confirm: l10n("save"),
  });
  if (answer.cancelled) return;

  const nextWhen = (answer.values["when"] ?? "").trim();
  const command = (answer.values["command"] ?? "").trim();
  if (!command) {
    note.value = l10n("errNoCommand");
    return;
  }
  if (!isSchedule(nextWhen)) {
    // Named rather than described: the person typed it and needs to see which
    // part was refused.
    note.value = l10n("errBadSchedule", nextWhen);
    return;
  }

  await write(
    s,
    job
      ? edited(s.cronLines, job.line, { when: nextWhen, command })
      : added(s.cronLines, { when: nextWhen, command }),
  );
}

/**
 * Removes the picked jobs.
 *
 * By line, and all in one write: removing them one at a time would be one
 * compare-and-swap per job, and the second would meet the fingerprint the
 * first had just changed.
 */
async function removeJobs(s: Schedule): Promise<void> {
  const picked = selected.peek();
  const jobs = s.jobs.filter((j) => picked.has(j.line));
  if (jobs.length === 0) {
    clearSelection();
    return;
  }

  const answer = await sb.ui.prompt({
    title:
      jobs.length === 1
        ? l10n("confirmRemoveOne")
        : l10n("confirmRemove", `${jobs.length}`),
    // The user's own lines, which is what they are deciding about.
    message: jobs.map((j) => `${j.when}  ${j.command}`).join("\n"),
    confirm: l10n("remove"),
  });
  if (answer.cancelled) return;

  const lines = jobs.map((j) => j.line);
  clearSelection();
  await write(s, removed(s.cronLines, lines));
}

/** The lines as [parse] expects to be handed them, for re-reading in place. */
const sectioned = (lines: string[]) => `cron\n${lines.join("\n")}\n`;
