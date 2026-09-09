#!/usr/bin/env bun
/**
 * Checks that a repository and the packages it names agree.
 *
 *     bun run packages/plugin-tools/bin/verify.ts ../serverbox-plugins
 *     bun run packages/plugin-tools/bin/verify.ts https://github.com/lollipopkit/serverbox-plugins
 *
 * Takes a directory or a repository address. **The address form is the one that
 * matters**: it fetches what a client fetches — a tarball of the latest tree —
 * and checks it. Everything else in this package works from the bytes on the
 * machine that built them, and the ways publishing goes wrong all live in the
 * gap between those and the ones an app downloads: a package that was never
 * committed, a plugin file committed without it, a tree edited by hand.
 *
 * Every version of every plugin is read, its bytes located (in the repository or
 * at its `url`), and compared against the digest and size the file gave it. The
 * manifest *inside* each package is compared against the file that names it,
 * because a file pointing at another plugin's package is a plausible mistake
 * with an implausible symptom.
 */
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { join } from "node:path";

import {
  idOfLayout,
  manifestOf,
  pluginsDir,
  readPlugin,
  readRepoFile,
  type RepoPlugin,
} from "../src/repo.ts";
import { fetchRepoArchive, isRepoAddress } from "../src/fetch.ts";

const where = process.argv[2];
if (!where) {
  console.error("usage: verify.ts <repository directory or address>");
  process.exit(2);
}

/** The repository as a flat map of path to bytes, however it was named. */
async function open(source: string): Promise<Map<string, Uint8Array>> {
  if (isRepoAddress(source)) return fetchRepoArchive(source);

  const files = new Map<string, Uint8Array>();
  const walk = (dir: string, prefix: string) => {
    if (!existsSync(dir)) return;
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.name === ".git") continue;
      if (entry.isDirectory()) walk(join(dir, entry.name), rel);
      else files.set(rel, new Uint8Array(readFileSync(join(dir, entry.name))));
    }
  };
  walk(source, "");
  return files;
}

const files = await open(where);
const text = (path: string) =>
  new TextDecoder().decode(files.get(path) ?? new Uint8Array());

if (!files.has("repo.toml")) {
  console.error(`${where}: no repo.toml, so this is not a plugin repository`);
  process.exit(1);
}
const repo = readRepoFile(text("repo.toml"));

const plugins: RepoPlugin[] = [];
let bad = 0;

for (const path of [...files.keys()].sort()) {
  if (idOfLayout(path) === null) continue;
  try {
    plugins.push(readPlugin(text(path), path));
  } catch (e) {
    bad++;
    console.error(`✗ ${e instanceof Error ? e.message : e}`);
  }
}

let checked = 0;

for (const plugin of plugins) {
  for (const release of plugin.versions) {
    const name = `${plugin.id} ${release.version}`;
    let bytes: Uint8Array | undefined;

    if (release.path !== undefined) {
      bytes = files.get(release.path);
      if (!bytes) {
        bad++;
        console.error(`✗ ${name}: ${release.path} is not in the repository`);
        continue;
      }
    } else {
      try {
        const res = await fetch(release.url!, { redirect: "follow" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        bytes = new Uint8Array(await res.arrayBuffer());
      } catch (e) {
        bad++;
        console.error(`✗ ${name}: ${release.url} — ${e instanceof Error ? e.message : e}`);
        continue;
      }
    }

    const problems: string[] = [];
    const digest = createHash("sha256").update(bytes).digest("hex");
    if (release.sha256 !== digest) {
      problems.push(`sha256 ${release.sha256} but the bytes are ${digest}`);
    }
    if (release.size !== bytes.length) {
      problems.push(`size ${release.size} but the bytes are ${bytes.length}`);
    }
    try {
      const manifest = manifestOf(bytes, name);
      if (manifest.id !== plugin.id) problems.push(`the package is ${manifest.id}`);
      if (manifest.version !== release.version) {
        problems.push(`the package is version ${manifest.version}`);
      }
      if (manifest.abi !== release.abi) {
        problems.push(`the package needs abi ${manifest.abi}`);
      }
    } catch (e) {
      problems.push(`unreadable: ${e instanceof Error ? e.message : e}`);
    }

    checked++;
    if (problems.length === 0) {
      console.log(`✓ ${name} (${bytes.length} bytes)`);
    } else {
      bad++;
      for (const problem of problems) console.error(`✗ ${name}: ${problem}`);
    }
  }
}

// A package in the repository that nothing lists is dead weight in every
// client's download, and usually the leftover of a version that was withdrawn.
for (const path of files.keys()) {
  if (!path.startsWith("packages/") || !path.endsWith(".sbp")) continue;
  const listed = plugins.some((p) => p.versions.some((v) => v.path === path));
  if (!listed) console.warn(`! ${path} is in the repository and nothing lists it`);
}

console.log(
  `${repo.name ?? where}: ${checked} version(s) in ${plugins.length} plugin(s), ` +
    `${bad} problem(s)`,
);
process.exit(bad === 0 ? 0 : 1);
