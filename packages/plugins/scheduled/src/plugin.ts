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
 */

import {
  card,
  column,
  divider,
  expanded,
  key,
  onTap,
  onChange,
  classify,
  l10n,
  notice,
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
  type ServerHandle,
  type Surface,
  type UiOutput,
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

type State =
  | { at: "loading" }
  | { at: "ready"; schedule: Schedule; note?: string }
  | { at: "failed"; why: string };

let state: State = { at: "loading" };
let server: ServerHandle | null = null;

/**
 * What went wrong, in the user's language.
 *
 * `reason` from the SDK answers in English, which is right for a plugin that
 * ships no translations and wrong for one that does.
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

/// Whether the systemd half is read. A preference, so `global`.
const TIMERS_KEY = "includeTimers";

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
let selecting = false;
let selected = new Set<number>();

function clearSelection(): void {
  selecting = false;
  selected = new Set();
}

/**
 * The last value [includeTimers] read, for `view` — which is synchronous.
 *
 * A cache and not the source: the setting lives in the store, and this is only
 * so an empty page can say whether systemd was asked at all.
 */
let timersOn = true;

async function includeTimers(): Promise<boolean> {
  try {
    const stored = (await sb.store.get({ scope: "global", key: TIMERS_KEY }))
      .value;
    // Absent means on: a machine with systemd has timers and they belong in a
    // list of what is scheduled. The setting is for turning them off.
    timersOn = stored !== "0";
  } catch {
    timersOn = true;
  }
  return timersOn;
}

export function open(surface: Surface): UiOutput {
  if (surface.kind === "settings") {
    void drawSettings();
    return { ui: padding(17, text("…")) };
  }
  return { ui: view() };
}

/// The settings surface, which reads the store and so draws after it answers.
async function drawSettings(): Promise<void> {
  const on = await includeTimers();
  const node = card([
    onChange(
      toggle(on, {
        label: l10n("prefsTimers"),
        hint: l10n("prefsTimersHint"),
      }),
      { m: "setTimers" },
    ),
  ]);
  try {
    await sb.ui.patch({ path: "", node });
  } catch {
    // Nobody is looking at the settings page any more.
  }
}

export async function onHook(event: HookEvent): Promise<void> {
  const first = event.servers[0];
  if (!first) {
    state = { at: "failed", why: l10n("errNoServer") };
    await draw();
    return;
  }
  server = first.server;
  await read();
}

export async function onEvent(msg: unknown, value?: unknown): Promise<UiOutput> {
  const m = msg as { m: string; line?: number };
  if (m.m === "setTimers") {
    await sb.store.set({
      scope: "global",
      key: TIMERS_KEY,
      value: value === true ? "1" : "0",
    });
    await drawSettings();
    return {};
  }
  if (m.m === "reload") {
    state = { at: "loading" };
    await draw();
    await read();
  }
  if (m.m === "add") {
    await editJob(null);
    return {};
  }
  if (m.m === "edit" && typeof m.line === "number") {
    await editJob(m.line);
    return {};
  }
  if (m.m === "select") {
    selecting = true;
    return { ui: view() };
  }
  if (m.m === "cancelSelect") {
    clearSelection();
    return { ui: view() };
  }
  if (m.m === "pick" && typeof m.line === "number") {
    if (selected.has(m.line)) {
      selected.delete(m.line);
    } else {
      selected.add(m.line);
    }
    return { ui: view() };
  }
  if (m.m === "remove") {
    await removeJobs();
    return {};
  }
  if (m.m === "toggle" && typeof m.line === "number") {
    await toggleJob(m.line);
  }
  return {};
}

/**
 * Draws, and does not mind if nobody is looking.
 *
 * `sb.ui.patch` rejects when the surface is gone, which is right; awaiting it
 * unguarded would turn that into the work stopping.
 */
async function draw(): Promise<void> {
  try {
    await sb.ui.patch({ path: "", node: view() });
  } catch {
    // Nothing to report to a surface that is not there.
  }
}

async function read(): Promise<void> {
  const handle = server;
  if (!handle) return;
  try {
    const r = await sb.server.exec({
      server: handle,
      script: readCommand({ timers: await includeTimers() }),
    });
    state = { at: "ready", schedule: parse(r.stdout) };
  } catch (e) {
    state = { at: "failed", why: whyOf(e) };
  }
  await draw();
}

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
async function write(next: string[]): Promise<void> {
  const handle = server;
  if (!handle || state.at !== "ready") return;
  const { schedule } = state;

  try {
    const r = await sb.server.exec({
      server: handle,
      script: writeCommand(next, schedule.fingerprint),
    });
    const result = parseWrite(r.stdout);
    if (result.at === "conflict") {
      state = { at: "ready", schedule, note: l10n("conflict") };
      await draw();
      await read();
      return;
    }
    if (result.at === "failed") {
      state = { at: "ready", schedule, note: result.why };
      await draw();
      return;
    }
    state = {
      at: "ready",
      schedule: {
        ...schedule,
        cronLines: next,
        jobs: parse(sectioned(next)).jobs,
        fingerprint: result.fingerprint,
      },
    };
  } catch (e) {
    state = { at: "ready", schedule, note: whyOf(e) };
  }
  await draw();
}

async function toggleJob(line: number): Promise<void> {
  if (state.at !== "ready") return;
  const job = state.schedule.jobs.find((j) => j.line === line);
  if (!job) return;

  const answer = await sb.ui.prompt({
    title: l10n(job.disabled ? "confirmEnable" : "confirmDisable"),
    // The command rather than the line number: a person confirming this needs
    // to see what stops running. Not translated — it is the user's own text.
    message: `${job.when}\n${job.command}`,
    confirm: l10n(job.disabled ? "enable" : "disable"),
  });
  if (answer.cancelled) return;

  await write(toggled(state.schedule.cronLines, line));
}

/**
 * Adds a job, or edits one.
 *
 * The same form either way, because it is the same two values — and a person
 * who has just written a schedule in one dialog should not meet a different
 * one when they correct it.
 *
 * The schedule is checked before anything is written. `crontab` accepts a line
 * it cannot parse and simply never runs it, so refusing here is the only
 * moment anybody finds out.
 */
async function editJob(line: number | null): Promise<void> {
  if (state.at !== "ready") return;
  const job =
    line === null ? null : state.schedule.jobs.find((j) => j.line === line);
  if (line !== null && !job) return;

  const answer = await sb.ui.prompt({
    title: l10n(job ? "editTitle" : "addTitle"),
    fields: [
      { key: "when", label: l10n("fieldWhen"), value: job?.when ?? "0 3 * * *" },
      { key: "command", label: l10n("fieldCommand"), value: job?.command ?? "" },
    ],
    confirm: l10n("save"),
  });
  if (answer.cancelled) return;

  const when = (answer.values.when ?? "").trim();
  const command = (answer.values.command ?? "").trim();
  if (!command) {
    state = { ...state, note: l10n("errNoCommand") };
    await draw();
    return;
  }
  if (!isSchedule(when)) {
    // Named rather than described: the person typed it and needs to see which
    // part was refused.
    state = { ...state, note: l10n("errBadSchedule", when) };
    await draw();
    return;
  }

  await write(
    job
      ? edited(state.schedule.cronLines, job.line, { when, command })
      : added(state.schedule.cronLines, { when, command }),
  );
}

/**
 * Removes the picked jobs.
 *
 * By line, and all in one write: removing them one at a time would be one
 * compare-and-swap per job, and the second would meet the fingerprint the
 * first had just changed.
 */
async function removeJobs(): Promise<void> {
  if (state.at !== "ready") return;
  const jobs = state.schedule.jobs.filter((j) => selected.has(j.line));
  if (jobs.length === 0) {
    clearSelection();
    await draw();
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
  await write(removed(state.schedule.cronLines, lines));
}

/** The lines as [parse] expects to be handed them, for re-reading in place. */
const sectioned = (lines: string[]) => `cron\n${lines.join("\n")}\n`;

function view() {
  if (state.at === "loading") return padding(17, text(l10n("reading")));
  if (state.at === "failed") {
    return notice({
      kind: "failed",
      icon: "warning",
      title: l10n("errTitle"),
      detail: state.why,
      actions: [{ label: l10n("retry"), msg: { m: "reload" } }],
    });
  }

  const { schedule: s, note } = state;
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
          ? l10n(
              "breakdownOff",
              `${s.jobs.length}`,
              `${s.timers.length}`,
              `${off}`,
            )
          : l10n("breakdown", `${s.jobs.length}`, `${s.timers.length}`),
      actions: selecting
        ? [
            onTap(tone(tag(l10n("cancel")), "muted"), { m: "cancelSelect" }),
            onTap(
              tone(tag(l10n("remove", `${selected.size}`)), "danger"),
              { m: "remove" },
            ),
          ]
        : [
            ...(s.hasCron
              ? [
                  onTap(tag(l10n("add")), { m: "add" }),
                  ...(s.jobs.length === 0
                    ? []
                    : [onTap(tag(l10n("select")), { m: "select" })]),
                ]
              : []),
            onTap(tag(l10n("reload")), { m: "reload" }),
          ],
    }),
    ...(note ? [padding(13, tone(text(note), "warning"))] : []),
    divider(),
    expanded(
      scroll([
        ...(s.hasCron && s.jobs.length > 0 ? [card(s.jobs.map(cronRow))] : []),
        ...(s.timers.length > 0 ? [card(s.timers.map(timerRow))] : []),
        ...(total > 0
          ? []
          : [
              s.hasCron
                ? notice({
                    icon: "clock",
                    title: l10n("emptyTitle"),
                    detail: l10n(
                      s.timers.length === 0 && timersOn
                        ? "emptyDetailNoTimers"
                        : "emptyDetail",
                    ),
                    actions: [{ label: l10n("retry"), msg: { m: "reload" } }],
                  })
                : notice({
                    icon: "clock",
                    title: l10n("emptyNoCronTitle"),
                    detail: l10n("emptyNoCronDetail"),
                    actions: [{ label: l10n("retry"), msg: { m: "reload" } }],
                  }),
            ]),
      ]),
    ),
  ]);
}

function cronRow(job: CronJob) {
  return key(
    onTap(
      tile({
        icon: "clock",
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
      { m: "toggle", line: job.line },
    ),
    `cron:${job.line}`,
  );
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

export default { open, onHook, onEvent } satisfies Plugin;
