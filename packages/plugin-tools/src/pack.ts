/**
 * Packing a plugin directory into a `.sbp`.
 *
 * One implementation, for every plugin. It used to be a copy of this file in
 * each plugin's `scripts/`, all three identical — three places to fix a bug in
 * a hand-written zip writer, and three places for a new entry kind to be
 * forgotten in two of them. Which is what happened: the translations were left
 * out of the archive for a while, so a plugin shipped them in its directory,
 * installed correctly from that directory, and silently fell back to English
 * once it was packaged.
 *
 * What goes in is fixed by what `PluginPackage.read` looks for, and nothing
 * else does: `manifest.json`, `plugin.js`, `l10n/<locale>.json`, `icon.png`
 * and `assets/*`. Anything else in the directory is the author's own business
 * and is left where it is.
 */
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { writeZip, type ZipEntry } from "./zip.ts";

/** What the packer needs out of a manifest. The host parser reads the rest. */
export interface PackManifest {
  id: string;
  version: string;
  abi: number;
  name?: string;
  description?: string;
  l10n?: string[];
  license?: string;
  source_url?: string;
}

export interface PackedPlugin {
  manifest: PackManifest;
  /** Verbatim, because the manifest in the archive is the one the host parses. */
  manifestJson: string;
  bytes: Uint8Array;
  /** Entry names, in the order they were written. */
  entries: string[];
  /** `<id>-<version>.sbp`, which is what a repository serves it as. */
  fileName: string;
  /** Things that are not errors but that somebody should know about. */
  warnings: string[];
}

/** The app's own caps, mirrored so a package that cannot be installed is not
 * written in the first place. See `PluginPackage.maxTotalBytes`. */
export const maxEntryBytes = 4 * 1024 * 1024;
export const maxTotalBytes = 8 * 1024 * 1024;

export const manifestName = "manifest.json";
export const sourceName = "plugin.js";
export const iconName = "icon.png";
export const l10nDir = "l10n";
export const assetDir = "assets";

/**
 * What an `image` node may draw, by extension.
 *
 * The same list the app reads (`PluginAssets.allowed`). Anything else in
 * `assets/` is refused rather than dropped: a package whose picture is not
 * carried is a plugin drawing a gap on somebody else's device, and the author
 * finds out from a bug report.
 */
export const assetExtensions = [".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg"];

/**
 * Everything a plugin directory is made of, checked.
 *
 * **One list, because a plugin arrives two ways and both have to carry the same
 * files.** A `.sbp` is this zipped; a development directory is this on disk,
 * staged into `dist/` by the build. They were two lists once — the build copied
 * the manifest and the script and nothing else — so a plugin loaded from its
 * directory drew `l10n.summaryLabel` in every row while the packaged copy of
 * the same plugin was translated. That is the omission the packer itself had,
 * one path over.
 */
export function pluginEntries(dir: string): {
  manifest: PackManifest;
  manifestJson: string;
  entries: ZipEntry[];
  warnings: string[];
} {
  const manifestPath = join(dir, manifestName);
  if (!existsSync(manifestPath)) {
    throw new Error(`${dir} has no ${manifestName}`);
  }
  const manifestJson = readFileSync(manifestPath, "utf8");
  const manifest = parseManifest(manifestJson, manifestPath);

  const sourcePath = join(dir, "dist", sourceName);
  if (!existsSync(sourcePath)) {
    throw new Error(
      `${sourcePath} is not there — run \`bun run build\` before packing`,
    );
  }

  const warnings: string[] = [];
  const entries: ZipEntry[] = [
    { name: manifestName, data: bytesOf(manifestPath) },
    { name: sourceName, data: bytesOf(sourcePath) },
  ];

  // Declared and present are two lists, and the app reads the *files*. So a
  // locale in the manifest with no file is a promise the package does not keep
  // — refused — while a file nobody declared works and is only unannounced.
  const declared = manifest.l10n ?? [];
  const dirPath = join(dir, l10nDir);
  const present = existsSync(dirPath)
    ? readdirSync(dirPath)
        .filter((n) => n.endsWith(".json"))
        .sort()
    : [];
  const locales = new Set(present.map((n) => n.slice(0, -".json".length)));

  for (const locale of declared) {
    if (!locales.has(locale)) {
      throw new Error(
        `the manifest declares the locale ${locale} and there is no ${l10nDir}/${locale}.json`,
      );
    }
  }
  for (const locale of locales) {
    if (!declared.includes(locale)) {
      warnings.push(
        `${l10nDir}/${locale}.json is packed but the manifest does not list it`,
      );
    }
  }
  // `en` is the fallback every other locale is read behind, so a package
  // without it shows keys wherever a translation is incomplete.
  if (locales.size > 0 && !locales.has("en")) {
    throw new Error(`${l10nDir}/en.json is missing, and en is the fallback`);
  }
  for (const name of present) {
    entries.push({ name: `${l10nDir}/${name}`, data: bytesOf(join(dirPath, name)) });
  }

  const icon = join(dir, iconName);
  if (existsSync(icon)) entries.push({ name: iconName, data: bytesOf(icon) });

  // One flat directory, and a name with a path in it is refused rather than
  // normalised — so there is no `..` for either side to reason about.
  const assets = join(dir, assetDir);
  if (existsSync(assets)) {
    for (const name of readdirSync(assets).sort()) {
      const at = name.lastIndexOf(".");
      const ext = at <= 0 ? "" : name.slice(at).toLowerCase();
      if (!assetExtensions.includes(ext)) {
        throw new Error(
          `${assetDir}/${name} is not a file the app reads ` +
            `(${assetExtensions.join(", ")})`,
        );
      }
      entries.push({
        name: `${assetDir}/${name}`,
        data: bytesOf(join(assets, name)),
      });
    }
  }

  checkManifestKeys(manifestJson, join(dirPath, "en.json"));

  return { manifest, manifestJson, entries, warnings };
}

/**
 * Every `l10n.` key the manifest uses has an English string behind it.
 *
 * A manifest is one document for every language, so a plugin names itself and
 * its contributions with keys. Which means the *manifest's* keys can go missing
 * exactly like the script's, and the failure looks the same: a tab called
 * `l10n.fleetLabel`, a store row called `l10n.pluginName`. Checked here because
 * this is the last moment before those strings become somebody else's
 * download — and because the repository index is written from `en` and cannot
 * fall back to anything.
 */
function checkManifestKeys(manifestJson: string, enPath: string): void {
  const keys = manifestL10nKeys(manifestJson);
  if (keys.length === 0) return;
  const table = existsSync(enPath)
    ? (JSON.parse(readFileSync(enPath, "utf8")) as Record<string, unknown>)
    : {};
  const missing = keys.filter((k) => typeof table[k] !== "string");
  if (missing.length > 0) {
    throw new Error(
      `${manifestName} uses ${missing.map((k) => `l10n.${k}`).join(", ")} ` +
        `and ${enPath} has no such string`,
    );
  }
}

/** The keys a manifest names: its own strings, and each contribution's label. */
export function manifestL10nKeys(manifestJson: string): string[] {
  const out: string[] = [];
  const take = (v: unknown) => {
    if (typeof v === "string" && v.startsWith("l10n.")) {
      out.push(v.slice("l10n.".length));
    }
  };
  let raw: unknown;
  try {
    raw = JSON.parse(manifestJson);
  } catch {
    return out;
  }
  if (typeof raw !== "object" || raw === null) return out;
  const m = raw as Record<string, unknown>;
  take(m["name"]);
  take(m["description"]);
  const contributes = m["contributes"];
  if (typeof contributes === "object" && contributes !== null) {
    for (const one of Object.values(contributes as Record<string, unknown>)) {
      if (typeof one === "object" && one !== null) {
        take((one as Record<string, unknown>)["label"]);
      }
    }
  }
  return out;
}

/**
 * Reads [dir] and returns the archive, or throws with what is wrong.
 *
 * Throws rather than warns for anything that would produce a package the app
 * refuses or half-reads. A packer that succeeds and hands back something
 * uninstallable moves the failure to whoever downloads it.
 */
export function packPlugin(dir: string): PackedPlugin {
  const { manifest, manifestJson, entries, warnings } = pluginEntries(dir);

  let total = 0;
  for (const entry of entries) {
    if (entry.data.length > maxEntryBytes) {
      throw new Error(
        `${entry.name} is ${entry.data.length} bytes and the app reads at most ${maxEntryBytes}`,
      );
    }
    total += entry.data.length;
  }
  if (total > maxTotalBytes) {
    throw new Error(
      `the package unpacks to ${total} bytes and the app reads at most ${maxTotalBytes}`,
    );
  }

  return {
    manifest,
    manifestJson,
    bytes: writeZip(entries),
    entries: entries.map((e) => e.name),
    fileName: `${manifest.id}-${manifest.version}.sbp`,
    warnings,
  };
}

/**
 * The fields a repository index is built out of, checked.
 *
 * Only those: the host's parser is the authority on the rest, and a second
 * implementation of it here would be a second thing to keep in step.
 */
export function parseManifest(json: string, where: string): PackManifest {
  let raw: unknown;
  try {
    raw = JSON.parse(json);
  } catch (e) {
    throw new Error(`${where} is not JSON: ${e}`);
  }
  if (typeof raw !== "object" || raw === null) {
    throw new Error(`${where} is not an object`);
  }
  const m = raw as Record<string, unknown>;
  const id = m["id"];
  const version = m["version"];
  const abi = m["abi"];
  if (typeof id !== "string" || id.length === 0) {
    throw new Error(`${where} names no id`);
  }
  if (typeof version !== "string" || version.length === 0) {
    throw new Error(`${where} names no version`);
  }
  if (typeof abi !== "number" || !Number.isInteger(abi)) {
    throw new Error(`${where}: abi has to be a whole number`);
  }
  const l10n = m["l10n"];
  return {
    id,
    version,
    abi,
    ...(typeof m["name"] === "string" ? { name: m["name"] } : {}),
    ...(typeof m["description"] === "string"
      ? { description: m["description"] }
      : {}),
    ...(Array.isArray(l10n)
      ? { l10n: l10n.filter((v): v is string => typeof v === "string") }
      : {}),
    ...(typeof m["license"] === "string" ? { license: m["license"] } : {}),
    ...(typeof m["source_url"] === "string"
      ? { source_url: m["source_url"] }
      : {}),
  };
}

function bytesOf(path: string): Uint8Array {
  const size = statSync(path).size;
  if (size > maxEntryBytes) {
    throw new Error(
      `${path} is ${size} bytes and the app reads at most ${maxEntryBytes}`,
    );
  }
  return new Uint8Array(readFileSync(path));
}
