#!/usr/bin/env bun
/**
 * Stages a plugin into `dist/`, so the directory the app loads is a whole one.
 *
 *     bun run ../../plugin-tools/bin/stage.ts .
 *
 * A desktop build can be pointed at a plugin's directory instead of installing
 * it, and what it reads there is `manifest.json`, `plugin.js`, `l10n/*.json`
 * and `icon.png` — the same list a `.sbp` carries, which is why both come from
 * `pluginEntries`.
 *
 * **The build used to copy the manifest and nothing else.** `bun build` writes
 * `dist/plugin.js`, so a development directory had a script and a manifest and
 * no translations: every string in it drew as `l10n.summaryLabel`, in a plugin
 * whose packaged copy was fully translated. Two lists, one of them forgotten —
 * the same failure the packer had before it was made the only packer.
 */
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

import { pluginEntries } from "../src/pack.ts";

const dirs = process.argv.slice(2).filter((a) => !a.startsWith("-"));
if (dirs.length === 0) dirs.push(".");

let failed = false;
for (const dir of dirs) {
  const root = resolve(dir);
  try {
    const { entries, warnings } = pluginEntries(root);
    const dist = join(root, "dist");
    // Whatever was staged before, gone: a locale dropped from the source would
    // otherwise stay behind in `dist/` and keep being loaded.
    rmSync(join(dist, "l10n"), { recursive: true, force: true });
    // `plugin.js` is already in there — it is what `bun build` wrote and what
    // `pluginEntries` just read — so it is written back unchanged rather than
    // special-cased.
    for (const entry of entries) {
      const target = join(dist, entry.name);
      mkdirSync(dirname(target), { recursive: true });
      writeFileSync(target, entry.data);
    }
    for (const warning of warnings) console.warn(`  ! ${warning}`);
    console.log(`${dist} (${entries.length} files)`);
  } catch (e) {
    failed = true;
    console.error(`${root}: ${e instanceof Error ? e.message : e}`);
  }
}

process.exit(failed ? 1 : 0);
