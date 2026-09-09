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
 * else does: `manifest.json`, `plugin.js`, `l10n/<locale>.json`, `icon.png`.
 * Anything else in the directory is the author's own business and is left
 * where it is.
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

/**
 * Reads [dir] and returns the archive, or throws with what is wrong.
 *
 * Throws rather than warns for anything that would produce a package the app
 * refuses or half-reads. A packer that succeeds and hands back something
 * uninstallable moves the failure to whoever downloads it.
 */
export function packPlugin(dir: string): PackedPlugin {
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
