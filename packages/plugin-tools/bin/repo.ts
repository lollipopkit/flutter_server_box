#!/usr/bin/env bun
/**
 * Writes a plugin repository: one TOML file per plugin, and nothing binary.
 *
 *     bun run packages/plugin-tools/bin/repo.ts --repo ../serverbox-plugins
 *
 * With no paths it takes every `packages/plugins/＊/dist/＊.sbp` in this
 * checkout. What is already in the repository is read first and merged into —
 * see `buildRepo`, and the reason a plugin's file keeps versions this run knows
 * nothing about.
 *
 * A file `<package>.notes` beside a `.sbp` becomes that release's `notes`.
 * Nothing writes it — "what changed" is not derivable from a package — and a
 * file that carried notes once keeps them.
 */
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";

import {
  buildRepo,
  idOfLayout,
  pluginsDir,
  readRepoFile,
  writeRepoFile,
  type PackageInput,
} from "../src/repo.ts";

function fail(message: string): never {
  console.error(message);
  console.error(
    "usage: repo.ts --repo <dir> [--base-url <url>] [--name <name>] " +
      "[--allow-republish] [<file.sbp> ...]",
  );
  process.exit(2);
}

/**
 * Where the official repository's packages are downloaded from.
 *
 * Its own releases, one per plugin version — see `tagOf`. So the repository is
 * text and the packages are releases of the same repository, which is where
 * somebody looking for a version's bytes would look first.
 */
const defaultBaseUrl =
  "https://github.com/lollipopkit/serverbox-plugins/releases/download";

const values = new Map<string, string>();
const switches = new Set<string>();
const paths: string[] = [];

const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const arg = argv[i]!;
  if (!arg.startsWith("--")) {
    paths.push(arg);
    continue;
  }
  const name = arg.slice(2);
  if (name === "allow-republish") {
    switches.add(name);
    continue;
  }
  if (name !== "repo" && name !== "name" && name !== "base-url") {
    fail(`no such option: ${arg}`);
  }
  const value = argv[++i];
  if (value === undefined || value.startsWith("--")) fail(`${arg} needs a value`);
  values.set(name, value);
}

const repoDir = resolve(values.get("repo") ?? fail("--repo is required"));
if (!existsSync(repoDir)) fail(`${repoDir} is not there`);

if (paths.length === 0) {
  // This checkout: bin/ → plugin-tools/ → packages/ → root.
  const root = resolve(import.meta.dir, "../../..");
  const glob = new Bun.Glob("packages/plugins/*/dist/*.sbp");
  for (const found of glob.scanSync({ cwd: root })) paths.push(join(root, found));
  if (paths.length === 0) {
    fail("no packages: run `bun run pack` in the plugins first");
  }
}

/** Every plugin file the repository already has, by repository-relative path. */
function readExisting(): Map<string, string> {
  const out = new Map<string, string>();
  const walk = (dir: string, prefix: string) => {
    if (!existsSync(dir)) return;
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.isDirectory()) {
        walk(join(dir, entry.name), rel);
      } else if (idOfLayout(rel) !== null) {
        out.set(rel, readFileSync(join(dir, entry.name), "utf8"));
      }
    }
  };
  walk(join(repoDir, pluginsDir), pluginsDir);
  return out;
}

const packages: PackageInput[] = paths.map((path) => {
  const bytes = new Uint8Array(readFileSync(path));
  const notes = `${path}.notes`;
  return {
    bytes,
    fileName: basename(path),
    ...(existsSync(notes) ? { notes: readFileSync(notes, "utf8").trim() } : {}),
  };
});

try {
  // `repo.toml` is what says a tarball is a plugin repository at all, so it is
  // written when missing rather than being something to remember.
  const repoFile = join(repoDir, "repo.toml");
  if (existsSync(repoFile)) {
    readRepoFile(readFileSync(repoFile, "utf8"));
  } else {
    writeFileSync(
      repoFile,
      writeRepoFile(values.get("name") ?? basename(repoDir)),
    );
    console.log("+ repo.toml");
  }

  const { files, notes } = buildRepo({
    packages,
    baseUrl: values.get("base-url") ?? defaultBaseUrl,
    existing: readExisting(),
    allowRepublish: switches.has("allow-republish"),
  });

  for (const [path, text] of files) {
    const target = join(repoDir, path);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, text);
  }

  for (const note of notes) console.log(note);
  console.log(`${repoDir}: ${files.size} plugin file(s)`);
} catch (e) {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
}
