/**
 * Reading a `.tar.gz`, which is how a repository arrives.
 *
 * Written by hand because Bun has `gunzipSync` and no tar reader, and because
 * what is needed is small: the entries of a source tarball, by name. Only what
 * GitHub, GitLab and `git archive` actually emit is implemented — ustar with the
 * `prefix` field, GNU long names, and pax headers skipped — and anything else is
 * an error rather than a guess.
 */
const BLOCK = 512;

export interface TarLimits {
  /** Refuse a single entry larger than this. */
  maxEntryBytes?: number;
  /** Refuse an archive whose entries add up to more than this. */
  maxTotalBytes?: number;
}

export function readTarGz(
  bytes: Uint8Array,
  limits: TarLimits = {},
): Map<string, Uint8Array> {
  // Copied into an `ArrayBuffer`-backed view: `gunzipSync` will not take one
  // that might be over a `SharedArrayBuffer`, and a subarray of a larger read
  // is exactly that as far as the types are concerned.
  return readTar(new Uint8Array(Bun.gunzipSync(Uint8Array.from(bytes))), limits);
}

export function readTar(
  bytes: Uint8Array,
  { maxEntryBytes = 8 * 1024 * 1024, maxTotalBytes = 64 * 1024 * 1024 }: TarLimits = {},
): Map<string, Uint8Array> {
  const out = new Map<string, Uint8Array>();
  const decoder = new TextDecoder();
  let at = 0;
  let total = 0;
  /** Set by a GNU `L` entry, which names the entry that follows it. */
  let longName: string | undefined;

  while (at + BLOCK <= bytes.length) {
    const header = bytes.subarray(at, at + BLOCK);
    // Two zero blocks end the archive; one is enough to stop on.
    if (header.every((b) => b === 0)) break;

    const field = (from: number, length: number) => {
      const raw = header.subarray(from, from + length);
      const end = raw.indexOf(0);
      return decoder.decode(end < 0 ? raw : raw.subarray(0, end)).trim();
    };
    const octal = (from: number, length: number) => {
      const text = field(from, length).replace(/[^0-7]/g, "");
      return text.length === 0 ? 0 : Number.parseInt(text, 8);
    };

    const size = octal(124, 12);
    const type = String.fromCharCode(header[156] ?? 0);
    const prefix = field(345, 155);
    const name = longName ?? (prefix ? `${prefix}/${field(0, 100)}` : field(0, 100));
    longName = undefined;

    at += BLOCK;
    if (size > maxEntryBytes) throw new Error(`${name} is larger than ${maxEntryBytes} bytes`);
    const data = bytes.subarray(at, at + size);
    at += Math.ceil(size / BLOCK) * BLOCK;

    switch (type) {
      case "0":
      case "\0":
        total += size;
        if (total > maxTotalBytes) throw new Error("the archive unpacks to too much");
        out.set(name, data);
        break;
      case "L":
        // GNU long name: the next header's name is this entry's contents.
        longName = decoder.decode(data).replace(/\0+$/, "");
        break;
      case "5": // a directory, which carries nothing
      case "x": // pax header for the next entry
      case "g": // pax header for the archive
      case "1": // a hard link
      case "2": // a symlink
              break;
      default:
        throw new Error(`${name}: tar entry type ${type}`);
    }
  }

  return out;
}

/**
 * Drops the single top directory a source tarball is wrapped in.
 *
 * **Its name cannot be predicted**: GitHub names it `<repo>-<ref>`, and for a
 * `HEAD` archive the ref is the resolved commit sha. So the prefix is taken from
 * the entries rather than constructed, and an archive whose entries do not share
 * one is left alone — a tarball made by `tar czf` from inside the directory is
 * already flat.
 */
export function stripTopDirectory(
  files: Map<string, Uint8Array>,
): Map<string, Uint8Array> {
  const tops = new Set<string>();
  for (const name of files.keys()) {
    const at = name.indexOf("/");
    if (at < 0) return files;
    tops.add(name.slice(0, at));
  }
  if (tops.size !== 1) return files;

  const prefix = `${[...tops][0]}/`;
  const out = new Map<string, Uint8Array>();
  for (const [name, data] of files) out.set(name.slice(prefix.length), data);
  return out;
}
