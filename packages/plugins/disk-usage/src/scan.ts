/**
 * One level of `du`, and the filesystem it sits on.
 *
 * Its own module so the command building and the parsing are testable without
 * a host — and because the command building is the part with a security
 * property in it: the path comes back out of a listing the *server* produced,
 * and goes straight into a shell command.
 */

import { isUsablePath, shellQuote } from "@serverbox/plugin-api";

export interface Entry {
  path: string;
  /** The last component, which is what a row shows. */
  name: string;
  bytes: number;
}

export interface Scan {
  /** What was asked about, and the total for it. */
  path: string;
  totalBytes: number;
  children: Entry[];
  /** The filesystem's own numbers, where `df` answered. */
  filesystem?: { usedBytes: number; sizeBytes: number };

  /**
   * How many directories `du` could not read.
   *
   * **The total is short by whatever is in them**, and nothing else on the
   * page says so. This used to be thrown away with `2>/dev/null`, which meant
   * a `/` measured as an ordinary user reported a number quietly smaller than
   * the `df` figure printed beside it, and looked like a bug in the parser.
   */
  unreadable: number;
}

/**
 * One level under [path], plus the filesystem it is on.
 *
 * **`-x` is the whole reason this is usable.** Without it, `du /` walks every
 * network mount on the machine: an NFS share, a `//` SMB mount, a FUSE
 * filesystem that answers slowly and might not answer at all. Staying on one
 * filesystem is also what makes descending mean something — the number under a
 * mount point is that mount's, and asking about it separately is a different
 * question.
 *
 * `-d 1` bounds what is *reported*, not what is walked: a directory's size is
 * the sum of everything under it and there is no way to know it without
 * looking. So this is slow on a big tree by construction, and the plugin gives
 * it a timeout rather than pretending otherwise.
 *
 * `-k` rather than `-b` or `-h`: `-b` is GNU-only and `-h` is a rounded string
 * that differs between implementations. Kibibytes are what every `du` agrees
 * on.
 */
export function command(path: string, opts?: { crossFilesystems?: boolean }): string {
  if (!isUsablePath(path)) throw new Error(`not a path: ${path}`);
  // Quoted, and this is the line that matters in this file. A directory called
  // `; rm -rf ~` is a legal directory name, and it arrives here out of a
  // listing this plugin asked the server for.
  const quoted = shellQuote(path);
  // `-x` keeps the measurement on one filesystem, which is the right default:
  // `/` on a machine whose `/var` is its own mount otherwise walks both and
  // reports a total the `df` line beside it contradicts. Off, it follows
  // mounts — which is what somebody looking for where the space went across a
  // set of volumes actually wants.
  const stayOnOne = opts?.crossFilesystems ? "" : "-x ";
  return [
    `printf 'df\\n'`,
    `df -kP ${quoted} 2>/dev/null | tail -n +2`,
    `printf 'du\\n'`,
    // **`2>&1`, not `2>/dev/null`.** `du` prints one line per directory it
    // could not read, and discarding them made the total silently short. They
    // are told apart from results by shape — a result is `<number>\t<path>` —
    // which the parser already had to do for anything else on the stream.
    `du ${stayOnOne}-d 1 -k ${quoted} 2>&1`,
  ].join("\n");
}

const KIB = 1024;

export function parse(path: string, raw: string): Scan {
  let section: "df" | "du" | null = null;
  const children: Entry[] = [];
  let totalBytes = 0;
  let filesystem: Scan["filesystem"];
  let unreadable = 0;

  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (trimmed === "df" || trimmed === "du") {
      section = trimmed;
      continue;
    }
    if (!trimmed || section === null) continue;

    if (section === "df") {
      // `Filesystem 1024-blocks Used Available Capacity Mounted on`
      const cols = trimmed.split(/\s+/);
      const size = Number(cols[1]);
      const used = Number(cols[2]);
      if (Number.isFinite(size) && Number.isFinite(used) && size > 0) {
        filesystem = { usedBytes: used * KIB, sizeBytes: size * KIB };
      }
      continue;
    }

    // `<kb>\t<path>`, and a path may contain spaces — so the size is taken off
    // the front and everything after the first run of whitespace is the path,
    // rather than splitting into columns.
    const at = trimmed.search(/\s/);
    const kb = at <= 0 ? Number.NaN : Number(trimmed.slice(0, at));
    const found = at <= 0 ? "" : trimmed.slice(at).trim();
    if (!Number.isFinite(kb) || !found) {
      // Not a result, so it is `du` on stderr — one line per directory it
      // could not read. Counted rather than shown: the paths are long, there
      // may be hundreds, and what the reader needs to know is that the total
      // is short.
      unreadable++;
      continue;
    }

    if (found === path) {
      totalBytes = kb * KIB;
      continue;
    }
    // A grandchild, which `-d 1` should not have produced. Skipped rather than
    // shown at the wrong level.
    if (!isChildOf(path, found)) continue;
    children.push({ path: found, name: basename(found), bytes: kb * KIB });
  }

  // Largest first: the question is where the space went, and the answer is
  // almost always the first row.
  children.sort((a, b) => b.bytes - a.bytes);
  return { path, totalBytes, children, filesystem, unreadable };
}

/** Exactly one level below, by path rather than by asking the server again. */
function isChildOf(parent: string, child: string): boolean {
  const base = parent === "/" ? "/" : `${parent}/`;
  if (!child.startsWith(base)) return false;
  const rest = child.slice(base.length);
  return rest.length > 0 && !rest.includes("/");
}

function basename(path: string): string {
  const at = path.lastIndexOf("/");
  return at < 0 || path === "/" ? path : path.slice(at + 1);
}

/** The parent, or null at the root. */
export function parentOf(path: string): string | null {
  if (path === "/" || path === "") return null;
  const trimmed = path.endsWith("/") ? path.slice(0, -1) : path;
  const at = trimmed.lastIndexOf("/");
  if (at < 0) return null;
  return at === 0 ? "/" : trimmed.slice(0, at);
}

/**
 * Bytes as a person reads them.
 *
 * Binary units, because `du -k` counts kibibytes and every tool that reports a
 * disk this way does — a plugin that divided by 1000 would disagree with `df`
 * on the same machine.
 */
export function humanBytes(bytes: number): string {
  const units = ["B", "K", "M", "G", "T", "P"];
  let value = bytes;
  let unit = 0;
  while (value >= KIB && unit < units.length - 1) {
    value /= KIB;
    unit++;
  }
  // One decimal below 10, none above: `9.4G` and `47G` rather than `47.0G`,
  // which is a digit of noise on the number people actually compare.
  const shown = unit === 0 || value >= 10 ? Math.round(value) : value.toFixed(1);
  return `${shown}${units[unit]}`;
}
