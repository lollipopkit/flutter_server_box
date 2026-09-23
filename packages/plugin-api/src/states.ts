/**
 * The two screens every plugin has and nobody designs: nothing here, and it
 * did not work.
 *
 * Both are moments for direction rather than mood. A failure says what
 * happened and offers the way out; an empty screen says what would put
 * something on it. Neither apologises, and neither shows the user a JavaScript
 * error — `Error: exec failed: 1` is a fact about this code, not about their
 * machine.
 *
 * Here rather than in each plugin because all three of them wrote the same
 * red-text-and-nothing-else, and the next one would too.
 */

import type { RemoteState } from "./host.ts";
import type { Node } from "./ui.ts";
import { card, column, icon, onTap, padding, row, tag, text, tone } from "./ui.ts";

/** One thing the user can do about it. */
export interface Action {
  label: string;
  /** The message `onEvent` receives. */
  msg: unknown;
}

/**
 * A block for a screen with nothing on it, or a screen that failed.
 *
 * `detail` is the sentence that explains; keep it plain and say what to do.
 * `actions` are what to do about it — a failure with no way to retry is a
 * dead end, which is what every one of these pages used to be.
 */
export function notice(n: {
  title: string;
  detail?: string;
  /** One of the fixed icon names. Absent draws none. */
  icon?: string;
  actions?: Action[];
  kind?: "empty" | "failed";
}): Node {
  const danger = n.kind === "failed";
  return padding(
    21,
    card([
      padding(
        13,
        column(
          [
            row(
              [
                ...(n.icon ? [icon(n.icon)] : []),
                danger ? tone(text(n.title), "danger") : text(n.title),
              ],
              { spacing: 9 },
            ),
            ...(n.detail ? [tone(text(n.detail), "muted")] : []),
            ...(n.actions && n.actions.length > 0
              ? [
                  row(
                    n.actions.map((a) => onTap(tag(a.label), a.msg)),
                    { spacing: 7 },
                  ),
                ]
              : []),
          ],
          { spacing: 9 },
        ),
      ),
    ]),
  );
}

/** What class of thing went wrong, as far as anything here can tell. */
export type ReasonKind =
  | "denied"
  | "unavailable"
  | "bad_request"
  | "timeout"
  | "cancelled"
  | "io"
  | "cert"
  | "decode"
  | "unknown";

/**
 * What went wrong, without deciding how to say it.
 *
 * For a plugin that ships translations: it needs the *classification* and then
 * its own `l10n` key, and [reason] below can only hand back an English
 * sentence. `permission` is set for a refusal and is the one thing the user can
 * act on — they can grant it.
 *
 * `remote` is set for `cancelled` and `timeout` from `sb.server.exec`, and says
 * whether the command was stopped on the server or is still running there. It
 * is a separate field rather than two more kinds because a plugin that does not
 * care should not have to know about it, and one that does should not have to
 * parse a string to find out.
 */
export function classify(e: unknown): {
  kind: ReasonKind;
  permission?: string;
  remote?: RemoteState;
} {
  const structured = e as {
    kind?: unknown;
    permission?: unknown;
    remote?: unknown;
  } | null;
  const kind = typeof structured?.kind === "string" ? structured.kind : "";
  const permission =
    typeof structured?.permission === "string" ? structured.permission : undefined;
  if (kind === "denied") {
    return {
      kind: "denied",
      ...(permission !== undefined ? { permission } : {}),
    };
  }
  if (kind === "unavailable") return { kind: "unavailable" };
  if (kind === "bad_request") return { kind: "bad_request" };

  // TODO: remove the message fallback after plugins requiring a pre-ABI 4
  // host are no longer supported. Older hosts did not attach structured
  // refusal fields.
  const said = `${(e as { message?: unknown } | null)?.message ?? e ?? ""}`;
  if (said.includes("permission denied")) {
    // Left out rather than set to `undefined`: the field means "there is one the
    // user could grant", and a present-but-undefined key says that too under
    // `exactOptionalPropertyTypes`. It also made `bun run typecheck` fail here,
    // which nothing but this script notices — `bun test` does not typecheck.
    const permission = /needs `([^`]+)`/.exec(said)?.[1];
    return {
      kind: "denied",
      ...(permission !== undefined ? { permission } : {}),
    };
  }
  if (said.includes("is not available on")) return { kind: "unavailable" };

  // Left out rather than set to `undefined`, for the reason above: the field
  // means "the host said which", and a run that was not stopped has no answer
  // to give.
  const said2 = structured?.remote;
  const remote: { remote?: RemoteState } =
    said2 === "stopped" || said2 === "running" ? { remote: said2 } : {};

  switch (kind) {
    case "denied":
      return { kind: "denied" };
    case "timeout":
      return { kind: "timeout", ...remote };
    case "cancelled":
      return { kind: "cancelled", ...remote };
    case "io":
      return { kind: "io" };
    case "cert":
      return { kind: "cert" };
    case "decode":
      return { kind: "decode" };
    default:
      return { kind: "unknown" };
  }
}

/**
 * What went wrong, as a sentence rather than as an exception.
 *
 * Reads `HostError.kind`, which is the whole reason that field exists — the
 * app already decided what class of thing happened, and a plugin turning it
 * back into `String(e)` throws that away and shows the user a stack-trace
 * fragment instead.
 *
 * `fallback` is for what this cannot classify. Give it something specific to
 * the plugin: "The command did not run" says more than "Something failed".
 */
export function reason(e: unknown, fallback: string): string {
  const { kind, permission, remote } = classify(e);
  switch (kind) {
    case "denied":
      return permission
        ? `This plugin was not given the "${permission}" permission. Reinstall it to grant one.`
        : "This plugin was not given permission for that.";
    case "unavailable":
      return "This host does not offer what the plugin asked for.";
    case "bad_request":
      return "The plugin sent a request this host could not read.";
    // Both say what is happening on the server now, because that is the part
    // the person in front of it cannot see and may need to act on.
    case "timeout":
      return remote === "running"
        ? "The server did not answer in time. The command is still running there."
        : "The server did not answer in time.";
    case "cancelled":
      return remote === "running"
        ? "Stopped waiting. The command is still running on the server."
        : "Stopped.";
    case "io":
      return "The server could not be reached.";
    case "cert":
      return "The server's certificate was not the one that was reviewed.";
    case "decode":
      return "The answer could not be read.";
    case "unknown":
      return fallback;
  }
}

/**
 * What a command's own failure means, from what it printed.
 *
 * A shell reports through stderr and an exit code, and the useful part is
 * almost always one recognisable line. Matching on it is not lovely, but the
 * alternative is showing `rm: cannot remove '/var/log': Permission denied` in
 * a red box and calling it done — which tells a person nothing about the one
 * thing they can act on, which is that they need a different account.
 */
export function commandReason(
  r: { code: number; stderr: string },
  fallback: string,
): string {
  const said = r.stderr.trim();
  const lower = said.toLowerCase();
  if (lower.includes("permission denied") || lower.includes("operation not permitted")) {
    return "The account this app signs in as is not allowed to do that.";
  }
  if (lower.includes("not found") && lower.includes("command")) {
    return "That command is not installed on this server.";
  }
  if (lower.includes("no such file") || lower.includes("no such directory")) {
    return "It is not there any more.";
  }
  if (lower.includes("read-only file system")) {
    return "That filesystem is mounted read-only.";
  }
  // The first line only: a command that failed usually says it once and then
  // repeats itself per path, and a wall of text is not a message.
  const first = said.split("\n")[0];
  return first && first.length > 0 ? first : fallback;
}
