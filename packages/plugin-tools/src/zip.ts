/**
 * The `.sbp` archive, written and read.
 *
 * **One copy of the format, because the two tools here have to agree.** The
 * packer writes the archive; the index generator reads the manifest back *out
 * of the bytes it is about to publish a digest for*. Reading the plugin's
 * `manifest.json` off disk instead would let the two drift — an edit made after
 * packaging would be described by the index and absent from the package, and
 * the digest would be right about a file nobody has.
 *
 * Bun has no zip API and a plugin package is a handful of small files, so the
 * writer stores them uncompressed: every reader accepts stored entries, and
 * `PluginPackage` caps what a package unpacks to anyway, which is the thing
 * compression here would trade against.
 */
import { inflateRawSync } from "node:zlib";

export interface ZipEntry {
  /** A flat, forward-slash path. `PluginPackage.read` refuses one that escapes. */
  name: string;
  data: Uint8Array;
}

const LOCAL_SIG = 0x04034b50;
const CENTRAL_SIG = 0x02014b50;
const EOCD_SIG = 0x06054b50;

const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[i] = c >>> 0;
  }
  return t;
})();

export function crc32(b: Uint8Array): number {
  let c = 0xffffffff;
  for (const byte of b) c = crcTable[(c ^ byte) & 0xff]! ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

/** Writes [entries] in the order given, stored. */
export function writeZip(entries: ZipEntry[]): Uint8Array {
  const chunks: Uint8Array[] = [];
  const central: Uint8Array[] = [];
  let offset = 0;

  for (const { name, data } of entries) {
    const nameBytes = new TextEncoder().encode(name);
    const crc = crc32(data);

    const local = new DataView(new ArrayBuffer(30));
    local.setUint32(0, LOCAL_SIG, true);
    local.setUint16(4, 20, true);
    local.setUint32(14, crc, true);
    local.setUint32(18, data.length, true);
    local.setUint32(22, data.length, true);
    local.setUint16(26, nameBytes.length, true);
    const localBytes = new Uint8Array(local.buffer);

    const dir = new DataView(new ArrayBuffer(46));
    dir.setUint32(0, CENTRAL_SIG, true);
    dir.setUint16(4, 20, true);
    dir.setUint16(6, 20, true);
    dir.setUint32(16, crc, true);
    dir.setUint32(20, data.length, true);
    dir.setUint32(24, data.length, true);
    dir.setUint16(28, nameBytes.length, true);
    dir.setUint32(42, offset, true);

    chunks.push(localBytes, nameBytes, data);
    central.push(new Uint8Array(dir.buffer), nameBytes);
    offset += localBytes.length + nameBytes.length + data.length;
  }

  const centralSize = central.reduce((n, c) => n + c.length, 0);
  const end = new DataView(new ArrayBuffer(22));
  end.setUint32(0, EOCD_SIG, true);
  end.setUint16(8, entries.length, true);
  end.setUint16(10, entries.length, true);
  end.setUint32(12, centralSize, true);
  end.setUint32(16, offset, true);

  const all = [...chunks, ...central, new Uint8Array(end.buffer)];
  const total = all.reduce((n, c) => n + c.length, 0);
  const buf = new Uint8Array(total);
  let at = 0;
  for (const c of all) {
    buf.set(c, at);
    at += c.length;
  }
  return buf;
}

/**
 * Reads every file entry, by name.
 *
 * Walks the central directory rather than scanning for local headers: the
 * central directory is what a zip reader is defined to trust, and it is the
 * only place that says how many entries there are. Deflate is accepted as well
 * as stored, because the archive read here may not be one this packer wrote.
 */
export function readZip(bytes: Uint8Array): Map<string, Uint8Array> {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const eocd = findEocd(bytes, view);
  const count = view.getUint16(eocd + 10, true);
  let at = view.getUint32(eocd + 16, true);

  const out = new Map<string, Uint8Array>();
  for (let i = 0; i < count; i++) {
    if (at + 46 > bytes.length || view.getUint32(at, true) !== CENTRAL_SIG) {
      throw new Error(`the central directory ends early, at entry ${i}`);
    }
    const method = view.getUint16(at + 10, true);
    const compressed = view.getUint32(at + 20, true);
    const uncompressed = view.getUint32(at + 24, true);
    const nameLen = view.getUint16(at + 28, true);
    const extraLen = view.getUint16(at + 30, true);
    const commentLen = view.getUint16(at + 32, true);
    const localAt = view.getUint32(at + 42, true);
    const name = new TextDecoder().decode(
      bytes.subarray(at + 46, at + 46 + nameLen),
    );
    at += 46 + nameLen + extraLen + commentLen;

    // A directory entry, which carries no data.
    if (name.endsWith("/")) continue;

    if (localAt + 30 > bytes.length || view.getUint32(localAt, true) !== LOCAL_SIG) {
      throw new Error(`${name}: no local header where the directory says`);
    }
    const dataAt =
      localAt +
      30 +
      view.getUint16(localAt + 26, true) +
      view.getUint16(localAt + 28, true);
    if (dataAt + compressed > bytes.length) {
      throw new Error(`${name}: runs past the end of the archive`);
    }
    const raw = bytes.subarray(dataAt, dataAt + compressed);

    const data =
      method === 0
        ? raw
        : method === 8
          ? new Uint8Array(inflateRawSync(raw))
          : (() => {
              throw new Error(`${name}: compression method ${method}`);
            })();
    if (data.length !== uncompressed) {
      throw new Error(
        `${name}: ${data.length} bytes where the directory says ${uncompressed}`,
      );
    }
    out.set(name, data);
  }
  return out;
}

/**
 * The end-of-central-directory record, searched from the back.
 *
 * The record is last but not at a fixed offset — a trailing comment sits after
 * it — so the scan starts at the earliest place a 22-byte record could begin
 * and walks backwards over the 64 KiB a comment length can reach.
 */
function findEocd(bytes: Uint8Array, view: DataView): number {
  const first = Math.max(0, bytes.length - 22 - 0xffff);
  for (let i = bytes.length - 22; i >= first; i--) {
    if (view.getUint32(i, true) === EOCD_SIG) return i;
  }
  throw new Error("not a zip: no end-of-central-directory record");
}
