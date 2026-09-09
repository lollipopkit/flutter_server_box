#!/usr/bin/env bun
/**
 * Packs a plugin directory into `dist/<id>-<version>.sbp`.
 *
 *     bun run ../../plugin-tools/bin/pack.ts .
 *
 * With no argument it packs the current directory, which is what each plugin's
 * `bun run pack` does.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

import { packPlugin } from "../src/pack.ts";

const dirs = process.argv.slice(2).filter((a) => !a.startsWith("-"));
if (dirs.length === 0) dirs.push(".");

let failed = false;
for (const dir of dirs) {
  const root = resolve(dir);
  try {
    const packed = packPlugin(root);
    const out = join(root, "dist", packed.fileName);
    mkdirSync(dirname(out), { recursive: true });
    writeFileSync(out, packed.bytes);
    for (const warning of packed.warnings) console.warn(`  ! ${warning}`);
    console.log(
      `${out} (${packed.bytes.length} bytes, ${packed.entries.length} entries)`,
    );
  } catch (e) {
    failed = true;
    console.error(`${root}: ${e instanceof Error ? e.message : e}`);
  }
}

process.exit(failed ? 1 : 0);
