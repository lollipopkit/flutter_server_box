/**
 * What runs on a timer, out of `crontab -l` and `systemctl list-timers`.
 *
 * Two sources that answer the same question differently: cron says *when* and
 * nothing about what happened, systemd says when it last ran and whether that
 * worked. Both are shown, and neither is translated into the other's shape.
 */

import { shellQuote } from "@serverbox/plugin-api";

/** One line of the user's crontab that schedules something. */
export interface CronJob {
  /** Its position in the file, which is how an edit names it. */
  line: number;
  /** The five (or six, with a year) schedule fields, or `@reboot` and friends. */
  when: string;
  command: string;
  /** Whether the line is commented out. */
  disabled: boolean;
}

export interface Timer {
  unit: string;
  /** What it starts. */
  activates: string;
  /** As systemd printed them — absolute, and left alone. */
  next: string;
  last: string;
}

export interface Schedule {
  /** Every line of the crontab, verbatim, so an edit can write it back whole. */
  cronLines: string[];
  jobs: CronJob[];
  timers: Timer[];
  /**
   * `cksum` of the crontab as it was read.
   *
   * The crontab is the only copy and anything else on the machine may edit it
   * — another client, a person over ssh, a config-management run. A write that
   * does not say what it believed it was replacing silently discards whatever
   * landed in between, which is the same reasoning the app's own
   * custom-command directory is built on.
   */
  fingerprint: string;
  /** Whether the machine has a crontab command at all. */
  hasCron: boolean;
}

/** Reads both, and the fingerprint the next write will have to match. */
export const READ_COMMAND = [
  `printf 'cron\\n'`,
  `crontab -l 2>/dev/null`,
  `printf 'cronsum\\n'`,
  // `cksum` is POSIX and on every machine that has `crontab`. A missing
  // crontab prints nothing and sums to the empty string's sum, which is a
  // real answer: "there is no crontab" and "the crontab is empty" are the
  // same thing to a writer.
  `crontab -l 2>/dev/null | cksum`,
  `printf 'hascron\\n'`,
  `command -v crontab >/dev/null 2>&1 && printf 'yes\\n'`,
  `printf 'timers\\n'`,
  `systemctl list-timers --all --no-pager --no-legend 2>/dev/null`,
].join("\n");

/**
 * Replaces the crontab, but only if it still looks like [expect].
 *
 * Compare-and-swap rather than a plain write. The check and the write are one
 * command so nothing can land between them, and a refusal is a word on stdout
 * rather than an exit code — an exit code says "it did not work" where the
 * caller needs "it did not work *because somebody else got there first*",
 * which is answered by reloading rather than by retrying.
 */
export function writeCommand(lines: string[], expect: string): string {
  // No validity check on the body: a crontab is a file and may contain
  // anything, including the newlines that make `isUsablePath` refuse a path.
  // `shellQuote` is what makes it safe, and it is enough on its own.
  const body = lines.join("\n");
  return [
    `cur=$(crontab -l 2>/dev/null | cksum)`,
    `if [ "$cur" != ${shellQuote(expect)} ]; then printf 'conflict\\n'; exit 0; fi`,
    // A trailing newline, because cron requires one on the last line and a
    // crontab written without it loses that entry on some implementations.
    `printf '%s\\n' ${shellQuote(body)} | crontab - 2>&1 || { printf 'failed\\n'; exit 0; }`,
    `printf 'ok\\n'`,
    `crontab -l 2>/dev/null | cksum`,
  ].join("\n");
}

export type WriteResult =
  | { at: "ok"; fingerprint: string }
  /** Somebody else edited it. Reload, do not retry. */
  | { at: "conflict" }
  | { at: "failed"; why: string };

export function parseWrite(raw: string): WriteResult {
  const lines = raw.split("\n").map((l) => l.trim());
  if (lines.includes("conflict")) return { at: "conflict" };
  const at = lines.indexOf("ok");
  if (at < 0) {
    const why = lines.filter(Boolean).join(" ") || "the write said nothing";
    return { at: "failed", why };
  }
  return { at: "ok", fingerprint: (lines[at + 1] ?? "").trim() };
}

export function parse(raw: string): Schedule {
  let section: string | null = null;
  const cronLines: string[] = [];
  const sumLines: string[] = [];
  const timerLines: string[] = [];
  let hasCron = false;

  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (["cron", "cronsum", "hascron", "timers"].includes(trimmed)) {
      section = trimmed;
      continue;
    }
    switch (section) {
      case "cron":
        cronLines.push(line);
        break;
      case "cronsum":
        if (trimmed) sumLines.push(trimmed);
        break;
      case "hascron":
        if (trimmed === "yes") hasCron = true;
        break;
      case "timers":
        if (trimmed) timerLines.push(line);
        break;
    }
  }

  // A trailing empty line is an artefact of the section marker that follows
  // it, not part of the file.
  while (cronLines.length > 0 && cronLines[cronLines.length - 1] === "") {
    cronLines.pop();
  }

  return {
    cronLines,
    jobs: cronLines.map(parseCronLine).filter((j): j is CronJob => j !== null),
    timers: timerLines.map(parseTimer).filter((t): t is Timer => t !== null),
    fingerprint: sumLines.join(" "),
    hasCron,
  };
}

/**
 * One crontab line, or null for a comment, a blank, or an assignment.
 *
 * A commented-out *job* is a job — that is how this plugin disables one, and
 * how most people do it by hand — so a `#` line is looked at rather than
 * skipped. A `#` line that is prose stays prose: it only becomes a job if what
 * follows the hash parses as one.
 */
export function parseCronLine(line: string, index: number): CronJob | null {
  const trimmed = line.trim();
  if (!trimmed) return null;

  const disabled = trimmed.startsWith("#");
  const body = disabled ? trimmed.replace(/^#+\s*/, "") : trimmed;
  if (!body) return null;

  // `MAILTO=root`, `PATH=/usr/bin` — settings, not jobs.
  if (/^[A-Za-z_][A-Za-z0-9_]*\s*=/.test(body)) return null;

  if (body.startsWith("@")) {
    const at = body.search(/\s/);
    if (at < 0) return null;
    return {
      line: index,
      when: body.slice(0, at),
      command: body.slice(at).trim(),
      disabled,
    };
  }

  // Five fields then the command. Split on the first five runs of whitespace
  // rather than on all of them, because the command is full of spaces.
  const fields: string[] = [];
  let rest = body;
  for (let i = 0; i < 5; i++) {
    const at = rest.search(/\s/);
    if (at < 0) return null;
    fields.push(rest.slice(0, at));
    rest = rest.slice(at).trimStart();
  }
  if (!rest) return null;
  // Every field has to look like one, or this is prose that happened to have
  // five words in it — which is what most comments are.
  if (!fields.every(isCronField)) return null;

  return { line: index, when: fields.join(" "), command: rest, disabled };
}

/**
 * The names cron accepts in the month and day-of-week fields.
 *
 * Enumerated rather than allowed as "letters", which is what this was and what
 * made `# run this every day at three` parse as a job — five words followed by
 * a sixth is the shape of a schedule *and* the shape of most English. A
 * comment is the commonest thing in a crontab, so getting this wrong shows up
 * on the first real file.
 *
 * Not checked against the field's position: `JAN` in the minute field is
 * something cron itself refuses, and refusing to *show* it here would hide a
 * line the user needs to see in order to fix.
 */
const CRON_NAMES = new Set([
  "jan", "feb", "mar", "apr", "may", "jun",
  "jul", "aug", "sep", "oct", "nov", "dec",
  "sun", "mon", "tue", "wed", "thu", "fri", "sat",
]);

/**
 * Whether one whitespace-separated field is one cron would accept.
 *
 * A field is a comma-separated list of terms, and a term is `*`, a number, a
 * name, or a range of those — each optionally with a `/step`.
 */
function isCronField(field: string): boolean {
  if (!field) return false;
  return field.split(",").every((part) => {
    const [value, step, ...rest] = part.split("/");
    if (rest.length > 0) return false;
    if (step !== undefined && !/^[0-9]+$/.test(step)) return false;
    if (value === "*") return true;
    if (!value) return false;
    const bounds = value.split("-");
    return bounds.length <= 2 && bounds.every(isCronTerm);
  });
}

const isCronTerm = (t: string) =>
  /^[0-9]+$/.test(t) || CRON_NAMES.has(t.toLowerCase());

/**
 * One row of `systemctl list-timers --no-legend`:
 *
 * ```text
 * Mon 2026-09-08 06:00:00 UTC 8h left Sun 2026-09-07 06:00:00 UTC 15h ago logrotate.timer logrotate.service
 * ```
 *
 * Read from the right, because the two dates are full of spaces and the two
 * columns that are not are at the end. `n/a` is what a timer that has never
 * run prints, and is left as it is rather than turned into an empty string —
 * "never" is an answer.
 */
export function parseTimer(line: string): Timer | null {
  const cols = line.trim().split(/\s+/);
  if (cols.length < 3) return null;

  const activates = cols[cols.length - 1]!;
  const unit = cols[cols.length - 2]!;
  if (!unit.endsWith(".timer")) return null;

  const middle = cols.slice(0, cols.length - 2).join(" ");
  // The two halves meet at `left`/`ago`/`n/a`; splitting on the first of those
  // that ends the next-run half is what tells them apart.
  const at = middle.search(/\s(left|n\/a)\s|\sleft$/);
  const next = at < 0 ? middle : middle.slice(0, at + " left".length).trim();
  const last = at < 0 ? "" : middle.slice(at + " left".length).trim();
  return { unit, activates, next: next || "n/a", last: last || "n/a" };
}

/**
 * The crontab with one line's `#` added or removed.
 *
 * Returns the whole file, because that is what `crontab -` takes: there is no
 * way to edit one line of a crontab, and pretending otherwise is how a
 * read-modify-write loses the lines it did not know about.
 */
export function toggled(lines: string[], index: number): string[] {
  const out = [...lines];
  const line = out[index];
  if (line === undefined) return out;
  const trimmed = line.trimStart();
  const indent = line.slice(0, line.length - trimmed.length);
  out[index] = trimmed.startsWith("#")
    ? indent + trimmed.replace(/^#+\s?/, "")
    : `${indent}#${trimmed}`;
  return out;
}
