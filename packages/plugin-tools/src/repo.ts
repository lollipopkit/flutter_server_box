/**
 * A plugin repository: one TOML file per plugin, and nothing binary.
 *
 * **Shaped after a Homebrew tap, and for the same reasons.** A tap is a git
 * repository of one file per formula, each naming where the thing itself lives;
 * a client fetches the tree and reads what is in it. So there is no single
 * document every publish rewrites, a pull request touches exactly the plugin it
 * is about, and the repository stays text — the packages are release assets of
 * whatever project publishes them, which for the bundled three is the app's own
 * repository.
 *
 * ```
 * repo.toml                              schema, name
 * plugins/app/serverbox/diskusage.toml   one file per plugin, naming a url
 * ```
 *
 * The path is derived from the id and checked against it — see [[layoutOf]].
 *
 * Two rules here are decisions rather than mechanics, both carried over from
 * when this wrote a single `index.json`:
 *
 * - **a plugin's file is merged into, never replaced.** It lists every version
 *   still on offer, because one repository serves apps of different ages and
 *   each installs the newest release its own ABI can run. Writing only what is
 *   in `dist/` today would drop the rest, and an older app would see the plugin
 *   vanish rather than see a version it can use.
 * - **republishing a version with different bytes is refused.** A version
 *   number that no longer identifies bytes makes every other check here
 *   meaningless. `--allow-republish` says it was meant.
 */
import { createHash } from "node:crypto";

import { l10nDir, manifestName, parseManifest } from "./pack.ts";
import { readZip } from "./zip.ts";

/** The schema a repository announces in `repo.toml`. */
export const schema = 1;

/**
 * Where a repository that carries its own packages puts them.
 *
 * Not written by this tool — it names a `url` — but the format allows a `path`,
 * and the app reads one. Kept so a third-party repository built by hand has a
 * conventional place for them.
 */
export const packagesDir = "packages";

/** Where the per-plugin files live. */
export const pluginsDir = "plugins";

export interface RepoRelease {
  version: string;
  abi: number;
  /** A path inside the repository. Exactly one of this and [url]. */
  path?: string;
  /** An absolute https address, for a package served from somewhere else. */
  url?: string;
  sha256: string;
  size: number;
  notes?: string;
}

export interface RepoPlugin {
  id: string;
  name: string;
  description: string;
  homepage?: string;
  license?: string;
  /** Newest first. The order in the file is for whoever reads it. */
  versions: RepoRelease[];
}

/**
 * The file a plugin id belongs in.
 *
 * **Two directory levels, taken from the id.** An id is reverse-DNS, so its
 * first two segments are the publisher and the rest is the plugin —
 * `app.serverbox.diskusage` is `plugins/app/serverbox/diskusage.toml`. That
 * shards a growing repository the way Homebrew's `Formula/a/…` does, and it
 * groups a publisher's plugins together, which a first-letter shard would not.
 *
 * Derived rather than declared, and checked in both directions when a file is
 * read: a file whose path and `id` disagree is a copy-paste into the wrong
 * folder, and without the check the app would install something the repository
 * does not think it is offering.
 */
export function layoutOf(id: string): string {
  const parts = id.split(".");
  if (parts.length < 3 || parts.some((p) => !/^[A-Za-z0-9_-]+$/.test(p))) {
    throw new Error(
      `${id} is not a reverse-DNS id of at least three parts, so it has no ` +
        `place in the repository (expected something like com.example.thing)`,
    );
  }
  const [first, second, ...rest] = parts;
  return `${pluginsDir}/${first}/${second}/${rest.join(".")}.toml`;
}

/**
 * The release tag one version of one plugin is published under.
 *
 * **One release per plugin version**, so a tag identifies exactly one set of
 * bytes and keeps its URL for as long as a file lists that version. A single
 * shared tag would mean every package sharing one release's history, and
 * "which release is this package in" would stop having an answer.
 *
 * The same string the packer names the file after, so a tag and its one asset
 * read the same.
 */
export function tagOf(id: string, version: string): string {
  return `${id}-${version}`;
}

/** The id a file at [path] must declare, or null if that is not a plugin file. */
export function idOfLayout(path: string): string | null {
  const match = new RegExp(
    `^${pluginsDir}/([^/]+)/([^/]+)/(.+)\\.toml$`,
  ).exec(path);
  if (!match) return null;
  return `${match[1]}.${match[2]}.${match[3]}`;
}

// ------------------------------------------------------------------ reading

/**
 * Parses a plugin's file, checking it against the path it was found at.
 *
 * Uses Bun's TOML parser rather than a hand-written subset: the files here are
 * written by other people, and a reader that only accepts what this tool emits
 * would reject valid TOML with a confusing message.
 */
export function readPlugin(text: string, path: string): RepoPlugin {
  const raw = Bun.TOML.parse(text) as Record<string, unknown>;
  const id = raw["id"];
  if (typeof id !== "string" || id.length === 0) {
    throw new Error(`${path}: no id`);
  }
  const expected = idOfLayout(path);
  if (expected !== null && expected !== id) {
    throw new Error(
      `${path}: declares ${id}, but its path says ${expected} — a file has to ` +
        `sit where its id puts it`,
    );
  }

  const versions = raw["version"];
  if (!Array.isArray(versions) || versions.length === 0) {
    throw new Error(`${path}: no [[version]]`);
  }

  return {
    id,
    name: typeof raw["name"] === "string" ? raw["name"] : id,
    description:
      typeof raw["description"] === "string" ? raw["description"] : "",
    ...(typeof raw["homepage"] === "string" ? { homepage: raw["homepage"] } : {}),
    ...(typeof raw["license"] === "string" ? { license: raw["license"] } : {}),
    versions: versions.map((v, i) => readRelease(v, `${path} [[version]] ${i}`)),
  };
}

function readRelease(raw: unknown, where: string): RepoRelease {
  if (typeof raw !== "object" || raw === null) throw new Error(`${where}: not a table`);
  const v = raw as Record<string, unknown>;
  const version = v["version"];
  const abi = v["abi"];
  const sha256 = v["sha256"];
  if (typeof version !== "string" || version.length === 0) {
    throw new Error(`${where}: no version`);
  }
  if (typeof abi !== "number" || !Number.isInteger(abi)) {
    throw new Error(`${where}: abi has to be a whole number`);
  }
  const path = typeof v["path"] === "string" ? v["path"] : undefined;
  const url = typeof v["url"] === "string" ? v["url"] : undefined;
  // Exactly one: a release with both would leave the reader choosing, and the
  // two can disagree.
  if ((path === undefined) === (url === undefined)) {
    throw new Error(`${where}: name exactly one of path and url`);
  }
  if (typeof sha256 !== "string" || !/^[0-9a-f]{64}$/.test(sha256)) {
    throw new Error(`${where}: sha256 has to be 64 hex characters`);
  }
  return {
    version,
    abi,
    ...(path !== undefined ? { path } : {}),
    ...(url !== undefined ? { url } : {}),
    sha256,
    size: typeof v["size"] === "number" ? v["size"] : 0,
    ...(typeof v["notes"] === "string" ? { notes: v["notes"] } : {}),
  };
}

/** Parses `repo.toml`, or throws. */
export function readRepoFile(text: string): { name?: string } {
  const raw = Bun.TOML.parse(text) as Record<string, unknown>;
  const announced = raw["schema"];
  if (typeof announced !== "number") {
    throw new Error("repo.toml names no schema");
  }
  if (announced > schema) {
    throw new Error(`repo.toml is schema ${announced} and this tool writes ${schema}`);
  }
  return typeof raw["name"] === "string" ? { name: raw["name"] } : {};
}

// ------------------------------------------------------------------ writing

/**
 * Emits a plugin's file.
 *
 * Hand-written rather than through a library, because Bun has a TOML parser and
 * no writer, and because the output is a file people read and send patches to:
 * a fixed key order, one table per version, and nothing quoted that does not
 * need to be.
 */
export function writePlugin(plugin: RepoPlugin): string {
  const lines: string[] = [
    `id = ${str(plugin.id)}`,
    `name = ${str(plugin.name)}`,
    `description = ${str(plugin.description)}`,
  ];
  if (plugin.homepage) lines.push(`homepage = ${str(plugin.homepage)}`);
  if (plugin.license) lines.push(`license = ${str(plugin.license)}`);

  for (const release of plugin.versions) {
    lines.push("", "[[version]]", `version = ${str(release.version)}`);
    lines.push(`abi = ${release.abi}`);
    if (release.path) lines.push(`path = ${str(release.path)}`);
    if (release.url) lines.push(`url = ${str(release.url)}`);
    lines.push(`sha256 = ${str(release.sha256)}`);
    lines.push(`size = ${release.size}`);
    if (release.notes) lines.push(`notes = ${str(release.notes)}`);
  }

  return `${lines.join("\n")}\n`;
}

export function writeRepoFile(name: string): string {
  return `schema = ${schema}\nname = ${str(name)}\n`;
}

/** A TOML basic string. */
function str(value: string): string {
  const escaped = value
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\t/g, "\\t")
    // Anything else in the C0 range has to be escaped, and a raw one would
    // produce a file no parser accepts.
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, (c) =>
      `\\u${c.charCodeAt(0).toString(16).padStart(4, "0")}`,
    );
  return `"${escaped}"`;
}

// ------------------------------------------------------------------ building

export interface PackageInput {
  /** The `.sbp` itself. The manifest is read out of these bytes. */
  bytes: Uint8Array;
  /** What it is served as, and its name under `packages/`. */
  fileName: string;
  notes?: string;
}

export interface BuildOptions {
  packages: PackageInput[];
  /**
   * Where releases are downloaded from, e.g.
   * `https://github.com/owner/repo/releases/download`.
   *
   * A version's URL is this, then its own tag, then the package's file name —
   * see [tagOf]. The repository holds no packages: it names where they are, the
   * way a Homebrew formula names the tarball it points at.
   */
  baseUrl: string;
  /** Every plugin file the repository already has, by repository path. */
  existing?: Map<string, string>;
  allowRepublish?: boolean;
}

export interface BuildResult {
  /** Files to write, by repository path: the TOML files that changed. */
  files: Map<string, string>;
  /** One line per package, for the tool to print. */
  notes: string[];
}

export function buildRepo({
  packages,
  baseUrl,
  existing = new Map(),
  allowRepublish = false,
}: BuildOptions): BuildResult {
  const plugins = new Map<string, RepoPlugin>();
  for (const [path, text] of existing) {
    if (idOfLayout(path) === null) continue;
    const plugin = readPlugin(text, path);
    plugins.set(plugin.id, plugin);
  }

  const notes: string[] = [];
  const out = new Map<string, string>();
  const touched = new Set<string>();
  const base = baseUrl.replace(/\/+$/, "");

  for (const pkg of packages) {
    const manifest = manifestOf(pkg.bytes, pkg.fileName);
    const release: RepoRelease = {
      version: manifest.version,
      abi: manifest.abi,
      url: `${base}/${tagOf(manifest.id, manifest.version)}/${pkg.fileName}`,
      sha256: createHash("sha256").update(pkg.bytes).digest("hex"),
      size: pkg.bytes.length,
      ...(pkg.notes ? { notes: pkg.notes } : {}),
    };

    const plugin = plugins.get(manifest.id) ?? {
      id: manifest.id,
      name: manifest.name ?? manifest.id,
      description: manifest.description ?? "",
      versions: [],
    };
    // The newest package wins for what the plugin *is*: its name and what it
    // says about itself follow the code, and a repository that kept the first
    // description forever would describe a plugin as it was years ago.
    plugin.name = manifest.name ?? plugin.name;
    plugin.description = manifest.description ?? plugin.description;
    if (manifest.source_url) plugin.homepage = manifest.source_url;
    if (manifest.license) plugin.license = manifest.license;

    const at = plugin.versions.findIndex((v) => v.version === release.version);
    if (at < 0) {
      plugin.versions.push(release);
      notes.push(`+ ${manifest.id} ${release.version} (${release.size} bytes)`);
    } else {
      const had = plugin.versions[at]!;
      if (had.sha256 !== release.sha256) {
        if (!allowRepublish) {
          throw new Error(
            `${manifest.id} ${release.version} is already published with a ` +
              `different checksum (${had.sha256} → ${release.sha256}). A ` +
              `version has to identify its bytes; bump the version, or pass ` +
              `--allow-republish if this was meant.`,
          );
        }
        notes.push(`! ${manifest.id} ${release.version} republished`);
      } else {
        notes.push(`= ${manifest.id} ${release.version}`);
      }
      // Notes the file already carried are kept when this run has none: they
      // were written by hand and are not derivable from a package.
      plugin.versions[at] = {
        ...release,
        ...(release.notes ?? had.notes
          ? { notes: release.notes ?? had.notes }
          : {}),
      };
    }

    plugin.versions.sort((a, b) => compareVersions(b.version, a.version));
    plugins.set(manifest.id, plugin);
    touched.add(manifest.id);
  }

  // Only the plugins this run touched are rewritten. A repository holds files
  // other people sent, and reformatting them all on every publish would bury
  // the change that was actually made.
  for (const id of touched) {
    out.set(layoutOf(id), writePlugin(plugins.get(id)!));
  }

  return { files: out, notes };
}

/**
 * Reads the manifest out of a `.sbp`, as a repository has to read it.
 *
 * **`l10n.` keys resolved against the package's English table.** A manifest is
 * one document for every language, so a plugin names itself with a key and the
 * app looks it up in whichever language it is running in. An index has no
 * language — it is one text file in a git repository, read by every client —
 * so English is what goes in it, and this is where that is decided.
 */
export function manifestOf(bytes: Uint8Array, where: string) {
  const files = readZip(bytes);
  const manifest = files.get(manifestName);
  if (!manifest) throw new Error(`${where} has no ${manifestName}`);
  const parsed = parseManifest(new TextDecoder().decode(manifest), where);
  const english = englishOf(files, where);
  return {
    ...parsed,
    ...(parsed.name === undefined
      ? {}
      : { name: resolveL10n(parsed.name, english, where) }),
    ...(parsed.description === undefined
      ? {}
      : { description: resolveL10n(parsed.description, english, where) }),
  };
}

/** The prefix that marks a manifest string as a key. `PluginL10n.prefix`. */
export const l10nPrefix = "l10n.";

/**
 * [value] with an `l10n.` key looked up, or [value] itself.
 *
 * **Throws for a key nothing translates**, rather than passing `l10n.name`
 * through into a repository where every client would show it. The app is
 * lenient about this for a good reason — a missing key names itself on screen,
 * which is how you find it — but an index is written once and read by
 * everybody.
 */
export function resolveL10n(
  value: string,
  table: Record<string, string>,
  where: string,
): string {
  if (!value.startsWith(l10nPrefix)) return value;
  const key = value.slice(l10nPrefix.length);
  const hit = table[key];
  if (hit === undefined) {
    throw new Error(`${where}: ${l10nDir}/en.json has no ${key}`);
  }
  return hit;
}

/** A package's `en` strings, which is the one locale a manifest must ship. */
function englishOf(
  files: Map<string, Uint8Array>,
  where: string,
): Record<string, string> {
  const raw = files.get(`${l10nDir}/en.json`);
  if (!raw) return {};
  let decoded: unknown;
  try {
    decoded = JSON.parse(new TextDecoder().decode(raw));
  } catch (e) {
    throw new Error(`${where}: ${l10nDir}/en.json is not JSON: ${e}`);
  }
  if (typeof decoded !== "object" || decoded === null) return {};
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(decoded as Record<string, unknown>)) {
    if (typeof v === "string") out[k] = v;
  }
  return out;
}

/**
 * The app's `PluginVersion.compare`, ported.
 *
 * Field by field and numerically: a string comparison puts `1.10` before
 * `1.9`, and a suffix (`1.0.0-beta`) sorts below the release it precedes.
 */
export function compareVersions(a: string, b: string): number {
  const parts = (v: string) =>
    v
      .split("-")[0]!
      .split(".")
      .map((p) => Number.parseInt(p.trim(), 10) || 0);
  const left = parts(a);
  const right = parts(b);
  for (let i = 0; i < 3; i++) {
    const d = (left[i] ?? 0) - (right[i] ?? 0);
    if (d !== 0) return d < 0 ? -1 : 1;
  }
  const suffix = (v: string) => {
    const at = v.indexOf("-");
    return at < 0 ? "" : v.slice(at + 1);
  };
  const sa = suffix(a);
  const sb = suffix(b);
  if (sa === "" && sb === "") return 0;
  if (sa === "") return 1;
  if (sb === "") return -1;
  return sa < sb ? -1 : sa > sb ? 1 : 0;
}
