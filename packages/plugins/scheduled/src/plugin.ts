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
import {
  READ_COMMAND,
  parse,
  parseWrite,
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

export function open(_surface: Surface): UiOutput {
  return { ui: view() };
}

export async function onHook(event: HookEvent): Promise<void> {
  const first = event.servers[0];
  if (!first) {
    state = { at: "failed", why: "no server" };
    await draw();
    return;
  }
  server = first.server;
  await read();
}

export async function onEvent(msg: unknown): Promise<UiOutput> {
  const m = msg as { m: string; line?: number };
  if (m.m === "reload") {
    state = { at: "loading" };
    await draw();
    await read();
  }
  if (m.m === "toggle" && typeof m.line === "number") {
    await toggle(m.line);
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
    const r = await sb.server.exec({ server: handle, script: READ_COMMAND });
    state = { at: "ready", schedule: parse(r.stdout) };
  } catch (e) {
    state = { at: "failed", why: String(e) };
  }
  await draw();
}

async function toggle(line: number): Promise<void> {
  const handle = server;
  if (!handle || state.at !== "ready") return;
  const { schedule } = state;

  const job = schedule.jobs.find((j) => j.line === line);
  if (!job) return;

  // Asked before it is done, and naming the command rather than the line
  // number: a person confirming this needs to see what stops running.
  const answer = await sb.ui.prompt({
    title: job.disabled ? "Enable this job?" : "Disable this job?",
    message: `${job.when}\n${job.command}`,
    confirm: job.disabled ? "Enable" : "Disable",
  });
  if (answer.cancelled) return;

  const next = toggled(schedule.cronLines, line);
  try {
    const r = await sb.server.exec({
      server: handle,
      script: writeCommand(next, schedule.fingerprint),
    });
    const result = parseWrite(r.stdout);
    if (result.at === "conflict") {
      // Reload, not retry. What is on the machine is not what this was edited
      // from, and writing anyway is what would lose somebody's change.
      state = {
        at: "ready",
        schedule,
        note: "The crontab changed on the server. Reloaded.",
      };
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
    state = { at: "ready", schedule, note: String(e) };
  }
  await draw();
}

/** The lines as [parse] expects to be handed them, for re-reading in place. */
const sectioned = (lines: string[]) => `cron\n${lines.join("\n")}\n`;

function view() {
  if (state.at === "loading") return padding(17, text("Reading…"));
  if (state.at === "failed") {
    return padding(17, tone(text(state.why), "danger"));
  }

  const { schedule: s, note } = state;
  return column([
    padding(
      11,
      row(
        [
          expanded(
            text(`${s.jobs.length} cron · ${s.timers.length} timers`),
          ),
          onTap(tag("Reload"), { m: "reload" }),
        ],
        { spacing: 7 },
      ),
    ),
    ...(note ? [padding(11, tone(text(note), "warning"))] : []),
    divider(),
    expanded(
      scroll([
        ...(s.hasCron
          ? s.jobs.map(cronRow)
          : [padding(13, tone(text("No crontab on this machine."), "muted"))]),
        ...s.timers.map(timerRow),
        ...(s.jobs.length === 0 && s.timers.length === 0
          ? [padding(17, text("Nothing is scheduled."))]
          : []),
      ]),
    ),
  ]);
}

function cronRow(job: CronJob) {
  return key(
    onTap(
      card([
        padding(
          11,
          column(
            [
              row(
                [
                  expanded(
                    job.disabled
                      ? tone(text(job.command), "muted")
                      : text(job.command),
                  ),
                  // The state is a word, not only a colour: "off" is a fact
                  // about the machine and a person scanning this list is
                  // looking for it.
                  job.disabled ? tone(tag("off"), "muted") : tag("on"),
                ],
                { spacing: 9 },
              ),
              tone(text(job.when), "muted"),
            ],
            { spacing: 3 },
          ),
        ),
      ]),
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
function timerRow(t: { unit: string; activates: string; next: string; last: string }) {
  return key(
    card([
      padding(
        11,
        column(
          [
            row(
              [expanded(text(t.unit)), tag("timer")],
              { spacing: 9 },
            ),
            tone(text(`next ${t.next} · last ${t.last}`), "muted"),
          ],
          { spacing: 3 },
        ),
      ),
    ]),
    `timer:${t.unit}`,
  );
}

export default { open, onHook, onEvent } satisfies Plugin;
