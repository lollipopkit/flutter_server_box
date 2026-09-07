/**
 * A status plugin, whole. PLUGINS.md section 9.
 *
 * Two exports, no surface, no host calls — which is why it is worth having as
 * an example: it is the smallest useful plugin there is, and everything in it
 * is checked by `satisfies Plugin` against the same types the host implements.
 */

import type {
  Plugin,
  StatusCmd,
  StatusCmdCtx,
  StatusParseCtx,
  StatusResult,
} from "../src/index.ts";

export function statusCmd({ platform }: StatusCmdCtx): StatusCmd {
  // `-Hp` is the only reason this parses at all: tab-separated, no header, and
  // byte counts rather than the human-readable sizes `zpool list` prints by
  // default and formats differently between releases.
  if (platform === "windows") throw new Error("no ZFS on Windows");
  return { cmd: "zpool list -Hp -o name,size,alloc,health" };
}

export function parse({ text }: StatusParseCtx): StatusResult {
  const items = [];
  let unreadable = 0;

  for (const line of text.split("\n")) {
    if (!line.trim()) continue;
    const [name, size, alloc, health] = line.split("\t");
    const total = Number(size);
    const used = Number(alloc);
    // A pool whose numbers did not parse is one row, not the card: `zpool`
    // prints a diagnostic to stdout on some failures, and it arrives here.
    if (!name || !Number.isFinite(total) || !Number.isFinite(used) || total <= 0) {
      unreadable++;
      continue;
    }
    items.push({
      label: name,
      value: `${gib(used)} / ${gib(total)}`,
      percent: used / total,
      tone: health === "ONLINE" ? ("success" as const) : ("danger" as const),
    });
  }

  return {
    title: "ZFS",
    items,
    // What a row cannot say. Left out rather than "0 unreadable", which is a
    // row of noise on every healthy machine.
    ...(unreadable > 0 ? { note: `${unreadable} pool(s) unreadable` } : {}),
  };
}

const gib = (bytes: number) => `${(bytes / 1024 ** 3).toFixed(1)}G`;

export default { statusCmd, parse } satisfies Plugin;
