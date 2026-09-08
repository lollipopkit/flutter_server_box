/**
 * Packs `dist/plugin.js` and `manifest.json` into a `.sbp`.
 *
 * A `.sbp` is a zip, and `PluginPackage.read` refuses one with a path that
 * escapes — so this writes exactly two flat entries and nothing else.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const root = join(import.meta.dir, "..");
const manifest = JSON.parse(
  readFileSync(join(root, "manifest.json"), "utf8"),
) as { id: string; version: string };

const out = join(root, "dist", `${manifest.id}-${manifest.version}.sbp`);
mkdirSync(dirname(out), { recursive: true });

// Bun has no zip writer, and a plugin package is two files — so the archive is
// written by hand, stored (no compression), which every reader accepts.
const files: [string, Uint8Array][] = [
  ["manifest.json", new Uint8Array(readFileSync(join(root, "manifest.json")))],
  ["plugin.js", new Uint8Array(readFileSync(join(root, "dist/plugin.js")))],
];

const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[i] = c >>> 0;
  }
  return t;
})();
const crc32 = (b: Uint8Array) => {
  let c = 0xffffffff;
  for (const byte of b) c = crcTable[(c ^ byte) & 0xff]! ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};

const chunks: Uint8Array[] = [];
const central: Uint8Array[] = [];
let offset = 0;

for (const [name, data] of files) {
  const nameBytes = new TextEncoder().encode(name);
  const crc = crc32(data);

  const local = new DataView(new ArrayBuffer(30));
  local.setUint32(0, 0x04034b50, true);
  local.setUint16(4, 20, true);
  local.setUint32(14, crc, true);
  local.setUint32(18, data.length, true);
  local.setUint32(22, data.length, true);
  local.setUint16(26, nameBytes.length, true);
  const localBytes = new Uint8Array(local.buffer);

  const dir = new DataView(new ArrayBuffer(46));
  dir.setUint32(0, 0x02014b50, true);
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
end.setUint32(0, 0x06054b50, true);
end.setUint16(8, files.length, true);
end.setUint16(10, files.length, true);
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
writeFileSync(out, buf);
console.log(`${out} (${buf.length} bytes)`);
